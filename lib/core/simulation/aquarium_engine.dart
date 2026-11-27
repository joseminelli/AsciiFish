import 'dart:math';

import '../models/critter_sprites.dart';
import '../models/fish_sprites.dart';
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

  /// Profundidade da água em linhas (ancorada na base). Acima dela é ar (transparente).
  int waterRows = 6;
  int get _wr => waterRows.clamp(4, max(4, rows - 1));
  int get waterTop => max(0, rows - _wr);
  int get airRows => waterTop;
  double time = 0;

  final FishState fish = FishState();
  final List<Particle> particles = [];
  final List<Plant> plants = [];
  final List<Plant> backPlants = []; // camada de fundo (mais baixa e apagada)
  final List<Ghost> ghosts = []; // silhuetas distantes
  final List<Critter> companions = [];

  /// Escritos pelo controlador a cada frame.
  double cleanliness = 100;
  double hunger = 100;
  double happiness = 80;
  bool oxygen = false;
  int plantStyle = 0;

  /// Chamado quando o peixe come um floco.
  void Function(Particle food)? onEat;

  /// Chamado quando o peixe pula para fora da agua.
  void Function()? onJump;
  static const _g = 16.0; // gravidade do pulo (linhas/s^2)
  double _jumpT = 25;

  double _bubbleT = 1;
  double _dirtT = 30;
  double _heartT = 12;
  double _blinkT = 3;
  double _eatT = 0;
  double _turnT = 0;
  double _ghostT = 10;
  double _schoolT = 35; // próximo cardume
  int _lastFacing = 1;
  double _wanderT = 0;
  double _mouthT = 4;
  double _curiousT = 0;
  double _curiousX = 0;
  double _curiousY = 0;
  double _tx = 10;
  double _ty = 5;

  int get dirtCount => _count(ParticleType.dirt);
  int get foodCount => _count(ParticleType.food);

  // contagem sem alocar lista (chamada várias vezes por frame)
  int _count(ParticleType t) {
    var n = 0;
    for (final p in particles) {
      if (p.type == t) n++;
    }
    return n;
  }

  double get _minY => waterTop + 1.0;
  double get _maxY => max(_minY, rows - 3.0);

  void resize(int newCols, int newRows) {
    final nr = max(newRows, 8);
    final d = nr - rows; // tudo e ancorado na base: desloca junto com a altura
    cols = max(newCols, 20);
    rows = nr;
    if (d != 0) {
      fish.y += d;
      for (final p in particles) {
        p.y += d;
      }
      for (final c in companions) {
        c.y += d;
      }
    }
    _buildPlants();
    fish.x = fish.x.clamp(0, max(0, cols - fish.width)).toDouble();
    fish.y = fish.mode == FishMode.jumping
        ? fish.y.clamp(0, _maxY).toDouble()
        : fish.y.clamp(_minY, _maxY).toDouble();
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

  void setCompanions({
    required bool fishCompanion,
    required bool crab,
    required bool squid,
  }) {
    bool want(String k) => switch (k) {
      'fish' => fishCompanion,
      'crab' => crab,
      _ => squid,
    };
    companions.removeWhere((c) => !want(c.kind));
    for (final k in const ['fish', 'crab', 'squid']) {
      if (want(k) && !companions.any((c) => c.kind == k)) {
        final w = CritterSprites.widthOf(k);
        final x = _rnd.nextDouble() * max(1, cols - w);
        final y = k == 'crab'
            ? rows - 2.0
            : _minY + _rnd.nextDouble() * (_maxY - _minY);
        companions.add(Critter(k, x, y)..width = w);
      }
    }
  }

  void _buildPlants() {
    plants.clear();
    backPlants.clear();
    final rb = Random(11);
    final nb = (cols / 6).round().clamp(3, 20);
    final maxB = max(2, (_wr * 0.3).floor());
    for (var i = 0; i < nb; i++) {
      backPlants.add(
        Plant(
          x: (i + 0.5) * cols / nb + (rb.nextDouble() - 0.5) * 3,
          height: 1 + rb.nextInt(maxB),
          freq: 0.8 + rb.nextDouble() * 0.8,
          phase: rb.nextDouble() * pi * 2,
        ),
      );
    }
    final r = Random(7);
    final n = (cols / (plantStyle == 1 ? 7 : 11)).round().clamp(2, 14);
    final maxH = max(2, (_wr * (plantStyle == 1 ? 0.55 : 0.4)).floor());
    for (var i = 0; i < n; i++) {
      plants.add(
        Plant(
          x: (i + 0.5) * cols / n + (r.nextDouble() - 0.5) * 2,
          height: 2 + r.nextInt(maxH - 1),
          freq: 1.2 + r.nextDouble() * 1.2,
          phase: r.nextDouble() * pi * 2,
        ),
      );
    }
  }

  // ---------------------------------------------------------------- ações

  /// Solta flocos de comida no topo.
  void dropFood(double x, String tag, {int count = 3, bool bright = false}) {
    for (var i = 0; i < count; i++) {
      final fx = (x + (_rnd.nextDouble() - 0.5) * 3)
          .clamp(0, cols - 1)
          .toDouble();
      final p =
          Particle(
              ParticleType.food,
              fx,
              -i * 0.7,
              const ['*', '•', '.'][_rnd.nextInt(3)],
              tag: tag,
              bright: bright,
            )
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

  /// Debug: cria sujeira na hora.
  void spawnDirt(int n) {
    for (var i = 0; i < n; i++) {
      particles.add(
        Particle(
          ParticleType.dirt,
          _rnd.nextDouble() * (cols - 1),
          rows - 2.0,
          const [',', '.', ';', '`'][_rnd.nextInt(4)],
        ),
      );
    }
  }

  /// Pulo em direção a um ponto (clique do usuário). [x] em colunas, [y] em linhas (opcional).
  /// Retorna false se não deu para pular (já no ar, ou sem espaço de ar).
  bool jumpToward(double x, {double? y}) {
    if (fish.mode == FishMode.jumping || airRows < 2) return false;
    final depth = max(
      0.0,
      fish.y - waterTop,
    ); // o peixe precisa subir até a superfície primeiro
    final wanted = (y != null && y < waterTop)
        ? (waterTop - y + 0.5)
        : (airRows - 1.0);
    final above = wanted.clamp(1.2, airRows - 1.0).toDouble();
    _launch(
      apex: above + depth,
      vx: ((x - fish.mouthX) * 1.5).clamp(-8.0, 8.0),
    );
    return true;
  }

  /// Debug: força um pulo agora (se houver ar suficiente).
  void forceJump() {
    if (fish.mode != FishMode.jumping && airRows >= 2) _launch();
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
      final p =
          Particle(
              ParticleType.bubble,
              x + (_rnd.nextDouble() - 0.5),
              y - i * 0.4,
              const ['.', '°', 'o'][size],
              bright: bright,
            )
            ..vy = 1.5 + _rnd.nextDouble() * 2 + size * 0.4
            ..phase = _rnd.nextDouble() * pi * 2;
      particles.add(p);
    }
  }

  /// Corações subindo (carinho ou peixe muito feliz).
  void spawnHearts(double x, double y, int n) {
    for (var i = 0; i < n; i++) {
      particles.add(
        Particle(
            ParticleType.heart,
            x + (_rnd.nextDouble() - 0.5) * 2,
            y - i * 0.5,
            '♥',
          )
          ..vy = 1.1 + _rnd.nextDouble() * 0.6
          ..phase = _rnd.nextDouble() * pi * 2,
      );
    }
  }

  void spawnSplash(double x, int n) {
    for (var i = 0; i < n; i++) {
      particles.add(
        Particle(
            ParticleType.splash,
            x + (_rnd.nextDouble() - 0.5) * 2,
            waterTop + 0.3,
            const ['.', '°', "'", ','][_rnd.nextInt(4)],
          )
          ..vx = (_rnd.nextDouble() - 0.5) * 8
          ..vy = -(3 + _rnd.nextDouble() * 6),
      );
    }
  }

  // ----------------------------------------------------------- simulação

  void update(double dt) {
    time += dt;
    _updateFace(dt);
    _updateGhosts(dt);
    _spawn(dt);
    _updateFish(dt);
    _updateParticles(dt);
    _updateCompanions(dt);
  }

  /// Piscar de olho e boca aberta (ao comer ou com comida perto).
  void _updateFace(double dt) {
    final f = fish;
    _blinkT -= dt;
    if (_blinkT <= 0) {
      f.blink = !f.blink;
      _blinkT = f.blink ? 0.14 : 2.5 + _rnd.nextDouble() * 4;
    }
    if (_eatT > 0) _eatT -= dt;
    if (_turnT > 0) _turnT -= dt;
    var near = false;
    final food = _nearestFood();
    if (food != null) {
      near = (food.x - f.mouthX).abs() < 4 && (food.y - f.y).abs() < 2;
    }
    f.mouthOpen = _eatT > 0 || near;
  }

  /// De vez em quando um peixe bem apagado cruza o fundo.
  void _updateGhosts(double dt) {
    for (final g in ghosts) {
      g.x += g.vx * dt;
    }
    ghosts.removeWhere((g) => g.x < -16 || g.x > cols + 16);
    _updateSchool(dt);
    _ghostT -= dt;
    if (_ghostT <= 0) {
      _ghostT = 20 + _rnd.nextDouble() * 30;
      if (ghosts.length < 2 && cols >= 30) {
        const arts = ['<o)><', '<°))))><', '<=°)))))))><'];
        final right = _rnd.nextBool();
        final art = arts[_rnd.nextInt(arts.length)];
        ghosts.add(
          Ghost(
            right ? mirrorSprite(art) : art,
            right ? -art.length.toDouble() : cols + 1.0,
            _minY + _rnd.nextDouble() * (_maxY - _minY),
            (right ? 1 : -1) * (1.5 + _rnd.nextDouble() * 1.5),
          ),
        );
      }
    }
  }

  /// De tempos em tempos um cardume de peixinhos cruza a água, todos juntos.
  void _updateSchool(double dt) {
    _schoolT -= dt;
    if (_schoolT > 0) return;
    _schoolT = 70 + _rnd.nextDouble() * 70;
    if (cols < 40 || ghosts.any((g) => g.school)) return;
    final right = _rnd.nextBool();
    final art = right ? '><>' : '<><';
    final speed = (right ? 1 : -1) * (3.0 + _rnd.nextDouble() * 1.5);
    final baseY = _minY + _rnd.nextDouble() * (_maxY - _minY);
    final n = 7 + _rnd.nextInt(4);
    for (var i = 0; i < n; i++) {
      final dx = _rnd.nextDouble() * 12;
      ghosts.add(
        Ghost(
          art,
          right ? -4.0 - dx : cols + 1.0 + dx,
          (baseY + (_rnd.nextDouble() - 0.5) * 4).clamp(_minY, _maxY),
          speed * (0.95 + _rnd.nextDouble() * 0.1),
          alpha: 0.28,
          phase: _rnd.nextDouble() * 6.28,
          school: true,
        ),
      );
    }
  }

  void _spawn(double dt) {
    _bubbleT -= dt;
    if (_bubbleT <= 0) {
      final joy = happiness > 70 ? 0.6 : 1.0; // peixe feliz solta mais bolhas
      _bubbleT =
          ((oxygen ? 0.5 : 2.5) + _rnd.nextDouble() * (oxygen ? 0.8 : 3)) * joy;
      final x = oxygen ? cols * 0.12 : _rnd.nextDouble() * cols;
      spawnBubbles(x, rows - 2.0, 1);
    }
    if (happiness > 80 && fish.mode != FishMode.jumping) {
      _heartT -= dt;
      if (_heartT <= 0) {
        _heartT = 14 + _rnd.nextDouble() * 14;
        spawnHearts(fish.x + fish.width / 2, fish.y - 1, 1);
      }
    }
    _dirtT -= dt;
    if (_dirtT <= 0) {
      final dirtiness = (100 - cleanliness) / 100;
      // ~30–50 s entre sujeiras (menos quando já está sujo); no máximo 8 de uma vez
      _dirtT = 30 + _rnd.nextDouble() * 20 - dirtiness * 12;
      if (dirtCount < 8) {
        particles.add(
          Particle(
            ParticleType.dirt,
            _rnd.nextDouble() * (cols - 1),
            rows - 2.0,
            const [',', '.', ';', '`'][_rnd.nextInt(4)],
          ),
        );
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

  void _launch({double? apex, double? vx}) {
    final f = fish;
    final a =
        apex ??
        min(1.5 + _rnd.nextDouble() * max(0.5, airRows - 2.8), airRows - 1.0);
    f.vy = -sqrt(2 * _g * a);
    f.vx = vx ?? f.facing * (3 + _rnd.nextDouble() * 5);
    f.mode = FishMode.jumping;
    _jumpT = max(_jumpT, 10) + (apex == null ? 30 + _rnd.nextDouble() * 60 : 0);
    spawnSplash(f.x + f.width / 2, 8);
    onJump?.call();
  }

  void _updateJump(double dt) {
    final f = fish;
    f.vy += _g * dt;
    f.x += f.vx * dt;
    f.y += f.vy * dt;
    final maxX = max(0, cols - f.width).toDouble();
    if (f.x < 0) {
      f.x = 0;
      f.vx = f.vx.abs();
    } else if (f.x > maxX) {
      f.x = maxX;
      f.vx = -f.vx.abs();
    }
    if (f.vx > 0.6) f.facing = 1;
    if (f.vx < -0.6) f.facing = -1;
    if (f.y < 0) {
      f.y = 0;
      f.vy = max(0, f.vy);
    }
    f.tailPhase += dt * 4;
    f.wavePhase += dt * 6;
    f.waveAmp += (1.8 - f.waveAmp) * min(1.0, 5 * dt);
    // Em pleno ar, corrige o rumo na direcao da comida que esta caindo.
    final food = _nearestFood();
    if (food != null && food.y < waterTop + 1) {
      final want = ((food.x - f.mouthX) * 3).clamp(-9.0, 9.0);
      f.vx += (want - f.vx) * min(1.0, 5 * dt);
    }
    _tryEat();
    if (f.vy > 0 && f.y >= waterTop + 0.3) {
      spawnSplash(f.x + f.width / 2, 8);
      spawnBubbles(f.x + f.width / 2, f.y + 1, 4);
      f.mode = FishMode.wandering;
      f.vy *= 0.4;
      _wanderT = 0;
    }
  }

  void _updateFish(double dt) {
    final f = fish;
    if (f.mode == FishMode.jumping) {
      _updateJump(dt);
      return;
    }
    final activity =
        0.35 + 0.35 * (cleanliness / 100) + 0.3 * (happiness / 100);
    final tired = hunger < 25 ? 0.6 : 1.0;
    final food = _nearestFood();
    double tx, ty, speed;

    if (food != null) {
      f.mode = FishMode.seekingFood;
      tx = food.x > f.x + f.width / 2 ? food.x - f.width : food.x;
      ty = max(food.y, _minY);
      speed = 10 + cols / 40;
      if (food.y < waterTop) {
        // comida no ar: espera embaixo e salta quando ela esta ao alcance
        final reach = min(airRows - 1.0, 4.0);
        if (reach >= 2 &&
            food.y > waterTop - reach &&
            (food.x - f.mouthX).abs() < 4 &&
            f.y <= waterTop + 2.2) {
          _launch(
            apex: reach + 0.3,
            vx: ((food.x - f.mouthX) * 1.5).clamp(-8.0, 8.0),
          );
          return;
        }
      }
    } else if (_curiousT > 0) {
      f.mode = FishMode.curious;
      _curiousT -= dt;
      tx = _curiousX > f.x + f.width / 2 ? _curiousX - f.width : _curiousX;
      ty = _curiousY.clamp(_minY, _maxY).toDouble();
      speed = 6 + cols / 60;
    } else {
      f.mode = FishMode.wandering;
      _jumpT -= dt;
      if (_jumpT <= 0 && airRows >= 3 && hunger > 30) {
        // vai ate a superficie e salta
        tx = f.x;
        ty = waterTop + 1.0;
        speed = 7;
        if (f.y <= waterTop + 1.7) {
          _launch();
          return;
        }
      } else {
        _wanderT -= dt;
        if (_wanderT <= 0) {
          _wanderT = 2.5 + _rnd.nextDouble() * 3.5;
          final range = min(cols, 70).toDouble();
          _tx = (f.x + (_rnd.nextDouble() - 0.5) * 2 * range)
              .clamp(0, max(1, cols - f.width))
              .toDouble();
          _ty = _minY + _rnd.nextDouble() * (_maxY - _minY);
        }
        tx = _tx;
        ty = _ty;
        speed = (3.5 + cols / 60) * activity * tired;
      }
    }

    final dx = tx - f.x;
    final dy = ty - f.y;
    final d = sqrt(
      dx * dx + dy * dy * 4,
    ); // linhas sao ~2x mais altas que colunas
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

    // Inversao de direcao com histerese: o peixe desacelera, passa por zero e entao vira.
    if (f.vx > 0.6 && f.facing < 0) f.facing = 1;
    if (f.vx < -0.6 && f.facing > 0) f.facing = -1;
    if (f.facing != _lastFacing) {
      _lastFacing = f.facing;
      if (_turnT <= 0) {
        _turnT = 3;
        spawnBubbles(f.x + f.width / 2, f.y, 2 + _rnd.nextInt(2));
      }
    }
    // Animação calma: cauda no máximo ~3 trocas/s; onda 2,5–5 rad/s; amplitude suavizada.
    final sp = sqrt(f.vx * f.vx + f.vy * f.vy);
    f.tailPhase += dt * min(3.0, 1.0 + sp * 0.25);
    f.wavePhase += dt * (2.5 + min(sp, 8.0) * 0.3);
    f.waveAmp += ((0.8 + min(1.0, sp * 0.12)) - f.waveAmp) * min(1.0, 5 * dt);

    // Bolhas pela boca.
    _mouthT -= dt;
    if (_mouthT <= 0) {
      _mouthT = 4 + _rnd.nextDouble() * 5;
      spawnBubbles(f.mouthX, f.y, 1 + _rnd.nextInt(2));
    }

    _tryEat();
  }

  void _tryEat() {
    final f = fish;
    for (final p in List<Particle>.of(particles)) {
      if (p.type != ParticleType.food) continue;
      if ((p.x - f.mouthX).abs() < 1.8 && (p.y - f.y).abs() < 1.4) {
        particles.remove(p);
        _eatT = 0.45;
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
          if (p.y < waterTop + 0.6) particles.remove(p);
        case ParticleType.food:
          if (p.settled) {
            if (p.age > 7) {
              // comida esquecida apodrece e vira sujeira
              particles.remove(p);
              particles.add(Particle(ParticleType.dirt, p.x0, rows - 2.0, ';'));
              onRot?.call();
            }
          } else {
            if (p.y < waterTop) {
              p.vy = min(4.5, p.vy + 6 * dt); // no ar: queda livre (visivel)
              p.x = p.x0;
            } else {
              p.vy += (2.2 - p.vy) * min(1.0, 3 * dt); // na agua: arrasto
              p.x = p.x0 + sin(time * 2 + p.phase) * 0.5;
            }
            p.y += p.vy * dt;
            if (p.y >= rows - 2) {
              p.y = rows - 2.0;
              p.settled = true;
              p.age = 0;
            }
          }
        case ParticleType.splash:
          p.vy += 14 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          if ((p.vy > 0 && p.y >= waterTop + 0.6) || p.age > 1.5)
            particles.remove(p);
        case ParticleType.heart:
          p.y -= p.vy * dt;
          p.x = p.x0 + sin(time * 2 + p.phase) * 0.5;
          if (p.age > 2.6 || p.y < 0) particles.remove(p);
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
      final maxX = max(0, cols - c.width).toDouble();
      if (c.kind == 'crab') {
        c.y = rows - 2.0;
        if (c.timer <= 0) {
          c.timer = 1.5 + _rnd.nextDouble() * 4;
          c.tx = _rnd.nextBool()
              ? _rnd.nextDouble() * maxX
              : c.x; // as vezes pausa
        }
        final dx = c.tx - c.x;
        if (dx.abs() > 0.2) {
          c.facing = dx > 0 ? 1 : -1;
          c.vx = dx.sign * 2.4;
          c.x = (c.x + c.vx * dt).clamp(0, maxX).toDouble();
        } else {
          c.vx = 0;
        }
      } else {
        // peixinho e lula nadam na agua; a lula avanca em jatos
        if (c.timer <= 0) {
          c.timer = (c.kind == 'squid' ? 3 : 2) + _rnd.nextDouble() * 4;
          c.tx = _rnd.nextDouble() * maxX;
          c.ty = _minY + _rnd.nextDouble() * (_maxY - _minY);
        }
        final dx = c.tx - c.x, dy = c.ty - c.y;
        final d = max(0.001, sqrt(dx * dx + dy * dy * 4));
        var s = 2.5 * min(1.0, d / 3);
        if (c.kind == 'squid') {
          final pulse = max(0.0, sin(time * 1.9 + c.width));
          s = (0.6 + 6.0 * pulse * pulse) * min(1.0, d / 3 + 0.3);
        }
        c.vx += (dx / d * s - c.vx) * min(1.0, 3 * dt);
        c.vy += (dy / d * s - c.vy) * min(1.0, 3 * dt);
        c.x = (c.x + c.vx * dt).clamp(0, maxX).toDouble();
        c.y = (c.y + c.vy * dt).clamp(_minY, _maxY).toDouble();
        if (c.vx > 0.4) c.facing = 1;
        if (c.vx < -0.4) c.facing = -1;
      }
    }
  }
}
