import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/models/app_settings.dart';
import '../core/models/ascii_theme.dart';
import '../core/models/fish_sprites.dart';
import '../core/models/game_progress.dart';
import '../core/models/particle.dart';
import '../core/models/shop_catalog.dart';
import '../core/simulation/aquarium_engine.dart';
import '../core/simulation/progression_service.dart';
import '../core/storage/save_repository.dart';
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
  double _armedUntil = -1;
  bool get feedArmed => _clock < _armedUntil;
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
      shrimp: o.contains('comp_shrimp'),
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
    final c = cursorLocal;
    if (c != null && !overPanel(c)) {
      feed(x: c.dx / glyphs.cell.width); // atalho: solta no X do mouse
    } else {
      armFeed();
    }
  }

  /// Botão Alimentar: o próximo clique em qualquer lugar da faixa solta a comida naquele X.
  void armFeed() {
    _armedUntil = _clock + 6;
    showToast('Clique onde soltar a comida');
    notifyListeners();
  }

  void cancelFeed() {
    _armedUntil = -1;
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
    if (feedArmed && !overPanel(px)) {
      _armedUntil = -1;
      feed(x: cx);
      notifyListeners();
      return;
    }
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
    }
  }

  /// Cursor sobre a água (mesmo em click-through): o peixe vem olhar.
  void passiveHover(Offset local) {
    final cw = glyphs.cell.width, ch = glyphs.cell.height;
    if (local.dy >= engine.waterTop * ch && !overPanel(local)) {
      engine.attract(local.dx / cw, local.dy / ch);
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
    if (overPanel(p) || feedArmed) return true;
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
            d.x * cw - 5,
            d.y * ch - 5,
            cw + 10,
            ch + 10,
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
