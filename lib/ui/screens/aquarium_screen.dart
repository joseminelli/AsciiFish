import 'dart:async';

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

class _AquariumScreenState extends State<AquariumScreen> {
  final _frame = ValueNotifier<int>(0);
  final _clock = Stopwatch()..start();
  Duration _last = Duration.zero;
  Timer? _wake;
  bool _alive = true;

  GameController get g => widget.game;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _alive = false;
    _wake?.cancel();
    _frame.dispose();
    super.dispose();
  }

  // Sem Ticker contínuo: cada quadro agenda o próximo. Um Ticker acorda o motor a cada vsync
  // e cada quadro apresentado custa CPU (janela transparente), mesmo sem nada novo para
  // desenhar. Aqui o ritmo vem da opção de FPS e o quadro continua alinhado ao vsync.
  void _schedule() {
    if (_alive) SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _onFrame(Duration _) {
    if (!_alive) return;
    if (g.window.dormant) {
      _onHiddenTick();
      return;
    }
    _step(maxDt: 0.1);
    _frame.value++;
    final ms = g.frameDelayMs;
    if (ms <= 0) {
      _schedule();
    } else {
      _wake = Timer(Duration(milliseconds: ms), _schedule);
    }
  }

  /// Escondida (bandeja ou tela cheia): só avança a lógica (fome etc.) a 4 Hz e não pede quadros.
  void _onHiddenTick() {
    if (!_alive) return;
    _step(maxDt: 1.0);
    _next();
  }

  void _step({required double maxDt}) {
    final now = _clock.elapsed;
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, maxDt);
    _last = now;
    g.tick(dt);
  }

  void _next() {
    if (g.window.dormant) {
      _wake = Timer(const Duration(milliseconds: 250), _onHiddenTick);
    } else {
      _schedule();
    }
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
                        cursor: g.ctrlHeld
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
