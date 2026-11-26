// ignore_for_file: deprecated_member_use
import 'package:tray_manager/legacy.dart';

import '../app/game_controller.dart';

/// Ícone na bandeja do Windows (área de ícones ocultos) com menu de controle.
class TrayService with TrayListener {
  TrayService(this.game);
  final GameController game;
  String _lastState = '';

  Future<void> init() async {
    await trayManager.setIcon('assets/app_icon.ico');
    await trayManager.setToolTip('ASCII Fish Pet');
    trayManager.addListener(this);
    game.addListener(_maybeRebuild);
    await _rebuild();
  }

  void _maybeRebuild() {
    final s = game.settings;
    final state = '${s.alwaysOnTop}';
    if (state != _lastState) _rebuild();
  }

  Future<void> _rebuild() async {
    final s = game.settings;
    _lastState = '${s.alwaysOnTop}';
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Mostrar / trazer para frente'),
      MenuItem(key: 'hide', label: 'Esconder'),
      MenuItem.separator(),
      MenuItem.checkbox(key: 'top', label: 'Sempre no topo', checked: s.alwaysOnTop),
      MenuItem(key: 'snap', label: 'Reencaixar na barra de tarefas'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Sair'),
    ]));
  }

  @override
  void onTrayIconMouseDown() async {
    if (!game.window.hidden) {
      await game.window.hideToTray();
    } else {
      await game.window.showRaised();
    }
  }

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final s = game.settings;
    switch (menuItem.key) {
      case 'show':
        game.window.showRaised();
      case 'hide':
        game.window.hideToTray();
      case 'top':
        game.setAlwaysOnTop(!s.alwaysOnTop);
      case 'snap':
        game.snapToCorner();
      case 'quit':
        game.window.quit();
    }
  }
}
