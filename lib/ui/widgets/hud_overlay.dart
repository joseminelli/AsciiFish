import 'package:flutter/material.dart';

import '../../app/game_controller.dart';
import '../painter/aquarium_painter.dart';
import 'top_drag_bar.dart';

/// Barra discreta: aparece no hover (ou sempre, se "esconder HUD" estiver desligado).
class HudOverlay extends StatelessWidget {
  const HudOverlay(this.game, {super.key});
  final GameController game;

  Widget _fade(bool visible, Widget child) => AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: IgnorePointer(ignoring: !visible, child: child),
      );

  @override
  Widget build(BuildContext context) {
    final p = game.progress;
    final th = game.theme;
    final visible = game.hudHover || !game.settings.autoHideHud || game.menuOpen;
    final warn = p.hunger < 30
        ? ' · fome!'
        : p.cleanliness < 30
            ? ' · sujo!'
            : '';

    return Stack(
      children: [
        Positioned(top: 0, left: 0, right: 0, child: _fade(visible, TopDragBar(game))),
        Positioned(bottom: 0, left: 0, right: 0, child: _fade(visible, _bottom(game))),
        Positioned(
          left: 6,
          bottom: 3,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: visible ? 0 : 0.8,
              duration: const Duration(milliseconds: 180),
              child: Text('Nv.${p.level}$warn',
                  style: TextStyle(
                      fontFamily: kMonoFamily,
                      fontSize: 11,
                      color: warn.isEmpty ? th.fg.withValues(alpha: 0.6) : th.accent)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottom(GameController g) {
    final p = g.progress;
    final th = g.theme;
    final style = TextStyle(fontFamily: kMonoFamily, fontSize: 11, color: th.fg);
    return Container(
      color: th.bg.withValues(alpha: 0.78),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            children: [
              Text(_bar('Fome', p.hunger, 100), style: style),
              Text(_bar('Humor', p.happiness, 100), style: style),
              Text(_bar('XP', p.xp.toDouble(), p.xpToNextLevel.toDouble()), style: style),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _Btn('[ Alimentar ]', 'Alimentar (F / Espaço)', th.accent, g.triggerFeed),
              const SizedBox(width: 8),
              _Btn('[ Limpar ]', 'Limpar o aquário (C)', th.accent, g.clean),
              const Spacer(),
              Text('● ${p.pearls}', style: style.copyWith(color: th.food)),
            ],
          ),
        ],
      ),
    );
  }

  static String _bar(String label, double v, double max, {int w = 6}) {
    final n = (v / max * w).round().clamp(0, w);
    return '$label[${'#' * n}${'.' * (w - n)}]';
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.tip, this.color, this.onTap);
  final String label;
  final String tip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tip,
        waitDuration: const Duration(milliseconds: 600),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
            child: Text(label, style: TextStyle(fontFamily: kMonoFamily, fontSize: 12, color: color)),
          ),
        ),
      );
}
