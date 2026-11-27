class AppSettings {
  AppSettings({
    this.alwaysOnTop = false,
    this.widgetMode = true,
    this.themeId = 'theme_oled',
    this.fishColorId = 'fcolor_default',
    this.debugMode = false,
    this.fishReacts = true,
    this.autoHideHud = true,
    this.autoUpdate = true,
    this.fps = 60,
    this.lastUpdateCheck = 0,
    this.fontSize = 13,
    this.windowX,
    this.windowY,
    this.windowWidth = 340,
    this.windowHeight = 240,
  });

  bool alwaysOnTop;
  bool widgetMode; // fica atrás dos outros apps, como um widget de desktop
  String themeId;
  String fishColorId;
  bool debugMode;
  bool fishReacts; // peixe segue o mouse e pula quando clicam perto dele
  bool autoHideHud;
  int fps; // taxa de quadros alvo: 60, 30 ou 20 (menos CPU)
  bool autoUpdate; // procura atualizações ao abrir (no máx. 1x por dia)
  int lastUpdateCheck; // epoch ms
  double fontSize;
  double? windowX;
  double? windowY;
  double? windowWidth;
  double? windowHeight;

  Map<String, dynamic> toJson() => {
    'alwaysOnTop': alwaysOnTop,
    'widgetMode': widgetMode,
    'themeId': themeId,
    'fishColorId': fishColorId,
    'debugMode': debugMode,
    'fishReacts': fishReacts,
    'autoHideHud': autoHideHud,
    'autoUpdate': autoUpdate,
    'fps': fps,
    'lastUpdateCheck': lastUpdateCheck,
    'fontSize': fontSize,
    'windowX': windowX,
    'windowY': windowY,
    'windowWidth': windowWidth,
    'windowHeight': windowHeight,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final d = AppSettings();
    return AppSettings(
      alwaysOnTop: j['alwaysOnTop'] as bool? ?? d.alwaysOnTop,
      widgetMode: j['widgetMode'] as bool? ?? d.widgetMode,
      themeId: j['themeId'] as String? ?? d.themeId,
      fishColorId: j['fishColorId'] as String? ?? d.fishColorId,
      debugMode: j['debugMode'] as bool? ?? d.debugMode,
      fishReacts: j['fishReacts'] as bool? ?? d.fishReacts,
      autoHideHud: j['autoHideHud'] as bool? ?? d.autoHideHud,
      autoUpdate: j['autoUpdate'] as bool? ?? d.autoUpdate,
      fps: const [60, 30, 20].contains(j['fps']) ? j['fps'] as int : d.fps,
      lastUpdateCheck: (j['lastUpdateCheck'] as num?)?.toInt() ?? 0,
      fontSize: ((j['fontSize'] as num?) ?? d.fontSize).toDouble().clamp(
        10.0,
        20.0,
      ),
      windowX: (j['windowX'] as num?)?.toDouble(),
      windowY: (j['windowY'] as num?)?.toDouble(),
      windowWidth: (j['windowWidth'] as num?)?.toDouble() ?? d.windowWidth,
      windowHeight: (j['windowHeight'] as num?)?.toDouble() ?? d.windowHeight,
    );
  }
}
