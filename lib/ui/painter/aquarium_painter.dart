import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/game_controller.dart';
import '../../core/models/critter_sprites.dart';
import '../../core/models/fish_sprites.dart';
import '../../core/models/particle.dart';

const kMonoFamily = 'Consolas';
const kMonoFallback = ['Cascadia Mono', 'Courier New', 'monospace'];

/// Cache de TextPainters por (texto, cor) para uma fonte monoespaçada fixa.
class GlyphCache {
  GlyphCache(this.fontSize) {
    final tp = TextPainter(
      text: TextSpan(text: 'M', style: style(const Color(0xFFFFFFFF))),
      textDirection: TextDirection.ltr,
    )..layout();
    cell = Size(tp.width, tp.height);
    tp.dispose();
  }

  final double fontSize;
  late final Size cell;
  final Map<String, TextPainter> _cache = {};
  // Caracteres únicos (o caso quente: sprites, plantas, bolhas) usam chave inteira,
  // sem montar uma String por chamada.
  final Map<int, TextPainter> _single = {};

  TextStyle style(Color c) => TextStyle(
    fontFamily: kMonoFamily,
    fontFamilyFallback: kMonoFallback,
    fontSize: fontSize,
    color: c,
    height: 1.0,
  );

  TextPainter _make(String s, Color c) => TextPainter(
    text: TextSpan(text: s, style: style(c)),
    textDirection: TextDirection.ltr,
  )..layout();

  TextPainter get(String s, Color c) {
    if (s.length == 1) {
      if (_single.length > 800) {
        for (final t in _single.values) {
          t.dispose();
        }
        _single.clear();
      }
      final key = (s.codeUnitAt(0) << 32) | c.toARGB32();
      return _single[key] ??= _make(s, c);
    }
    if (_cache.length > 200) {
      for (final t in _cache.values) {
        t.dispose();
      }
      _cache.clear();
    }
    return _cache.putIfAbsent('${c.toARGB32()}|$s', () => _make(s, c));
  }
}

class AquariumPainter extends CustomPainter {
  AquariumPainter(this.game, Listenable repaint) : super(repaint: repaint);

  final GameController game;

  // caches por frame: evitam recriar a areia e o degradê da água a cada repintura
  int _sandCols = -1;
  String _sand = '';
  Rect? _waterRect;
  String? _waterTheme;
  Paint? _waterPaint;
  final Path _surface = Path();
  final Path _ray = Path();
  final Path _dune = Path();
  Size? _duneSize;
  int _duneRows = -1;
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  final Paint _wavePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final th = game.theme;
    final e = game.engine;
    final g = game.glyphs;
    final cw = g.cell.width, ch = g.cell.height;
    final owned = game.progress.owned;
    final fishCol = game.fishColor(e.time);

    // Ciclo dia/noite pelo relógio: 1 = pleno dia (10h–16h), 0 = noite (22h–4h).
    // Com o debug ligado, só o controle de debug define a hora; senão, o relógio.
    final dbg = game.settings.debugMode;
    final now = DateTime.now();
    final hour = dbg ? game.debugHour : now.hour + now.minute / 60;
    final day = (dbg || game.settings.dayNight)
        ? (0.5 + 0.8 * cos((hour - 13) / 24 * 2 * pi))
              .clamp(0.0, 1.0)
              .toDouble()
        : 1.0;
    final night = 1 - day;

    void text(String s, double col, double row, Color c) {
      g.get(s, c).paint(canvas, Offset(col * cw, row * ch));
    }

    // Fundo totalmente transparente: so a agua e desenhada.
    final wt = e.waterTop.toDouble();
    final surfaceY = (wt + 0.5) * ch;
    final waterRect = Rect.fromLTRB(0, surfaceY, size.width, size.height);
    if (_waterPaint == null ||
        _waterRect != waterRect ||
        _waterTheme != game.settings.themeId) {
      _waterRect = waterRect;
      _waterTheme = game.settings.themeId;
      _waterPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            th.accent.withValues(alpha: 0.10),
            th.accent.withValues(alpha: 0.24),
            Color.lerp(th.accent, th.bg, 0.55)!.withValues(alpha: 0.42),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(waterRect);
    }
    canvas.drawRect(waterRect, _waterPaint!);

    // Raios de luz descendo da superfície, balançando devagar.
    final rayColor = Color.lerp(
      th.accent,
      const Color(0xFFFFFFFF),
      th.isDark ? 0.5 : 0.2,
    )!.withValues(alpha: (th.isDark ? 0.05 : 0.07) * (0.4 + 0.6 * day));
    final rays = max(3, (size.width / 260).round());
    for (var k = 0; k < rays; k++) {
      final x0 =
          size.width * (k + 0.5) / rays + sin(e.time * 0.25 + k * 2.1) * 24;
      final w = 10.0 + 6 * sin(e.time * 0.4 + k);
      _ray
        ..reset()
        ..moveTo(x0 - w, surfaceY)
        ..lineTo(x0 + w, surfaceY)
        ..lineTo(x0 + w + 70, size.height)
        ..lineTo(x0 - w + 30, size.height)
        ..close();
      canvas.drawPath(_ray, _fill..color = rayColor);
    }

