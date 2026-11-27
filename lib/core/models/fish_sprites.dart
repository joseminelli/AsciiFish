import 'package:flutter/painting.dart';

class FishStage {
  const FishStage(this.name, this.minLevel, this.body);
  final String name;
  final int minLevel;

  /// Corpo virado para a esquerda; `{T}` é substituído pelo frame da cauda.
  final String body;
}

const kStages = [
  FishStage(
    'Alevino',
    1,
    '<o))'
        '{T}',
  ),
  FishStage(
    'Peixe Jovem',
    3,
    '<o))))'
        '{T}',
  ),
  FishStage(
    'Peixe Adulto',
    6,
    '<°)))))'
        '{T}',
  ),
  FishStage(
    'Peixe-anjo',
    10,
    '<{°)))))}'
        '{T}',
  ),
  FishStage(
    'Tubarão',
    15,
    '<=°))))))))))'
        '{T}',
  ),
  FishStage(
    'Dragão Marinho',
    20,
    '<§°)))~)))~)))'
        '{T}',
  ),
];

const _tailFrames = ['><', '>-'];

const _mirrorMap = {
  '<': '>',
  '>': '<',
  '(': ')',
  ')': '(',
  '/': r'\',
  r'\': '/',
  '{': '}',
  '}': '{',
};

String mirrorSprite(String s) =>
    s.split('').reversed.map((c) => _mirrorMap[c] ?? c).join();

class FishSprites {
  static FishStage stageFor(int level) {
    var s = kStages.first;
    for (final st in kStages) {
      if (level >= st.minLevel) s = st;
    }
    return s;
  }

  static String frame(
    int level, {
    required bool facingRight,
    required int tail,
    bool blink = false,
    bool mouth = false,
  }) {
    var left = stageFor(level).body
        .replaceFirst('{T}', _tailFrames[tail % _tailFrames.length]);
    if (blink) {
      final i = left.indexOf(RegExp('[o°]'));
      if (i >= 0) left = left.replaceRange(i, i + 1, '-'); // olho fechado
    }
    if (mouth && left.startsWith('<'))
      left = '(${left.substring(1)}'; // boca aberta
    return facingRight ? mirrorSprite(left) : left;
  }

  /// Zona de cor de cada caractere do sprite (mesmo tamanho do [frame]):
  /// `A` corpo, `B` detalhes (cabeça, cauda, nadadeiras), `C` olho.
  static String zones(int level, {required bool facingRight}) {
    final left = stageFor(level).body.replaceFirst('{T}', _tailFrames[0]);
    final eye = left.indexOf(RegExp('[o°]'));
    final z = StringBuffer();
    for (var i = 0; i < left.length; i++) {
      final c = left[i];
      if (i == eye) {
        z.write('C');
      } else if (i == 0 || i >= left.length - 2 || '{}=§~'.contains(c)) {
        z.write('B');
      } else {
        z.write('A');
      }
    }
    final s = z.toString();
    return facingRight ? s.split('').reversed.join() : s;
  }

  static int widthFor(int level) =>
      frame(level, facingRight: false, tail: 0).length;
}

/// Três cores do peixe, derivadas da cor principal [a]: detalhes [b] e olho [c].
class FishPalette {
  const FishPalette(this.a, this.b, this.c);
  final Color a, b, c;

  factory FishPalette.from(Color a) {
    final hsl = HSLColor.fromColor(a);
    final l = hsl.lightness;
    final b = hsl
        .withLightness(l > 0.6 ? l - 0.26 : l + 0.2)
        .withHue((hsl.hue + 14) % 360)
        .toColor();
    final c = l > 0.82 ? const Color(0xFF1E2A36) : const Color(0xFFFFFFFF);
    return FishPalette(a, b, c);
  }

  Color of(String zone) => zone == 'B'
      ? b
      : zone == 'C'
      ? c
      : a;

  /// Sprite como trechos coloridos (para Text.rich).
  List<TextSpan> spans(String sprite, String zones) => [
    for (var i = 0; i < sprite.length; i++)
      TextSpan(text: sprite[i], style: TextStyle(color: of(zones[i]))),
  ];
}
