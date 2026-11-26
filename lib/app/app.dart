import 'package:flutter/material.dart';

import '../core/models/ascii_theme.dart';
import '../ui/painter/aquarium_painter.dart';
import '../ui/screens/aquarium_screen.dart';
import 'game_controller.dart';

class AsciiFishApp extends StatelessWidget {
  const AsciiFishApp({super.key, required this.game});
  final GameController game;

  static ThemeData buildTheme(AsciiTheme t) {
    final brightness = t.isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: kMonoFamily,
      fontFamilyFallback: kMonoFallback,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: t.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: t.accent,
        brightness: brightness,
        surface: t.bg,
        onSurface: t.fg,
        primary: t.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: game.themeId,
      builder: (context, id, _) {
        final t = themeById(id);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ASCII Fish Pet',
          theme: buildTheme(t),
          home: Scaffold(backgroundColor: Colors.transparent, body: AquariumScreen(game: game)),
        );
      },
    );
  }
}
