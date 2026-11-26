import 'package:flutter/material.dart';

import '../../app/game_controller.dart';
import '../../core/models/ascii_theme.dart';
import '../../core/models/game_progress.dart';
import '../painter/aquarium_painter.dart';

/// Dock de controles no canto inferior esquerdo. Fica esmaecido até o mouse chegar perto.
class HudOverlay extends StatelessWidget {
  const HudOverlay(this.game, {super.key});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final p = game.progress;
    final th = game.theme;
    final visible =
        game.hudHover || !game.settings.autoHideHud || game.menuOpen;
    final warn = p.hunger < 30
        ? ' · fome!'
        : p.cleanliness < 30
        ? ' · sujo!'
        : '';
    final mono = TextStyle(fontFamily: kMonoFamily, fontSize: 11, color: th.fg);

    return Stack(
      children: [
        Positioned(
          left: kPanelMargin,
          bottom: kPanelMargin,
          width: kDockSize.width,
          height: kDockSize.height,
          child: Stack(
            children: [
              // Estado recolhido: só um rótulo discreto.
              Positioned(
                left: 6,
                bottom: 4,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: visible ? 0 : 0.85,
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      'Nv.${p.level}$warn',
                      style: mono.copyWith(
                        color: warn.isEmpty
                            ? th.fg.withValues(alpha: 0.7)
                            : th.accent,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !visible,
                  child: _dock(p, th, mono),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dock(GameProgress p, AsciiTheme th, TextStyle mono) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 6, 4),
      decoration: BoxDecoration(
        color: th.bg.withValues(alpha: 0.85),
        border: Border.all(color: th.fg.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_bar('Fome', p.hunger, 100), style: mono),
              Text(_bar('Humor', p.happiness, 100), style: mono),
              Text(
                _bar('XP', p.xp.toDouble(), p.xpToNextLevel.toDouble()),
                style: mono,
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _Btn(
                '[Alimentar]',
                'Clique depois onde soltar a comida (atalho F: solta no mouse)',
                th.accent,
                game.armFeed,
              ),
              const SizedBox(width: 4),
              _Btn('[Limpar]', 'Limpar o aquário (C)', th.accent, game.clean),
              const Spacer(),
              Text('● ${p.pearls}', style: mono.copyWith(color: th.food)),
              const SizedBox(width: 4),
              _Icon(
                game.settings.alwaysOnTop
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
                game.settings.alwaysOnTop
                    ? 'Sempre no topo: ligado'
                    : 'Sempre no topo: desligado',
                game.settings.alwaysOnTop ? th.accent : th.fg,
                () => game.setAlwaysOnTop(!game.settings.alwaysOnTop),
              ),
              _Icon(
                Icons.settings,
                'Menu',
                th.fg,
                () => game.setMenu(!game.menuOpen),
              ),
              _Icon(
                Icons.close,
                'Esconder na bandeja',
                th.fg,
                game.window.hideToTray,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _bar(String label, double v, double max, {int w = 4}) {
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
        child: Text(
          label,
          style: TextStyle(fontFamily: kMonoFamily, fontSize: 12, color: color),
        ),
      ),
    ),
  );
}

class _Icon extends StatelessWidget {
  const _Icon(this.icon, this.tip, this.color, this.onTap);
  final IconData icon;
  final String tip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    waitDuration: const Duration(milliseconds: 500),
    child: InkResponse(
      onTap: onTap,
      radius: 12,
      child: SizedBox(
        width: 22,
        height: 24,
        child: Icon(icon, size: 14, color: color),
      ),
    ),
  );
}
