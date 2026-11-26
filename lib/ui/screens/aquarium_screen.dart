import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/legacy.dart';

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

class _AquariumScreenState extends State<AquariumScreen> with SingleTickerProviderStateMixin {
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
    // Em segundo plano (sem foco e sem hover) reduz para ~15 FPS para poupar CPU/GPU.
    if (!g.focused && !g.hudHover) {
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
        return DragToResizeArea(
          resizeEdgeSize: 5,
          child: Focus(
            autofocus: true,
            onKeyEvent: _onKey,
            child: MouseRegion(
              onEnter: (_) => g.setHover(true),
              onExit: (_) => g.setHover(false),
              onHover: (e) => g.hoverAt(e.localPosition),
              child: Container(
                decoration: BoxDecoration(
                  color: th.bg,
                  border: Border.all(color: th.fg.withValues(alpha: 0.25)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LayoutBuilder(builder: (context, c) {
                        g.onLayout(c.biggest);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => g.tapAt(d.localPosition),
                          child: RepaintBoundary(
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: AquariumPainter(g, _frame),
                            ),
                          ),
                        );
                      }),
                    ),
                    Positioned.fill(child: HudOverlay(g)),
                    if (g.menuOpen) Positioned.fill(child: SideDrawerMenu(g)),
                    Positioned(
                      top: 30,
                      left: 8,
                      right: 8,
                      child: IgnorePointer(
                        child: ValueListenableBuilder<String?>(
                          valueListenable: g.toast,
                          builder: (_, msg, _) => AnimatedOpacity(
                            opacity: msg == null ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                color: th.fg.withValues(alpha: 0.9),
                                child: Text(msg ?? '',
                                    style: TextStyle(fontFamily: kMonoFamily, fontSize: 11, color: th.bg)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
