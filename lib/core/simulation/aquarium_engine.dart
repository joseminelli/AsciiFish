import 'dart:math';

import '../models/fish_state.dart';
import '../models/particle.dart';
import '../models/plant.dart';

/// Motor de simulação em Dart puro. Unidades: células (colunas / linhas) em ponto flutuante.
/// Linha 0 = superfície, linha `rows-1` = areia, plantas/sujeira em `rows-2`.
class AquariumEngine {
  AquariumEngine({int? seed}) : _rnd = Random(seed);

  final Random _rnd;
  int cols = 40;
  int rows = 14;
  double time = 0;

  final FishState fish = FishState();
  final List<Particle> particles = [];
  final List<Plant> plants = [];
  final List<Critter> companions = [];

  /// Escritos pelo controlador a cada frame.
  double cleanliness = 100;
  double hunger = 100;
  bool oxygen = false;
  int plantStyle = 0;

  /// Chamado quando o peixe come um floco.
  void Function(Particle food)? onEat;

  double _bubbleT = 1;
  double _dirtT = 3;
  double _wanderT = 0;
  double _mouthT = 4;
  double _curiousT = 0;
  double _curiousX = 0;
  double _curiousY = 0;
  double _tx = 10;
  double _ty = 5;

  int get dirtCount => particles.where((p) => p.type == ParticleType.dirt).length;
  int get foodCount => particles.where((p) => p.type == ParticleType.food).length;

  double get _minY => 1;
  double get _maxY => max(_minY, rows - 3.0);

  void resize(int c, int r) {
    cols = max(c, 20);
    rows = max(r, 8);
    _buildPlants();
    fish.x = fish.x.clamp(0, max(0, cols - fish.width)).toDouble();
    fish.y = fish.y.clamp(_minY, _maxY).toDouble();
    for (final p in particles) {
      p.x0 = p.x0.clamp(0, cols - 1).toDouble();
      if (p.type == ParticleType.dirt || p.settled) p.y = rows - 2.0;
    }
  }

  void setPlantStyle(int style) {
    if (style == plantStyle) return;
    plantStyle = style;
    _buildPlants();
  }

  void setCompanions({required bool fishCompanion, required bool shrimp}) {
    companions.removeWhere((c) => (c.kind == 'fish' && !fishCompanion) || (c.kind == 'shrimp' && !shrimp));
    if (fishCompanion && !companions.any((c) => c.kind == 'fish')) {
      companions.add(Critter('fish', _rnd.nextDouble() * cols, 2 + _rnd.nextDouble() * 3));
    }
    if (shrimp && !companions.any((c) => c.kind == 'shrimp')) {
      companions.add(Critter('shrimp', _rnd.nextDouble() * cols, rows - 2.0));
    }
  }

  void _buildPlants() {
    plants.clear();
    final r = Random(7);
    final n = (cols / (plantStyle == 1 ? 7 : 11)).round().clamp(2, 14);
    final maxH = max(2, (rows * (plantStyle == 1 ? 0.55 : 0.4)).floor());
    for (var i = 0; i < n; i++) {
      plants.add(Plant(
        x: (i + 0.5) * cols / n + (r.nextDouble() - 0.5) * 2,
        height: 2 + r.nextInt(maxH - 1),
        freq: 1.2 + r.nextDouble() * 1.2,
        phase: r.nextDouble() * pi * 2,
      ));
    }
  }

  // ---------------------------------------------------------------- ações

  /// Solta flocos de comida no topo.
  void dropFood(double x, String tag, {int count = 3, bool bright = false}) {
    for (var i = 0; i < count; i++) {
      final fx = (x + (_rnd.nextDouble() - 0.5) * 3).clamp(0, cols - 1).toDouble();
      final p = Particle(ParticleType.food, fx, 0.5 - i * 0.7, const ['*', '•', '.'][_rnd.nextInt(3)],
          tag: tag, bright: bright)
        ..phase = _rnd.nextDouble() * pi * 2
        ..vy = 0.5;
      particles.add(p);
    }
  }

  /// Remove toda a sujeira. Retorna quantas partículas foram limpas.
  int cleanAll() {
    final before = particles.length;
    particles.removeWhere((p) => p.type == ParticleType.dirt);
    return before - particles.length;
  }

