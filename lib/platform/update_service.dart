import 'dart:convert';
import 'dart:io';

/// Repositório no GitHub cujas Releases distribuem o instalador.
const kRepoOwner = 'joseminelli';
const kRepoName = 'AsciiFish';
const kSetupAssetName = 'AsciiFishPet-Setup.exe';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.pageUrl,
  });
  final String version;
  final String downloadUrl;
  final String pageUrl;
}

/// Procura a versão mais recente nas Releases do GitHub e instala por cima
/// (o save fica em %APPDATA%, fora da pasta do app, então nada se perde).
class UpdateService {
  /// Retorna a atualização se houver uma versão mais nova que [current]; senão null.
  /// Lança exceção em caso de falha de rede/resposta inesperada.
  static Future<UpdateInfo?> check(String current) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(
        Uri.parse(
          'https://api.github.com/repos/$kRepoOwner/$kRepoName/releases/latest',
        ),
      );
      req.headers
        ..set(HttpHeaders.userAgentHeader, 'AsciiFishPet-Updater')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 404) return null; // nenhuma release publicada
      if (res.statusCode != 200) {
        throw HttpException('GitHub respondeu ${res.statusCode}');
      }
      final j = jsonDecode(body) as Map<String, dynamic>;
      final latest = (j['tag_name'] as String? ?? '').replaceFirst(
        RegExp('^[vV]'),
        '',
      );
      if (!isNewer(latest, current)) return null;
      final assets = (j['assets'] as List? ?? const []).cast<Map>();
      final asset = assets.cast<Map<String, dynamic>>().where(
        (a) => a['name'] == kSetupAssetName,
      );
      if (asset.isEmpty) return null;
      return UpdateInfo(
        version: latest,
        downloadUrl: asset.first['browser_download_url'] as String,
        pageUrl: j['html_url'] as String? ?? '',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Compara versões "1.2.3" (ignora o sufixo "+build").
  static bool isNewer(String a, String b) {
    List<int> parts(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      final xi = i < x.length ? x[i] : 0, yi = i < y.length ? y[i] : 0;
      if (xi != yi) return xi > yi;
    }
    return false;
  }

  /// Baixa o instalador e o executa em modo silencioso. O instalador fecha o app,
  /// atualiza por cima (mantendo o save e as opções) e reabre o app no final.
  static Future<void> downloadAndInstall(UpdateInfo u) async {
    final file = File(
      '${Directory.systemTemp.path}\\AsciiFishPet-Setup-${u.version}.exe',
    );
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(u.downloadUrl));
      req.headers.set(HttpHeaders.userAgentHeader, 'AsciiFishPet-Updater');
      final res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException('Download falhou (${res.statusCode})');
      }
      final sink = file.openWrite();
      await res.pipe(sink);
    } finally {
      client.close(force: true);
    }
    await Process.start(file.path, [
      '/SILENT',
      '/NORESTART',
      '/RELAUNCH=1',
    ], mode: ProcessStartMode.detached);
    exit(0);
  }
}
