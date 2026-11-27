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

  TextStyle style(Color c) => TextStyle(
    fontFamily: kMonoFamily,
    fontFamilyFallback: kMonoFallback,
    fontSize: fontSize,
    color: c,
    height: 1.0,
  );

  TextPainter get(String s, Color c) {
    if (_cache.length > 800) {
      for (final t in _cache.values) {
        t.dispose();
      }
      _cache.clear();
    }
    return _cache.putIfAbsent('${c.toARGB32()}|$s', () {
      return TextPainter(
        text: TextSpan(text: s, style: style(c)),
        textDirection: TextDirection.ltr,
      )..layout();
    });
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

  @override
  void paint(Canvas canvas, Size size) {
    final th = game.theme;
    final e = game.engine;
    final g = game.glyphs;
    final cw = g.cell.width, ch = g.cell.height;
    final owned = game.progress.owned;
    final fishCol = game.fishColor(e.time);

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
            th.accent.withValues(alpha: 0.30),
          ],
        ).createShader(waterRect);
    }
    canvas.drawRect(waterRect, _waterPaint!);

    // Superficie ondulante.
    final wave = Path()..moveTo(0, surfaceY);
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
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = th.accent.withValues(alpha: 0.75),
    );

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

    // Areia.
    if (_sandCols != e.cols) {
      _sandCols = e.cols;
      _sand = List.generate(e.cols, (i) => '.:.,.'[i % 5]).join();
    }
    text(_sand, 0, e.rows - 1.0, th.dirt);

    // Decorações estáticas.
    final base = e.rows - 2.0;
    if (owned.contains('decor_rocks')) {
      text(r'/\', e.cols * 0.2, base, th.dirt);
      text(r'_/\_', e.cols * 0.72, base, th.dirt);
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

    // Partículas.
    for (final p in e.particles) {
      final c = switch (p.type) {
        ParticleType.bubble => p.bright ? th.accent : th.bubble,
        ParticleType.food => p.bright ? th.accent : th.food,
        ParticleType.dirt => th.dirt,
        ParticleType.splash => th.accent,
      };
      if (p.type == ParticleType.food) {
        final o = Offset(p.x * cw + cw / 2, p.y * ch + ch / 2);
        canvas.drawCircle(o, 6, Paint()..color = c.withValues(alpha: 0.25));
        canvas.drawCircle(o, 3, Paint()..color = c);
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
    );
    // O corpo ondula suavemente: fase e amplitude vêm do motor (integradas no tempo, sem saltos).
    _wave(
      canvas,
      g,
      sprite,
      f.x * cw,
      f.y * ch,
      fishCol,
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
    required double amp,
    required double phase,
    required double k,
    bool reverse = false,
  }) {
    final runes = s.runes.toList();
    var x = px;
    for (var i = 0; i < runes.length; i++) {
      final tp = g.get(String.fromCharCode(runes[i]), c);
      final idx = reverse ? runes.length - 1 - i : i;
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

    final fill = Paint()..color = const Color(0xFF8A5A24);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = dark ? const Color(0xFFE6B87A) : const Color(0xFF2B1A08);
    canvas.drawOval(body, fill);
    canvas.drawOval(body, edge);
    canvas.drawOval(
      Rect.fromCenter(
        center: body.center.translate(-w * 0.18, -h * 0.18),
        width: w * 0.35,
        height: h * 0.3,
      ),
      Paint()..color = const Color(0xFFC48A4A),
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
        Paint()
          ..color = (dark ? const Color(0xFFD8C49A) : const Color(0xFF6B5B45))
              .withValues(alpha: (1 - ph) * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant AquariumPainter old) => true;
}