  /// Remove a sujeira mais próxima do ponto (em células). Retorna true se limpou algo.
  bool cleanAt(double x, double y) {
    Particle? best;
    var bestD = double.infinity;
    for (final p in particles) {
      if (p.type != ParticleType.dirt) continue;
      final d = (p.x - x).abs() + (p.y - y).abs() * 2;
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    if (best != null && bestD <= 3.5) {
      particles.remove(best);
      return true;
    }
    return false;
  }

  /// Atrai a atenção do peixe para um ponto (hover/toque).
  void attract(double x, double y) {
    _curiousX = x;
    _curiousY = y;
    _curiousT = 3;
  }

  void spawnBubbles(double x, double y, int n, {bool bright = false}) {
    for (var i = 0; i < n; i++) {
      final size = _rnd.nextInt(3);
      final p = Particle(ParticleType.bubble, x + (_rnd.nextDouble() - 0.5), y - i * 0.4,
          const ['.', '°', 'o'][size], bright: bright)
        ..vy = 1.5 + _rnd.nextDouble() * 2 + size * 0.4
        ..phase = _rnd.nextDouble() * pi * 2;
      particles.add(p);
    }
  }

  // ----------------------------------------------------------- simulação

  void update(double dt) {
    time += dt;
    _spawn(dt);
    _updateFish(dt);
    _updateParticles(dt);
    _updateCompanions(dt);
  }

  void _spawn(double dt) {
    _bubbleT -= dt;
    if (_bubbleT <= 0) {
      _bubbleT = (oxygen ? 0.5 : 2.5) + _rnd.nextDouble() * (oxygen ? 0.8 : 3);
      final x = oxygen ? cols * 0.12 : _rnd.nextDouble() * cols;
      spawnBubbles(x, rows - 2.0, 1);
    }
    _dirtT -= dt;
    if (_dirtT <= 0) {
      final dirtiness = (100 - cleanliness) / 100;
      _dirtT = 4 + _rnd.nextDouble() * 4 - dirtiness * 3;
      if (dirtCount < 14) {
        particles.add(Particle(ParticleType.dirt, _rnd.nextDouble() * (cols - 1), rows - 2.0,
            const [',', '.', ';', '`'][_rnd.nextInt(4)]));
      }
    }
  }

  Particle? _nearestFood() {
    Particle? best;
    var bestD = double.infinity;
    for (final p in particles) {
      if (p.type != ParticleType.food) continue;
      final d = (p.x - fish.x).abs() + (p.y - fish.y).abs() * 2;
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best;
  }

  void _updateFish(double dt) {
    final f = fish;
    final activity = 0.5 + 0.5 * (cleanliness / 100);
    final tired = hunger < 25 ? 0.6 : 1.0;
    final food = _nearestFood();
    double tx, ty, speed;

    if (food != null) {
      f.mode = FishMode.seekingFood;
      tx = food.x > f.x + f.width / 2 ? food.x - f.width : food.x;
      ty = food.y;
      speed = 10;
    } else if (_curiousT > 0) {
      f.mode = FishMode.curious;
      _curiousT -= dt;
      tx = _curiousX > f.x + f.width / 2 ? _curiousX - f.width : _curiousX;
      ty = _curiousY;
      speed = 6;
    } else {
      f.mode = FishMode.wandering;
      _wanderT -= dt;
      if (_wanderT <= 0) {
        _wanderT = 2.5 + _rnd.nextDouble() * 3.5;
        _tx = _rnd.nextDouble() * max(1, cols - f.width);
        _ty = _minY + _rnd.nextDouble() * (_maxY - _minY);
      }
      tx = _tx;
      ty = _ty;
      speed = 3.5 * activity * tired;
    }

    final dx = tx - f.x;
    final dy = ty - f.y;
    final d = sqrt(dx * dx + dy * dy * 4); // linhas são ~2x mais altas que colunas
    var dvx = 0.0, dvy = 0.0;
    if (d > 0.3) {
      final s = f.mode == FishMode.wandering ? speed * min(1.0, d / 3) : speed;
      dvx = dx / d * s;
      dvy = dy / d * s;
    }
    dvy += sin(time * 1.7) * 0.4;
    final k = min(1.0, 2.2 * dt);
    f.vx += (dvx - f.vx) * k;
    f.vy += (dvy - f.vy) * k;
    f.x += f.vx * dt;
    f.y += f.vy * dt;

    final maxX = max(0, cols - f.width).toDouble();
    if (f.x < 0) {
      f.x = 0;
      f.vx = max(0, f.vx);
    } else if (f.x > maxX) {
      f.x = maxX;
      f.vx = min(0, f.vx);
    }
    if (f.y < _minY) {
      f.y = _minY;
      f.vy = max(0, f.vy);
    } else if (f.y > _maxY) {
      f.y = _maxY;
      f.vy = min(0, f.vy);
    }

    // Inversão de direção com histerese: o peixe desacelera, passa por zero e então vira.
    if (f.vx > 0.6 && f.facing < 0) f.facing = 1;
    if (f.vx < -0.6 && f.facing > 0) f.facing = -1;
    f.tailPhase += dt * (2 + sqrt(f.vx * f.vx + f.vy * f.vy) * 1.2);

    // Bolhas pela boca.
    _mouthT -= dt;
    if (_mouthT <= 0) {
      _mouthT = 4 + _rnd.nextDouble() * 5;
      spawnBubbles(f.mouthX, f.y, 1 + _rnd.nextInt(2));
    }

    // Comer.
    for (final p in List<Particle>.of(particles)) {
      if (p.type != ParticleType.food) continue;
      if ((p.x - f.mouthX).abs() < 1.6 && (p.y - f.y).abs() < 1.3) {
        particles.remove(p);
        onEat?.call(p);
        spawnBubbles(f.mouthX, f.y, p.bright ? 6 : 2, bright: p.bright);
      }
    }
  }

  void _updateParticles(double dt) {
    for (final p in List<Particle>.of(particles)) {
      p.age += dt;
      switch (p.type) {
        case ParticleType.bubble:
          p.y -= p.vy * dt;
          p.x = p.x0 + sin(time * 2.2 + p.phase) * 0.6;
          if (p.y < 0.6) particles.remove(p);
        case ParticleType.food:
          if (p.settled) {
            if (p.age > 7) {
              // comida esquecida apodrece e vira sujeira
              particles.remove(p);
              particles.add(Particle(ParticleType.dirt, p.x0, rows - 2.0, ';'));
              onRot?.call();
            }
          } else {
            p.vy += (2.2 - p.vy) * min(1.0, 1.5 * dt);
            p.y += p.vy * dt;
            p.x = p.x0 + sin(time * 2 + p.phase) * 0.5;
            if (p.y >= rows - 2) {
              p.y = rows - 2.0;
              p.settled = true;
              p.age = 0;
            }
          }
        case ParticleType.dirt:
          break;
      }
    }
  }

  /// Chamado quando comida esquecida vira sujeira.
  void Function()? onRot;

  void _updateCompanions(double dt) {
    for (final c in companions) {
      c.timer -= dt;
      if (c.kind == 'fish') {
        if (c.timer <= 0) {
          c.timer = 2 + _rnd.nextDouble() * 4;
          c.tx = _rnd.nextDouble() * (cols - 3);
          c.ty = _minY + _rnd.nextDouble() * (_maxY - _minY);
        }
        final dx = c.tx - c.x, dy = c.ty - c.y;
        final d = max(0.001, sqrt(dx * dx + dy * dy * 4));
        final s = 2.5 * min(1.0, d / 3);
        c.vx += (dx / d * s - c.vx) * min(1.0, 2 * dt);
        c.vy += (dy / d * s - c.vy) * min(1.0, 2 * dt);
        c.x = (c.x + c.vx * dt).clamp(0, cols - 3).toDouble();
        c.y = (c.y + c.vy * dt).clamp(_minY, _maxY).toDouble();
        if (c.vx > 0.4) c.facing = 1;
        if (c.vx < -0.4) c.facing = -1;
      } else {
        c.y = rows - 2.0;
        if (c.timer <= 0) {
          c.timer = 1.5 + _rnd.nextDouble() * 4;
          c.tx = _rnd.nextBool() ? _rnd.nextDouble() * (cols - 4) : c.x; // às vezes pausa
        }
        final dx = c.tx - c.x;
        if (dx.abs() > 0.2) {
          c.facing = dx > 0 ? 1 : -1;
          c.x = (c.x + dx.sign * 1.6 * dt).clamp(0, cols - 4).toDouble();
        }
      }
    }
  }
}
