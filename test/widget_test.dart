import 'package:ascii_fish_pet/core/models/fish_sprites.dart';
import 'package:ascii_fish_pet/core/models/game_progress.dart';
import 'package:ascii_fish_pet/core/models/shop_catalog.dart';
import 'package:ascii_fish_pet/core/simulation/aquarium_engine.dart';
import 'package:ascii_fish_pet/core/simulation/progression_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('motor mantém o peixe dentro do aquário', () {
    final e = AquariumEngine(seed: 1)..resize(40, 14);
    for (var i = 0; i < 6000; i++) {
      e.update(1 / 60);
      expect(e.fish.x, inInclusiveRange(0, 40));
      expect(e.fish.y, inInclusiveRange(0, 11)); // pode estar no ar durante um pulo
    }
  });

  test('peixe pula para fora da agua e volta', () {
    final e = AquariumEngine(seed: 3)
      ..waterRows = 6
      ..resize(60, 16);
    var jumps = 0;
    e.onJump = () => jumps++;
    var maxAir = 0.0;
    for (var i = 0; i < 60 * 150; i++) {
      e.update(1 / 60);
      if (e.fish.y < e.waterTop) maxAir = maxAir < e.waterTop - e.fish.y ? e.waterTop - e.fish.y : maxAir;
    }
    expect(jumps, greaterThan(0));
    expect(maxAir, greaterThan(0.5));
    expect(e.fish.y, greaterThanOrEqualTo(e.waterTop)); // terminou na agua
  });

  test('peixe pula para pegar comida que cai no ar', () {
    var pulou = 0;
    var comeu = 0;
    for (final seed in [1, 2, 3, 4, 5]) {
      final e = AquariumEngine(seed: seed)
        ..waterRows = 6
        ..resize(80, 18);
      e.onEat = (_) => comeu++;
      e.dropFood(40, 'food_basic');
      var jumped = false;
      for (var i = 0; i < 60 * 12; i++) {
        e.update(1 / 60);
        if (e.fish.y < e.waterTop) jumped = true;
      }
      if (jumped) pulou++;
    }
    expect(pulou, greaterThanOrEqualTo(3)); // na maioria dos casos ele salta
    expect(comeu, greaterThanOrEqualTo(10)); // e a comida é comida
  });

  test('peixe come a comida solta', () {
    final e = AquariumEngine(seed: 2)..resize(40, 14);
    var eaten = 0;
    e.onEat = (_) => eaten++;
    e.dropFood(20, 'food_basic');
    for (var i = 0; i < 60 * 20; i++) {
      e.update(1 / 60);
    }
    expect(eaten, greaterThan(0));
  });

  test('sprites espelham corretamente e evoluem por nível', () {
    expect(FishSprites.frame(3, facingRight: false, tail: 0), '<o))))><');
    expect(FishSprites.frame(3, facingRight: true, tail: 0), '><((((o>');
    expect(FishSprites.stageFor(1).name, 'Alevino');
    expect(FishSprites.stageFor(10).name, 'Peixe-anjo');
  });

  test('XP sobe de nível e concede pérolas', () {
    final p = GameProgress();
    final s = ProgressionService(p);
    s.addXp(p.xpToNextLevel);
    expect(p.level, 2);
    expect(p.pearls, greaterThan(20));
  });

  test('offline tem piso: peixe nunca morre de fome', () {
    final p = GameProgress(hunger: 60, lastSavedAt: DateTime.now().subtract(const Duration(days: 5)));
    ProgressionService(p).applyOffline();
    expect(p.hunger, greaterThanOrEqualTo(25));
  });

  test('comer com fome rende bônus de XP', () {
    final hungry = GameProgress(hunger: 20);
    final full = GameProgress(hunger: 70);
    ProgressionService(hungry).onEat(kFoods.first);
    ProgressionService(full).onEat(kFoods.first);
    expect(hungry.xp, greaterThan(full.xp));
  });
}
