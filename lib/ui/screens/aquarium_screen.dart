import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../app/game_controller.dart';
import '../painter/aquarium_painter.dart';
import '../widgets/hud_overlay.dart';
import '../widgets/side_drawer_menu.dart';

class AquariumScreen extends StatefulWidget {
  const AquariumScreen({super.key, required this.game});
  final GameController game;

  @override
  State<AquariumScreen> createState() => _AquariumScreenState();
}

class _AquariumScreenState extends State<AquariumScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _acc = 0;

  GameController get g => widget.game;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    var dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    // Visível = 60 FPS (a janela quase nunca tem foco por causa do click-through).
    // Só reduz quando está escondida na bandeja.
    if (g.window.hidden) {
      _acc += dt;
      if (_acc < 1 / 15) return;
      dt = _acc;
      _acc = 0;
    }
    g.tick(dt);
    _frame.value++;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.keyF) {
      g.triggerFeed();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyC) {
      g.clean();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape && g.feedArmed) {
      g.cancelFeed();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape && g.menuOpen) {
      g.setMenu(false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) {
        final th = g.theme;
        return Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: Container(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      g.onLayout(c.biggest);
                      return MouseRegion(
                        cursor: g.feedArmed
                            ? SystemMouseCursors.precise
                            : MouseCursor.defer,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => g.tapAt(d.localPosition),
                          child: RepaintBoundary(
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: AquariumPainter(g, _frame),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned.fill(child: HudOverlay(g)),
                if (g.menuOpen)
                  Positioned(
                    left: kPanelMargin,
                    bottom: kPanelMargin + kDockSize.height + 6,
                    width: kMenuSize.width,
                    height: kMenuSize.height,
                    child: SideDrawerMenu(g),
                  ),
                Positioned(
                  bottom: kPanelMargin + 20,
                  left: kPanelMargin + kDockSize.width + 12,
                  child: IgnorePointer(
                    child: ValueListenableBuilder<String?>(
                      valueListenable: g.toast,
                      builder: (_, msg, _) => AnimatedOpacity(
                        opacity: msg == null ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            color: th.fg.withValues(alpha: 0.9),
                            child: Text(
                              msg ?? '',
                              style: TextStyle(
                                fontFamily: kMonoFamily,
                                fontSize: 11,
                                color: th.bg,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
