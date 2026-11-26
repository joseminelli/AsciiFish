import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/models/app_settings.dart';
import '../core/models/ascii_theme.dart';
import '../core/models/fish_sprites.dart';
import '../core/models/game_progress.dart';
import '../core/models/particle.dart';
import '../core/models/shop_catalog.dart';
import '../core/simulation/aquarium_engine.dart';
import '../core/simulation/progression_service.dart';
import '../core/storage/save_repository.dart';
import '../platform/update_service.dart';
import '../platform/windows_window_service.dart';
import '../ui/painter/aquarium_painter.dart';

/// Geometria dos painéis flutuantes (pixels lógicos, ancorados no canto inferior esquerdo).
const kDockSize = Size(262, 64);
const kMenuSize = Size(360, 380);
const kPanelMargin = 8.0;
const kWaterPx = 90.0;
const kMenuWindowHeight = kPanelMargin * 3 + 64 + 380 + 20;

/// Liga motor, progressão, persistência e janela. A UI observa via ChangeNotifier (~2 Hz);
/// o canvas é repintado por um notifier separado a cada frame.
class GameController extends ChangeNotifier {
  GameController({
    required this.repo,
    required this.window,
    required this.settings,
    required this.progress,
  }) {
    prog = ProgressionService(progress, onMessage: showToast);
    glyphs = GlyphCache(settings.fontSize);
    themeId = ValueNotifier(settings.themeId);
  }

  final SaveRepository repo;
  final WindowsWindowService window;
  final AppSettings settings;
  final GameProgress progress;
  late final ProgressionService prog;
  final AquariumEngine engine = AquariumEngine();
  late GlyphCache glyphs;
  late final ValueNotifier<String> themeId;
  final ValueNotifier<String?> toast = ValueNotifier(null);
  final Random _rnd = Random();

  bool hudHover = false;

  /// Posição do cursor dentro da janela (null se fora). Atualizada pelo click-through.
  Offset? cursorLocal;

  /// Cursor relativo à janela, mesmo fora dela (o X vale para a faixa inteira).
  Offset? cursorAny;

  /// Ctrl pressionado: a faixa inteira captura o mouse e o clique solta comida.
  bool ctrlHeld = false;
  double _lastHint = -999;
  int _hints = 0;
  bool menuOpen = false;
  bool focused = true;

  Timer? _autosave;
  Timer? _debounce;
  Timer? _toastTimer;
  double _notifyT = 0;
  double _lastFeed = -10;
  double _lastInteract = -10;
  double _clock = 0;

  AsciiTheme get theme => themeById(settings.themeId);

  /// Cor atual do peixe (personalizada, arco-íris animado ou a do tema).
  Color fishColor(double t) {
    final fc = kFishColors.firstWhere(
      (c) => c.id == settings.fishColorId,
      orElse: () => kFishColors.first,
    );
    if (fc.rainbow) {
      // matiz em degraus de 6 graus: poucos valores distintos mantêm o cache de glifos estável
      final hue = (((t * 70) % 360) / 6).floor() * 6.0;
      return HSVColor.fromAHSV(1, hue, 0.6, 1).toColor();
    }
    return fc.color ?? theme.fish;
  }

  FishStage get stage => FishSprites.stageFor(progress.level);

  void start() {
    prog.applyOffline();
    engine
      ..onEat = _onEat
      ..onJump = (() => prog.onInteract())
      ..onRot = (() => progress.cleanliness = max(0, progress.cleanliness - 2));
    _syncEngine();
    engine.fish.x = 4;
    engine.fish.y = engine.rows - 4.0;
    _autosave = Timer.periodic(const Duration(seconds: 15), (_) => saveNow());
    saveNow();
    _initUpdates();
  }

  // ------------------------------------------------------------- atualizações

  String appVersion = '';
  UpdateInfo? update;
  bool updateBusy = false;
  String updateMsg = '';

  Future<void> _initUpdates() async {
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    notifyListeners();
    final day = const Duration(hours: 20).inMilliseconds;
    final due =
        DateTime.now().millisecondsSinceEpoch - settings.lastUpdateCheck > day;
    if (settings.autoUpdate && due) {
      await Future<void>.delayed(const Duration(seconds: 20));
      await checkUpdates(auto: true);
    }
  }

