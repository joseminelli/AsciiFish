// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:ui';

import 'package:screen_retriever/legacy.dart';

import '../app/game_controller.dart';
import 'desktop_layer.dart';

/// Faz o fundo transparente deixar os cliques passarem para o desktop.
/// Consulta o cursor ~20x/s: só captura o mouse sobre o peixe, sujeira e painéis.
class ClickThroughService {
  ClickThroughService(this.game);
  final GameController game;
  Timer? _timer;
  bool _busy = false;
  bool? _capturing;
  bool _hotkeyWas = false;

  void start() =>
      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _poll());

  void stop() => _timer?.cancel();

  Future<void> _poll() async {
    if (_busy || game.window.hidden) return;
    _busy = true;
    try {
      final cursor = await screenRetriever.getCursorScreenPoint();
      final win = game.window;
      final local = cursor - win.origin;
      final inWindow = (Offset.zero & win.size).contains(local);

      game.cursorLocal = inWindow ? local : null;
      game.cursorAny = local;
      game.setCtrl(inWindow && DesktopLayer.ctrlDown());
      final hot = DesktopLayer.feedHotkeyDown();
      if (hot && !_hotkeyWas) game.triggerFeed();
      _hotkeyWas = hot;
      game.setHover(inWindow && game.overPanel(local));
      if (inWindow) game.passiveHover(local);

      final capture = inWindow && game.isInteractiveAt(local);
      if (capture != _capturing) {
        _capturing = capture;
        await win.setIgnoreMouse(!capture);
      }
    } catch (_) {
      // falha pontual de leitura do cursor: mantém o estado atual
    } finally {
      _busy = false;
    }
  }
}
