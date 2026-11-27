import 'dart:io';

/// "Iniciar com o Windows": usa a mesma chave `HKCU\...\Run` e o mesmo nome de valor
/// do instalador, então o interruptor do app e a opção do instalador sempre concordam.
class StartupService {
  static const _key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _name = 'ASCII Fish Pet';

  /// Executável atual. Em desenvolvimento (`flutter run`) não registramos o build de debug.
  static String get exePath => Platform.resolvedExecutable;
  static bool get available => !exePath.contains(r'\build\windows\');

  static Future<bool> isEnabled() async {
    try {
      final r = await Process.run('reg', ['query', _key, '/v', _name]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Retorna o estado final (true = ligado).
  static Future<bool> set(bool enable) async {
    try {
      if (enable) {
        await Process.run('reg', [
          'add',
          _key,
          '/v',
          _name,
          '/t',
          'REG_SZ',
          '/d',
          '"$exePath"',
          '/f',
        ]);
      } else {
        await Process.run('reg', ['delete', _key, '/v', _name, '/f']);
      }
    } catch (_) {}
    return isEnabled();
  }
}
