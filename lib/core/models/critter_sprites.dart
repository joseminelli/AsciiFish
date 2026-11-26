import 'fish_sprites.dart';

/// Sprites dos companheiros: peixinho, caranguejo e lula (todos com frames de animação).
class CritterSprites {
  static const _fishTail = ['><', '>-'];

  static String fish(bool right, int tail) {
    final left = '<o)${_fishTail[tail % _fishTail.length]}';
    return right ? mirrorSprite(left) : left;
  }

  /// Garras abrindo/fechando e olhos piscando.
  static String crab(int claw, bool blink) {
    final c = claw % 2 == 0 ? r'(\/)' : r'(/\)';
    final eyes = blink ? '(-,,-)' : '(°,,°)';
    return '$c $eyes $c';
  }

  /// Tentáculos alternando entre 彡 e ミ.
  static String squid(bool right, int t) {
    final tent = t % 2 == 0 ? '彡' : 'ミ';
    return right ? '$tent:ㄷ>' : '<コ:$tent';
  }

  /// Largura em células (caracteres CJK ocupam 2).
  static int widthOf(String kind) => switch (kind) {
    'crab' => 16,
    'squid' => 6,
    _ => 5,
  };
}