  Future<void> checkUpdates({bool auto = false}) async {
    if (updateBusy || appVersion.isEmpty) return;
    updateBusy = true;
    if (!auto) updateMsg = 'Procurando...';
    notifyListeners();
    try {
      update = await UpdateService.check(appVersion);
      settings.lastUpdateCheck = DateTime.now().millisecondsSinceEpoch;
      scheduleSave();
      if (update != null) {
        updateMsg = 'Versão ${update!.version} disponível';
        if (auto) showToast('Nova versão ${update!.version} em Opções');
      } else if (!auto) {
        updateMsg = 'Você está na versão mais recente';
      }
    } catch (_) {
      if (!auto) updateMsg = 'Não foi possível verificar (sem internet?)';
    }
    updateBusy = false;
    notifyListeners();
  }

  Future<void> installUpdate() async {
    final u = update;
    if (u == null || updateBusy) return;
    updateBusy = true;
    updateMsg = 'Baixando ${u.version}...';
    notifyListeners();
    try {
      await saveNow(); // garante o save antes do app fechar
      await UpdateService.downloadAndInstall(u);
    } catch (_) {
      updateBusy = false;
      updateMsg = 'Falha ao baixar a atualização';
      notifyListeners();
    }
  }

  void setAutoUpdate(bool v) {
    settings.autoUpdate = v;
    scheduleSave();
    notifyListeners();
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _debounce?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _syncEngine() {
    final o = progress.owned;
    engine.fish.width = FishSprites.widthFor(progress.level);
    engine.setPlantStyle(o.contains('decor_plants') ? 1 : 0);
    engine.oxygen = o.contains('decor_oxygen');
    engine.setCompanions(
      fishCompanion: o.contains('comp_fish'),
      crab: o.contains('comp_crab'),
      squid: o.contains('comp_squid'),
    );
  }

  // ---------------------------------------------------------------- loop

  void tick(double dt) {
    _clock += dt;
    prog.tickDecay(dt, dirt: engine.dirtCount);
    engine.cleanliness = progress.cleanliness;
    engine.hunger = progress.hunger;
    final w = FishSprites.widthFor(progress.level);
    if (engine.fish.width != w) engine.fish.width = w;
    engine.update(dt);
    _notifyT += dt;
    if (_notifyT >= 0.5) {
      _notifyT = 0;
      notifyListeners();
    }
  }

  void onLayout(Size size) {
    final cols = (size.width / glyphs.cell.width).floor();
    final rows = (size.height / glyphs.cell.height).floor();
    final water = (kWaterPx / glyphs.cell.height).ceil();
    if (cols != engine.cols ||
        rows != engine.rows ||
        water != engine.waterRows) {
      engine.waterRows = water;
      engine.resize(cols, rows);
    }
  }

  // ---------------------------------------------------------- interação

  /// Solta comida (botão, tecla F/Espaço ou clique na água). Também é o ponto de entrada
  /// para eventos externos (futuro NFC/serial): basta chamar `triggerFeed()`.
  void triggerFeed() {
    final c = cursorAny;
    if (c != null && c.dx >= 0 && c.dx <= window.size.width && !overPanel(c)) {
      feed(x: c.dx / glyphs.cell.width); // atalho: solta no X do mouse
    } else {
      feedNearFish();
    }
  }

  /// Botão Alimentar: um clique, a comida cai perto do peixe.
  void feedNearFish() {
    final f = engine.fish;
    feed(x: f.x + f.width / 2 + (_rnd.nextDouble() - 0.5) * 8);
  }

  void setCtrl(bool v) {
    if (ctrlHeld == v) return;
    ctrlHeld = v;
    notifyListeners();
  }

  void feed({double? x}) {
    if (_clock - _lastFeed < 0.5 || engine.foodCount >= 10) return;
    _lastFeed = _clock;
    final food = foodById(progress.foodId);
    final fx = x ?? (2 + _rnd.nextDouble() * max(1, engine.cols - 4));
    engine.dropFood(fx, food.id, bright: food.id == 'food_bright');
  }

  void clean() {
    final n = engine.cleanAll();
    if (n == 0) {
      showToast('Água já está limpa');
      return;
    }
    prog.onCleanAll(n);
    scheduleSave();
    notifyListeners();
  }

  /// Toque: limpa a sujeira tocada ou faz carinho no peixe.
  void tapAt(Offset px) {
    final cx = px.dx / glyphs.cell.width;
    final cy = px.dy / glyphs.cell.height;
    if (engine.cleanAt(cx, cy)) {
      prog.onCleanOne();
      scheduleSave();
      return;
    }
    final f = engine.fish;
    if (cx >= f.x - 1 && cx <= f.x + f.width + 1 && (cy - f.y).abs() <= 1.5) {
      engine.spawnBubbles(f.mouthX, f.y, 3);
      if (_clock - _lastInteract > 3) {
        _lastInteract = _clock;
        prog.onInteract();
        scheduleSave();
      }
      return;
    }
    if (ctrlHeld)
      feed(x: cx); // Ctrl+clique na água solta comida no X do clique
  }

  Offset? _lastCursor;
  double _lastClickJump = -10;

  /// Clique (em qualquer lugar da tela) com o X perto do X do peixe: ele salta na direção do clique.
  void globalClick(Offset local, {required bool inWindow}) {
    if (!settings.fishReacts) return;
    if (inWindow && overPanel(local)) return;
    if (local.dx < 0 || local.dx > window.size.width) return;
    if (_clock - _lastClickJump < 1.2) return;
    final cw = glyphs.cell.width, ch = glyphs.cell.height;
    final cx = local.dx / cw;
    final f = engine.fish;
    if ((cx - (f.x + f.width / 2)).abs() <= f.width / 2 + 5) {
      if (engine.jumpToward(cx, y: local.dy / ch)) _lastClickJump = _clock;
    }
  }

  /// Mouse em qualquer lugar da área de trabalho: enquanto ele se move, o peixe vem olhar (só o X
  /// importa; ele continua na água). Parado há ~3 s, o peixe volta a nadar sozinho.
  void passiveHover(Offset local, {required bool inWindow}) {
    final cw = glyphs.cell.width, ch = glyphs.cell.height;
    final moved = _lastCursor == null || (local - _lastCursor!).distance > 3;
    _lastCursor = local;
    if (local.dx < 0 || local.dx > window.size.width) return; // outro monitor
    if (inWindow && overPanel(local)) return;
    if (moved && inWindow && settings.fishReacts) {
      engine.attract(local.dx / cw, local.dy / ch);
    }
    // dica discreta (poucas vezes por sessão) ao passar sobre a água sem Ctrl
    if (inWindow &&
        local.dy >= engine.waterTop * ch &&
        !ctrlHeld &&
        _hints < 3 &&
        _clock - _lastHint > 90) {
      _lastHint = _clock;
      _hints++;
      showToast('Ctrl+clique na água para alimentar');
    }
  }

  // ------------------------------------------------- regiões interativas

  Rect dockRect(Size win) => Rect.fromLTWH(
    kPanelMargin,
    win.height - kPanelMargin - kDockSize.height,
    kDockSize.width,
    kDockSize.height,
  );

  Rect menuRect(Size win) => Rect.fromLTWH(
    kPanelMargin,
    win.height - kPanelMargin - kDockSize.height - 6 - kMenuSize.height,
    kMenuSize.width,
    kMenuSize.height,
  );

  bool overPanel(Offset p) {
    final win = window.size;
    return dockRect(win).inflate(4).contains(p) ||
        (menuOpen && menuRect(win).inflate(4).contains(p));
  }

  /// Onde o mouse deve ser capturado (o resto é click-through).
  bool isInteractiveAt(Offset p) {
    if (overPanel(p) || ctrlHeld) return true;
    final cw = glyphs.cell.width, ch = glyphs.cell.height;
    final f = engine.fish;
    if (Rect.fromLTWH(
      f.x * cw - 6,
      f.y * ch - 4,
      f.width * cw + 12,
      ch + 8,
    ).contains(p))
      return true;
    for (final d in engine.particles) {
      if (d.type == ParticleType.dirt &&
          Rect.fromLTWH(
            d.x * cw - cw * 0.9,
            d.y * ch - 4,
            cw * 2.8,
            ch + 8,
          ).contains(p)) {
        return true;
      }
    }
    return false;
  }

  void _onEat(Particle p) {
    prog.onEat(foodById(p.tag));
    scheduleSave();
  }

  // ------------------------------------------------------ loja & opções

  bool owns(ShopItem i) => progress.owned.contains(i.id);

  bool isEquipped(ShopItem i) => switch (i.category) {
    ShopCategory.theme => settings.themeId == i.id,
    ShopCategory.food => progress.foodId == i.id,
    ShopCategory.fishColor => settings.fishColorId == i.id,
    _ => owns(i),
  };

  void buy(ShopItem i) {
    if (owns(i)) return;
    if (progress.level < i.minLevel) {
      showToast('Requer nível ${i.minLevel}');
      return;
    }
    if (progress.pearls < i.price) {
      showToast('Pérolas insuficientes');
      return;
    }
    progress.pearls -= i.price;
    progress.owned.add(i.id);
    showToast('Comprou ${i.name}');
    _syncEngine();
    prog.checkAchievements();
    equip(i);
  }

  void equip(ShopItem i) {
    if (!owns(i)) return;
    if (i.category == ShopCategory.theme) {
      settings.themeId = i.id;
      themeId.value = i.id;
    } else if (i.category == ShopCategory.fishColor) {
      settings.fishColorId = i.id;
    } else if (i.category == ShopCategory.food) {
      progress.foodId = i.id;
    }
    scheduleSave();
    notifyListeners();
  }

  Future<void> setAlwaysOnTop(bool v) async {
    await window.setAlwaysOnTop(v);
    scheduleSave();
    notifyListeners();
  }

  Future<void> setWidgetMode(bool v) async {
    await window.setWidgetMode(v);
    scheduleSave();
    notifyListeners();
  }

  // ------------------------------------------------------------- debug

  void setDebugMode(bool v) {
    settings.debugMode = v;
    scheduleSave();
    notifyListeners();
  }

  void debugAddPearls(int n) {
    progress.pearls += n;
    notifyListeners();
    scheduleSave();
  }

  void debugAddLevels(int n) {
    for (var i = 0; i < n; i++) {
      prog.addXp(progress.xpToNextLevel - progress.xp);
    }
    notifyListeners();
    scheduleSave();
  }

  void debugUnlockAll() {
    for (final it in kShopItems) {
      progress.owned.add(it.id);
    }
    _syncEngine();
    prog.checkAchievements();
    showToast('Tudo desbloqueado');
    notifyListeners();
    scheduleSave();
  }

  void debugSpawnDirt() {
    engine.spawnDirt(8);
    notifyListeners();
  }

  void debugJump() => engine.forceJump();

  void debugSetHunger(double v) {
    progress.hunger = v;
    notifyListeners();
  }

  void debugReset() {
    progress
      ..level = 1
      ..xp = 0
      ..pearls = 20
      ..hunger = 80
      ..happiness = 80
      ..cleanliness = 100
      ..feedCount = 0
      ..cleanCount = 0
      ..interactCount = 0
      ..foodId = 'food_basic'
      ..owned.clear()
      ..owned.addAll({'theme_oled', 'food_basic', 'fcolor_default'})
      ..achievements.clear()
      ..daysCared.clear();
    settings
      ..themeId = 'theme_oled'
      ..fishColorId = 'fcolor_default';
    themeId.value = 'theme_oled';
    _syncEngine();
    showToast('Progresso resetado');
    notifyListeners();
    scheduleSave();
  }

  void setFishReacts(bool v) {
    settings.fishReacts = v;
    scheduleSave();
    notifyListeners();
  }

  void setAutoHideHud(bool v) {
    settings.autoHideHud = v;
    scheduleSave();
    notifyListeners();
  }

  void setFontSize(double v) {
    settings.fontSize = v;
    glyphs = GlyphCache(v);
    scheduleSave();
    notifyListeners();
  }

  Future<void> snapToCorner() => window.dock(
    height: menuOpen
        ? max(settings.windowHeight ?? 200, kMenuWindowHeight)
        : null,
  );

  void setHover(bool v) {
    if (hudHover == v) return;
    hudHover = v;
    notifyListeners();
  }

  void setMenu(bool v) {
    menuOpen = v;
    window.dock(
      height: v ? max(settings.windowHeight ?? 200, kMenuWindowHeight) : null,
    );
    notifyListeners();
  }

  void setWindowHeight(double h) {
    settings.windowHeight = h;
    if (!menuOpen) window.dock();
    scheduleSave();
    notifyListeners();
  }

  void showToast(String msg) {
    toast.value = msg;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () => toast.value = null);
  }

  // ------------------------------------------------------------- save

  void scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), saveNow);
  }

  Future<void> saveNow() async {
    progress.lastSavedAt = DateTime.now();
    await repo.save(settings, progress);
  }
}
