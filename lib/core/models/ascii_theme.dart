import 'dart:ui';

class AsciiTheme {
  const AsciiTheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.bg,
    required this.fg,
    required this.accent,
    required this.fish,
    required this.plant,
    required this.food,
    required this.dirt,
    required this.bubble,
    required this.sand,
    required this.rock,
  });

  final String id;
  final String name;
  final bool isDark;
  final Color bg;
  final Color fg;
  final Color accent;
  final Color fish;
  final Color plant;
  final Color food;
  final Color dirt;
  final Color bubble;

  /// Areia do fundo e pedras (cores próprias, diferentes da sujeira).
  final Color sand;
  final Color rock;
}

const kThemes = [
  AsciiTheme(
    id: 'theme_oled',
    name: 'OLED Dark',
    isDark: true,
    bg: Color(0xFF000000),
    fg: Color(0xFF9AA4AE),
    accent: Color(0xFF5AC8FA),
    fish: Color(0xFFFFB84D),
    plant: Color(0xFF3FA66B),
    food: Color(0xFFE8D28A),
    dirt: Color(0xFF6B5B45),
    bubble: Color(0xFF7FB4D6),
    sand: Color(0xFFA68B5B),
    rock: Color(0xFF7C8794),
  ),
  AsciiTheme(
    id: 'theme_cyan',
    name: 'Ciano Aquário',
    isDark: true,
    bg: Color(0xFF06222B),
    fg: Color(0xFF7FE7F5),
    accent: Color(0xFFB8F5FF),
    fish: Color(0xFFE9FEFF),
    plant: Color(0xFF3CC9A6),
    food: Color(0xFFFFE8A3),
    dirt: Color(0xFF3B6B73),
    bubble: Color(0xFF9FEFFF),
    sand: Color(0xFFB5AD7E),
    rock: Color(0xFF5F93A0),
  ),
  AsciiTheme(
    id: 'theme_phosphor',
    name: 'Fósforo Verde',
    isDark: true,
    bg: Color(0xFF021003),
    fg: Color(0xFF2BD34A),
    accent: Color(0xFF7CFF8F),
    fish: Color(0xFF9CFFAA),
    plant: Color(0xFF1E9E37),
    food: Color(0xFFC4FFCB),
    dirt: Color(0xFF14612A),
    bubble: Color(0xFF46E863),
    sand: Color(0xFF2F9A45),
    rock: Color(0xFF6FBF86),
  ),
  AsciiTheme(
    id: 'theme_amber',
    name: 'Âmbar',
    isDark: true,
    bg: Color(0xFF140A00),
    fg: Color(0xFFE8A33A),
    accent: Color(0xFFFFC85C),
    fish: Color(0xFFFFD27A),
    plant: Color(0xFFB57A1E),
    food: Color(0xFFFFE3A8),
    dirt: Color(0xFF6E4A14),
    bubble: Color(0xFFF0B455),
    sand: Color(0xFFD1A55E),
    rock: Color(0xFF8A7B66),
  ),
  AsciiTheme(
    id: 'theme_paper',
    name: 'Paper Light',
    isDark: false,
    bg: Color(0xFFF4EFE6),
    fg: Color(0xFF3A3A3A),
    accent: Color(0xFF1F5E8C),
    fish: Color(0xFFA8451A),
    plant: Color(0xFF3E7A4B),
    food: Color(0xFF745810),
    dirt: Color(0xFF9A8C77),
    bubble: Color(0xFF5E86A8),
    sand: Color(0xFFC9B58A),
    rock: Color(0xFF77746D),
  ),
];

AsciiTheme themeById(String id) =>
    kThemes.firstWhere((t) => t.id == id, orElse: () => kThemes.first);

/// Cores personalizadas do peixe (null = cor do tema; rainbow = ciclo de matiz).
class FishColor {
  const FishColor(this.id, this.color, {this.rainbow = false});
  final String id;
  final Color? color;
  final bool rainbow;
}

const kFishColors = [
  FishColor('fcolor_default', null),
  FishColor('fcolor_gold', Color(0xFFFFC21A)),
  FishColor('fcolor_red', Color(0xFFFF4D4D)),
  FishColor('fcolor_blue', Color(0xFF4DA3FF)),
  FishColor('fcolor_green', Color(0xFF4DFF88)),
  FishColor('fcolor_pink', Color(0xFFFF7AC8)),
  FishColor('fcolor_white', Color(0xFFF2F2F2)),
  FishColor('fcolor_rainbow', null, rainbow: true),
];
