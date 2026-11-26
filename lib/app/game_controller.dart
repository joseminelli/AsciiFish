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
      ..onRot = (() => progress.cleanliness = max(0, progress.cleanliness - 2));
    _syncEngine();
    engine.fish.x = 4;
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
    engine.setCompanions(fishCompanion: o.contains('comp_fish'), shrimp: o.contains('comp_shrimp'));
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
    if (cols != engine.cols || rows != engine.rows) engine.resize(cols, rows);
  }

  // ---------------------------------------------------------- interação

  /// Solta comida (botão, tecla F/Espaço ou clique na água). Também é o ponto de entrada
  /// para eventos externos (futuro NFC/serial): basta chamar `triggerFeed()`.
  void triggerFeed() => feed();

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

  /// Toque no aquário: limpa sujeira próxima ou solta comida.
  void tapAt(Offset px) {
    final cx = px.dx / glyphs.cell.width;
    final cy = px.dy / glyphs.cell.height;
    if (engine.cleanAt(cx, cy)) {
      prog.onCleanOne();
      scheduleSave();
    } else {
      feed(x: cx);
    }
  }

  void hoverAt(Offset px) {
    final cx = px.dx / glyphs.cell.width;
    final cy = px.dy / glyphs.cell.height;
    engine.attract(cx, cy);
    if (_clock - _lastInteract > 6) {
      _lastInteract = _clock;
      prog.onInteract();
      engine.spawnBubbles(engine.fish.mouthX, engine.fish.y, 2);
    }
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
    settings.alwaysOnTop = v;
    await window.setAlwaysOnTop(v);
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

  Future<void> snapToCorner() => window.snapToCorner();

  void setHover(bool v) {
    if (hudHover == v) return;
    hudHover = v;
    notifyListeners();
  }

  void setMenu(bool v) {
    menuOpen = v;
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
