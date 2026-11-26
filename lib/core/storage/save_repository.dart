import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/game_progress.dart';

typedef SaveData = ({AppSettings settings, GameProgress progress});

/// Persistência JSON em %APPDATA% (via path_provider). Escrita atômica (tmp + rename).
class SaveRepository {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}ascii_fish_save.json');
  }

  Future<SaveData> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        return (
          settings: AppSettings.fromJson((j['settings'] as Map?)?.cast<String, dynamic>() ?? {}),
          progress: GameProgress.fromJson((j['progress'] as Map?)?.cast<String, dynamic>() ?? {}),
        );
      }
    } catch (_) {
      // save corrompido: começa do zero
    }
    return (settings: AppSettings(), progress: GameProgress());
  }

  Future<void> save(AppSettings settings, GameProgress progress) async {
    try {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'version': 1,
        'settings': settings.toJson(),
        'progress': progress.toJson(),
      }));
      await tmp.rename(f.path);
    } catch (_) {
      // falha de disco não deve derrubar o jogo
    }
  }
}
