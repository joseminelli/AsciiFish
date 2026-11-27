import 'dart:math';

import '../models/fish_sprites.dart';
import '../models/game_progress.dart';
import '../models/shop_catalog.dart';

class Achievement {
  const Achievement(this.id, this.name, this.desc, this.target);
  final String id;
  final String name;
  final String desc;

  /// Valor a atingir (ex.: 5 limpezas). O valor atual vem de [achievementValue].
  final int target;
}

/// Valor atual do progresso de uma conquista (para a barra no Status).
int achievementValue(String id, GameProgress p) => switch (id) {
  'first_meal' => p.feedCount,
  'clean_water' => p.cleanCount,
  'level5' => p.level,
  'theme_collector' => p.owned.where((o) => o.startsWith('theme_')).length,
  'three_days' => p.daysCared.length,
  'pet_20' => p.interactCount,
  _ => 0,
};

const kAchievements = [
  Achievement(
    'first_meal',
    'Primeira Refeição',
    'Alimente o peixe pela primeira vez.',
    1,
  ),
  Achievement('clean_water', 'Água Cristalina', 'Limpe o aquário 5 vezes.', 5),
  Achievement('level5', 'Nível 5', 'Alcance o nível 5.', 5),
  Achievement('theme_collector', 'Colecionador de Temas', 'Possua 3 temas.', 3),
  Achievement(
    'three_days',
    '3 Dias de Cuidado',
    'Cuide do peixe em 3 dias diferentes.',
    3,
  ),
  Achievement(
    'pet_20',
    'Melhor Amigo',
    'Faça 20 carinhos (toque no peixe) ou veja-o pular.',
    20,
  ),
];

/// XP, níveis, moedas, conquistas e decaimento (online e offline). Sem dependência de Flutter.
class ProgressionService {
  ProgressionService(this.p, {this.onMessage});

  final GameProgress p;
  void Function(String message)? onMessage;

  static const hungerDecay = 0.035; // por segundo
  static const cleanDecay = 0.008;
  static const dirtDecay = 0.002; // por sujeira na água
  static const maxOfflineSeconds = 10 * 3600;

  double _passiveT = 0;

  double _c(double v) => v.clamp(0.0, 100.0).toDouble();

  /// [joy]: alegria passiva por segundo vinda de companheiros e decorações.
  void tickDecay(double dt, {int dirt = 0, double joy = 0}) {
    p.hunger = _c(p.hunger - hungerDecay * dt);
    p.cleanliness = _c(p.cleanliness - (cleanDecay + dirtDecay * dirt) * dt);
    final good = p.hunger > 50 && p.cleanliness > 50;
    // companhia e decoração fazem o humor subir mais rápido e cair mais devagar
    final delta = good ? 0.004 + joy : -0.02 + joy * 2;
    p.happiness = _c(p.happiness + delta * dt);

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
    // comer alegra; comer com fome alegra mais (empanturrado não)
    p.happiness = _c(
      p.happiness + (before >= 95 ? 0.5 : (before < 40 ? 4 : 2.5)),
    );
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
    p.happiness = _c(p.happiness + 2);
    p.cleanCount++;
    addXp(1);
    checkAchievements();
  }

  void onCleanAll(int count) {
    if (count == 0) return;
    p.cleanliness = _c(p.cleanliness + 4 * count + 10);
    p.happiness = _c(p.happiness + 4 + count.clamp(0, 6));
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

  /// Carinho (toque no peixe): mais humor que um pulo, com recompensa rara em pérola.
  void onPet() {
    p.happiness = _c(p.happiness + 3);
    p.interactCount++;
    addXp(1);
    if (p.interactCount % 10 == 0) p.pearls += 1;
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
    for (final a in kAchievements) {
      if (!p.achievements.contains(a.id) &&
          achievementValue(a.id, p) >= a.target) {
        p.achievements.add(a.id);
        p.pearls += 15;
        onMessage?.call('Conquista: ${a.name} (+15)');
      }
    }
  }
}
