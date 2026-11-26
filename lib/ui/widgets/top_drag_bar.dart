import 'package:flutter/material.dart';
import 'package:window_manager/legacy.dart';

import '../../app/game_controller.dart';
import '../painter/aquarium_painter.dart';

class TopDragBar extends StatelessWidget {
  const TopDragBar(this.game, {super.key});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final th = game.theme;
    return Container(
      height: 26,
      color: th.bg.withValues(alpha: 0.78),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 8),
                child: Text('<o))))><  ${game.stage.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: kMonoFamily, fontSize: 11, color: th.fg.withValues(alpha: 0.7))),
              ),
            ),
          ),
          _IconBtn(
            game.settings.alwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
            game.settings.alwaysOnTop ? 'Sempre no topo: ligado' : 'Sempre no topo: desligado',
            game.settings.alwaysOnTop ? th.accent : th.fg,
            () => game.setAlwaysOnTop(!game.settings.alwaysOnTop),
          ),
          _IconBtn(Icons.settings, 'Menu', th.fg, () => game.setMenu(!game.menuOpen)),
          _IconBtn(Icons.remove, 'Minimizar', th.fg, game.window.minimize),
          _IconBtn(Icons.close, 'Fechar', th.fg, game.window.close),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(this.icon, this.tip, this.color, this.onTap);
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
          radius: 14,
          child: SizedBox(width: 26, height: 26, child: Icon(icon, size: 15, color: color)),
        ),
      );
}
