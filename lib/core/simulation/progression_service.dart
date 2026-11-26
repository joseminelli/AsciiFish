import 'dart:math';

import '../models/fish_sprites.dart';
import '../models/game_progress.dart';
import '../models/shop_catalog.dart';

class Achievement {
  const Achievement(this.id, this.name, this.desc);
  final String id;
  final String name;
  final String desc;
}

const kAchievements = [
  Achievement(
    'first_meal',
    'Primeira Refeição',
    'Alimente o peixe pela primeira vez.',
  ),
  Achievement('clean_water', 'Água Cristalina', 'Limpe o aquário 5 vezes.'),
  Achievement('level5', 'Nível 5', 'Alcance o nível 5.'),
  Achievement('theme_collector', 'Colecionador de Temas', 'Possua 3 temas.'),
  Achievement(
    'three_days',
    '3 Dias de Cuidado',
    'Cuide do peixe em 3 dias diferentes.',
  ),
];

/// XP, níveis, moedas, conquistas e decaimento (online e offline). Sem dependência de Flutter.
class ProgressionService {
  ProgressionService(this.p, {this.onMessage});

  final GameProgress p;
  void Function(String message)? onMessage;

  static const hungerDecay = 0.035; // por segundo
  static const cleanDecay = 0.012;
  static const maxOfflineSeconds = 10 * 3600;

  double _passiveT = 0;

  double _c(double v) => v.clamp(0.0, 100.0).toDouble();

  void tickDecay(double dt, {int dirt = 0}) {
    p.hunger = _c(p.hunger - hungerDecay * dt);
    p.cleanliness = _c(p.cleanliness - (cleanDecay + 0.004 * dirt) * dt);
    final good = p.hunger > 50 && p.cleanliness > 50;
    p.happiness = _c(p.happiness + (good ? 0.004 : -0.02) * dt);

    _passiveT += dt;
    if (_passiveT >= 60) {
      _passiveT = 0;
      if (p.hunger > 70 && p.happiness > 70 && p.cleanliness > 70) addXp(2);
      markDay();
    }
  }

  /// Decaimento suave com teto e piso: o peixe nunca fica irreversivelmente punido.
  void applyOffline() {
    final away = DateTime.now().difference(p.lastSavedAt);
    if (away.inMinutes < 1) return;
    final secs = min(away.inSeconds, maxOfflineSeconds) * 0.5;
    double soft(double old, double decay, double floor) =>
        _c(max(old - decay * secs, min(old, floor)));
    p.hunger = soft(p.hunger, hungerDecay, 25);
    p.cleanliness = soft(p.cleanliness, cleanDecay, 30);
    p.happiness = soft(p.happiness, 0.01, 30);
    markDay();
    onMessage?.call('Bem-vindo de volta!');
  }

  void markDay() {
    final n = DateTime.now();
    final key =
        '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    if (p.daysCared.add(key)) checkAchievements();
  }

  void onEat(FoodDef f) {
    final before = p.hunger;
    p.hunger = _c(p.hunger + f.hunger);
    p.happiness = _c(p.happiness + 1.5);
    p.feedCount++;
    if (before >= 95) {
      p.cleanliness = _c(
        p.cleanliness - 1.5,
      ); // empanturrado: sem XP, suja a água
    } else {
      addXp(before < 40 ? f.xp * 2 : f.xp); // alimentar com fome rende bônus
      if (before < 60) p.pearls += 1;
    }
    markDay();
    checkAchievements();
  }

  void onCleanOne() {
    p.cleanliness = _c(p.cleanliness + 4);
    p.happiness = _c(p.happiness + 1);
    p.cleanCount++;
    addXp(1);
    checkAchievements();
  }

  void onCleanAll(int count) {
    if (count == 0) return;
    p.cleanliness = _c(p.cleanliness + 4 * count + 10);
    p.happiness = _c(p.happiness + 3);
    p.cleanCount++;
    addXp(3 + count);
    if (count >= 3) p.pearls += 1;
    markDay();
    checkAchievements();
  }

  void onInteract() {
    p.happiness = _c(p.happiness + 0.8);
    p.interactCount++;
    addXp(1);
  }

  void addXp(int n) {
    final oldStage = FishSprites.stageFor(p.level).name;
    p.xp += n;
    while (p.xp >= p.xpToNextLevel) {
      p.xp -= p.xpToNextLevel;
      p.level++;
      final reward = 10 + p.level;
      p.pearls += reward;
      onMessage?.call('Nível ${p.level}! +$reward pérolas');
    }
    final newStage = FishSprites.stageFor(p.level).name;
    if (newStage != oldStage) onMessage?.call('Evoluiu: $newStage!');
    checkAchievements();
  }

  void checkAchievements() {
    bool ok(String id) => switch (id) {
      'first_meal' => p.feedCount >= 1,
      'clean_water' => p.cleanCount >= 5,
      'level5' => p.level >= 5,
      'theme_collector' =>
        p.owned.where((o) => o.startsWith('theme_')).length >= 3,
      'three_days' => p.daysCared.length >= 3,
      _ => false,
    };
    for (final a in kAchievements) {
      if (!p.achievements.contains(a.id) && ok(a.id)) {
        p.achievements.add(a.id);
        p.pearls += 15;
        onMessage?.call('Conquista: ${a.name} (+15)');
      }
    }
  }
}
