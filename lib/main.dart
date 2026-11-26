import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/game_controller.dart';
import 'core/storage/save_repository.dart';
import 'platform/windows_window_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repo = SaveRepository();
  final data = await repo.load();
  final window = WindowsWindowService();
  final game = GameController(
    repo: repo,
    window: window,
    settings: data.settings,
    progress: data.progress,
  );

  window
    ..onGeometryChanged = game.scheduleSave
    ..onCloseRequested = game.saveNow
    ..onFocusChanged = ((f) => game.focused = f);

  await window.init(data.settings);
  game.start();

  runApp(AsciiFishApp(game: game));
}
