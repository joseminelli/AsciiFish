class AppSettings {
  AppSettings({
    this.alwaysOnTop = false,
    this.widgetMode = true,
    this.themeId = 'theme_oled',
    this.autoHideHud = true,
    this.fontSize = 13,
    this.windowX,
    this.windowY,
    this.windowWidth = 340,
    this.windowHeight = 240,
  });

  bool alwaysOnTop;
  bool widgetMode; // fica atrás dos outros apps, como um widget de desktop
  String themeId;
  bool autoHideHud;
  double fontSize;
  double? windowX;
  double? windowY;
  double? windowWidth;
  double? windowHeight;

  Map<String, dynamic> toJson() => {
        'alwaysOnTop': alwaysOnTop,
        'widgetMode': widgetMode,
        'themeId': themeId,
        'autoHideHud': autoHideHud,
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
      autoHideHud: j['autoHideHud'] as bool? ?? d.autoHideHud,
      fontSize: ((j['fontSize'] as num?) ?? d.fontSize).toDouble().clamp(10.0, 20.0),
      windowX: (j['windowX'] as num?)?.toDouble(),
      windowY: (j['windowY'] as num?)?.toDouble(),
      windowWidth: (j['windowWidth'] as num?)?.toDouble() ?? d.windowWidth,
      windowHeight: (j['windowHeight'] as num?)?.toDouble() ?? d.windowHeight,
    );
  }
}