    // Superficie ondulante.
    final wave = _surface
      ..reset()
      ..moveTo(0, surfaceY);
    for (var x = 0.0; x <= size.width; x += 6) {
      wave.lineTo(
        x,
        surfaceY +
            sin(x * 0.045 + e.time * 2.2) * 1.8 +
            sin(x * 0.013 - e.time) * 1.2,
      );
    }
    canvas.drawPath(
      wave,
      _wavePaint..color = th.accent.withValues(alpha: 0.75),
    );

    // Reflexo do peixe na superfície: brilho que cresce quando ele está perto dela.
    final fs = e.fish;
    final prox = fs.y < e.waterTop
        ? 1 - (e.waterTop - fs.y) / 4
        : 1 - (fs.y - e.waterTop) / 3.5;
    if (prox > 0) {
      final a = prox.clamp(0.0, 1.0) * 0.4;
      final glow = Color.lerp(th.accent, const Color(0xFFFFFFFF), 0.6)!;
      final c = Offset((fs.x + fs.width / 2) * cw, surfaceY);
      final wd = 30 + fs.width * cw * 0.9;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: wd, height: 6),
        _fill..color = glow.withValues(alpha: a),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: wd * 1.7, height: 3),
        _fill..color = glow.withValues(alpha: a * 0.5),
      );
    }

    // Brilhos (causticas) na agua.
    final depth = max(1, e.rows - e.waterTop - 3);
    for (var k = 0; k * 9 < e.cols; k++) {
      final col = k * 9 + sin(e.time * 0.8 + k * 1.7) * 2.5;
      final row = wt + 1 + ((k * 7) % depth);
      text(
        '~',
        col,
        row,
        // alpha em degraus de 1/24: poucas cores distintas mantêm o cache de glifos eficiente
        th.accent.withValues(
          alpha: ((0.16 + 0.1 * sin(e.time + k)) * 24).round() / 24,
        ),
      );
    }

    // Plâncton: pontinhos fracos à deriva (posição calculada do tempo, sem estado).
    final span = max(1, e.rows - e.waterTop - 3);
    for (var k = 0; k < max(8, e.cols ~/ 4); k++) {
      final x =
          ((k * 37 % 100) / 100 * e.cols +
              e.time * (0.2 + (k % 4) * 0.08) +
              sin(e.time * 0.7 + k) * 1.2) %
          e.cols;
      final y =
          wt +
          1 +
          (k * 53 % 100) / 100 * span +
          sin(e.time * 0.5 + k * 1.3) * 0.6;
      canvas.drawCircle(
        Offset(x * cw, y * ch),
        0.8 + (k % 3) * 0.3,
        _fill..color = th.fg.withValues(alpha: 0.10 + 0.07 * sin(e.time + k)),
      );
    }

    // Silhuetas distantes (bem apagadas).
    for (final gh in e.ghosts) {
      final bob = gh.school ? sin(e.time * 2 + gh.phase) * 0.35 : 0.0;
      text(gh.art, gh.x, gh.y + bob, th.fg.withValues(alpha: gh.alpha));
    }

    final base = e.rows - 2.0;

    // Plantas de fundo: mais baixas e apagadas, atrás das principais.
    final bpc = th.plant.withValues(alpha: 0.32);
    for (final p in e.backPlants) {
      for (var i = 0; i < p.height; i++) {
        final dx =
            sin(e.time * p.freq * 0.7 + p.phase + i * 0.7) * 0.12 * (i + 1);
        final c = i == p.height - 1 ? '~' : (i.isEven ? '(' : ')');
        text(c, p.x + dx, base - i, bpc);
      }
    }

    // Areia com dunas suaves.
    if (_sandCols != e.cols) {
      _sandCols = e.cols;
      _sand = List.generate(e.cols, (i) => '.:.,.'[i % 5]).join();
    }
    if (_duneSize != size || _duneRows != e.rows) {
      _duneSize = size;
      _duneRows = e.rows;
      final top = (e.rows - 1.0) * ch + ch * 0.2;
      _dune
        ..reset()
        ..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width + 6; x += 6) {
        _dune.lineTo(
          x,
          top + (sin(x * 0.035) + sin(x * 0.013 + 1.3)) * ch * 0.14,
        );
      }
      _dune
        ..lineTo(size.width + 6, size.height)
        ..close();
    }
    canvas.drawPath(_dune, _fill..color = th.sand.withValues(alpha: 0.30));
    text(_sand, 0, e.rows - 1.0, th.sand);
    if (e.cols >= 24) {
      // estrelas-do-mar e seixos na areia
      text('*', e.cols * 0.07, e.rows - 1.0, const Color(0xFFE8825A));
      text('*', e.cols * 0.64, e.rows - 1.0, const Color(0xFFF2A65A));
      text('o', e.cols * 0.30, e.rows - 1.0, th.rock);
      text('o', e.cols * 0.82, e.rows - 1.0, th.rock);
    }

    // Decorações estáticas.
    if (owned.contains('decor_rocks')) {
      final hi = Color.lerp(th.rock, const Color(0xFFFFFFFF), 0.25)!;
      void rock(double col, String top, String bottom) {
        text(top, col + 1, base - 1, hi);
        text(bottom, col, base, th.rock);
      }

      rock(e.cols * 0.2, r'/\', r'/__\');
      rock(e.cols * 0.72, r'_/\_', r'/____\');
    }
    if (owned.contains('decor_shells')) {
      text('@', e.cols * 0.45, base, th.food);
      text('@', e.cols * 0.9, base, th.food);
    }
    if (owned.contains('decor_castle') && e.cols >= 30 && e.rows >= 9) {
      final cx = e.cols * 0.55;
      text('|^|^|^|', cx, base - 2, th.fg.withValues(alpha: 0.7));
      text('|[_ _]|', cx, base - 1, th.fg.withValues(alpha: 0.7));
      text('|_| |_|', cx, base, th.fg.withValues(alpha: 0.7));
    }

    if (owned.contains('decor_coral') && e.rows >= 9) {
      final cx = e.cols * 0.06;
      text(r'\|/ Y', cx, base - 2, const Color(0xFFFFA08F));
      text(r' |\/|', cx, base - 1, const Color(0xFFFF7A6B));
      text(r' \||/', cx, base, const Color(0xFFE0584A));
    }
    if (owned.contains('decor_anemone')) {
      final cx = e.cols * 0.33;
      final sway = (e.time * 1.6).floor().isEven;
      text(
        sway ? r'\|/|\|/' : r'/|\|/|\',
        cx,
        base - 1,
        const Color(0xFFFF8AD0),
      );
      text('(_____)', cx, base, const Color(0xFFC2417F));
    }

    // Plantas ondulantes.
    for (final p in e.plants) {
      for (var i = 0; i < p.height; i++) {
        final dx = sin(e.time * p.freq + p.phase + i * 0.7) * 0.18 * (i + 1);
        final top = i == p.height - 1;
        final String c;
        if (top) {
          c = '~';
        } else if (e.plantStyle == 1) {
          c = i.isEven ? '|' : ')';
        } else {
          c = i.isEven ? '(' : ')';
        }
        text(c, p.x + dx, base - i, th.plant);
      }
    }

    // Noite: escurece tudo que é cenário (peixe e partículas ficam por cima).
    if (night > 0.02) {
      canvas.drawRect(
        waterRect,
        _fill..color = const Color(0xFF020A1E).withValues(alpha: night * 0.40),
      );
    }
    // Luz do aquário (LED): tinge a água, mais forte à noite.
    final led = switch (game.settings.lightId) {
      'light_blue' => const Color(0xFF4DA3FF),
      'light_purple' => const Color(0xFFB07CFF),
      _ => null,
    };
    if (led != null) {
      canvas.drawRect(
        waterRect,
        _fill..color = led.withValues(alpha: 0.07 + 0.11 * night),
      );
    }

    // Partículas.
    for (final p in e.particles) {
      final c = switch (p.type) {
        ParticleType.bubble => p.bright ? th.accent : th.bubble,
        ParticleType.food => p.bright ? th.accent : th.food,
        ParticleType.dirt => th.dirt,
        ParticleType.splash => th.accent,
        ParticleType.heart => const Color(0xFFFF6B8A),
      };
      if (p.type == ParticleType.food) {
        final o = Offset(p.x * cw + cw / 2, p.y * ch + ch / 2);
        canvas.drawCircle(o, 6, _fill..color = c.withValues(alpha: 0.25));
        canvas.drawCircle(o, 3, _fill..color = c);
      } else if (p.type == ParticleType.dirt) {
        _paintDirt(canvas, p, cw, ch, e.time, th.isDark);
      } else {
        text(p.ch, p.x, p.y, c);
      }
    }

    // Companheiros (todos animados).
    for (final c in e.companions) {
      final px = c.x * cw, py = c.y * ch;
      switch (c.kind) {
        case 'fish':
          _wave(
            canvas,
            g,
            CritterSprites.fish(c.facing > 0, (e.time * 2.5).floor()),
            px,
            py,
            fishCol.withValues(alpha: 0.85),
            amp: 0.8,
            phase: e.time * 3.5,
            k: 0.7,
            reverse: c.facing > 0,
          );
        case 'crab':
          final walking = c.vx.abs() > 0.1;
          final claw = (e.time * (walking ? 1.6 : 0.5)).floor();
          final blink = ((e.time + c.x) % 4) > 3.75;
          _wave(
            canvas,
            g,
            CritterSprites.crab(claw, blink),
            px,
            py,
            const Color(0xFFE5533D),
            amp: walking ? 0.8 : 0.3,
            phase: e.time * 4,
            k: 0,
          );
        default: // lula
          _wave(
            canvas,
            g,
            CritterSprites.squid(c.facing > 0, (e.time * 2).floor()),
            px,
            py,
            const Color(0xFFB48CFF),
            amp: 1.4,
            phase: e.time * 3,
            k: 0.9,
            reverse: c.facing > 0,
          );
      }
    }

    // Mira de alimentação: linha tracejada no X do mouse.
    final cur = game.cursorLocal;
    if (game.ctrlHeld && cur != null) {
      final cx = cur.dx / cw;
      for (var r = 0; r < e.waterTop; r++) {
        text(
          r == 0 ? 'v' : ':',
          cx,
          r.toDouble(),
          th.food.withValues(alpha: r == 0 ? 1 : 0.45),
        );
      }
    }

    // Peixe principal.
    final f = e.fish;
    final sprite = FishSprites.frame(
      game.progress.level,
      facingRight: f.facing > 0,
      tail: f.tailPhase.floor(),
      blink: f.blink,
      mouth: f.mouthOpen,
    );
    // O corpo ondula suavemente: fase e amplitude vêm do motor (integradas no tempo, sem saltos).
    _wave(
      canvas,
      g,
      sprite,
      f.x * cw,
      f.y * ch,
      fishCol,
      pal: game.fishPalette(e.time),
      zones: FishSprites.zones(
        game.progress.level,
        facingRight: f.facing > 0,
        stripes: game.fishStripes,
      ),
      amp: f.waveAmp,
      phase: f.wavePhase,
      k: 0.55,
      reverse: f.facing > 0,
    );
  }

  /// Desenha [s] caractere a caractere com deslocamento vertical senoidal (efeito de onda).
  /// [reverse] faz a fase começar pelo fim (sprite virado para a direita: cabeça no fim).
  void _wave(
    Canvas canvas,
    GlyphCache g,
    String s,
    double px,
    double py,
    Color c, {
    String? zones,
    FishPalette? pal,
    required double amp,
    required double phase,
    required double k,
    bool reverse = false,
  }) {
    final n = s.length; // sprites são ASCII: sem alocar lista de runes
    var x = px;
    for (var i = 0; i < n; i++) {
      final tp = g.get(s[i], pal == null || zones == null ? c : pal.of(zones[i]));
      final idx = reverse ? n - 1 - i : i;
      tp.paint(canvas, Offset(x, py + sin(phase - idx * k) * amp));
      x += tp.width;
    }
  }

  /// Sujeira bem visível: montinho marrom com contorno, brilho e fiapos de "fedor" subindo.
  void _paintDirt(
    Canvas canvas,
    Particle p,
    double cw,
    double ch,
    double t,
    bool dark,
  ) {
    final seed = (p.x0 * 7.31).floor();
    final w = cw * (1.7 + (seed % 3) * 0.35); // largura varia por partícula
    final h = ch * 0.62;
    final cx = p.x * cw + cw / 2;
    final base = p.y * ch + ch * 0.95;
    final body = Rect.fromCenter(
      center: Offset(cx, base - h / 2),
      width: w,
      height: h,
    );

    canvas.drawOval(body, _fill..color = const Color(0xFF8A5A24));
    canvas.drawOval(
      body,
      _stroke..color = dark ? const Color(0xFFE6B87A) : const Color(0xFF2B1A08),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: body.center.translate(-w * 0.18, -h * 0.18),
        width: w * 0.35,
        height: h * 0.3,
      ),
      _fill..color = const Color(0xFFC48A4A),
    );

    // fiapos subindo
    for (var i = 0; i < 2; i++) {
      final ph = (t * 0.9 + i * 0.5 + seed * 0.13) % 1.0;
      final sx =
          cx + (i == 0 ? -w * 0.2 : w * 0.2) + sin((t + i) * 3 + seed) * 2.5;
      final sy = body.top - ph * ch * 1.1;
      canvas.drawCircle(
        Offset(sx, sy),
        1.8,
        _fill
          ..color = (dark ? const Color(0xFFD8C49A) : const Color(0xFF6B5B45))
              .withValues(alpha: (1 - ph) * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant AquariumPainter old) => true;
}
