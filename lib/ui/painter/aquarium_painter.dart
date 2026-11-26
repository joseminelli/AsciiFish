import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/game_controller.dart';
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
      return TextPainter(text: TextSpan(text: s, style: style(c)), textDirection: TextDirection.ltr)..layout();
    });
  }
}

class AquariumPainter extends CustomPainter {
  AquariumPainter(this.game, Listenable repaint) : super(repaint: repaint);

  final GameController game;

  @override
  void paint(Canvas canvas, Size size) {
    final th = game.theme;
    final e = game.engine;
    final g = game.glyphs;
    final cw = g.cell.width, ch = g.cell.height;
    final owned = game.progress.owned;

    void text(String s, double col, double row, Color c) {
      g.get(s, c).paint(canvas, Offset(col * cw, row * ch));
    }

    // Fundo totalmente transparente: so a agua e desenhada.
    final wt = e.waterTop.toDouble();
    final surfaceY = (wt + 0.5) * ch;
    final waterRect = Rect.fromLTRB(0, surfaceY, size.width, size.height);
    canvas.drawRect(
      waterRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [th.accent.withValues(alpha: 0.10), th.accent.withValues(alpha: 0.30)],
        ).createShader(waterRect),
    );

    // Superficie ondulante.
    final wave = Path()..moveTo(0, surfaceY);
    for (var x = 0.0; x <= size.width; x += 6) {
      wave.lineTo(x, surfaceY + sin(x * 0.045 + e.time * 2.2) * 1.8 + sin(x * 0.013 - e.time) * 1.2);
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
      text('~', col, row, th.accent.withValues(alpha: 0.16 + 0.1 * sin(e.time + k)));
    }

    // Areia.
    final sand = StringBuffer();
    for (var i = 0; i < e.cols; i++) {
      sand.write('.:.,.'[i % 5]);
    }
    text(sand.toString(), 0, e.rows - 1.0, th.dirt);

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
      text(p.ch, p.x, p.y, c);
    }

    // Companheiros.
    for (final c in e.companions) {
      if (c.kind == 'fish') {
        text(c.facing > 0 ? '><o>' : '<o><', c.x, c.y, th.fish.withValues(alpha: 0.8));
      } else {
        text(c.facing > 0 ? '=(:>' : '<:)=', c.x, c.y, th.fish.withValues(alpha: 0.8));
      }
    }

    // Peixe principal.
    final f = e.fish;
    final sprite = FishSprites.frame(game.progress.level, facingRight: f.facing > 0, tail: f.tailPhase.floor());
    text(sprite, f.x, f.y, th.fish);
  }

  @override
  bool shouldRepaint(covariant AquariumPainter old) => true;
}
