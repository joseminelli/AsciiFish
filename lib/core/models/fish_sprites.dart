class FishStage {
  const FishStage(this.name, this.minLevel, this.body);
  final String name;
  final int minLevel;

  /// Corpo virado para a esquerda; `{T}` é substituído pelo frame da cauda.
  final String body;
}

const kStages = [
  FishStage('Alevino', 1, '<o))' '{T}'),
  FishStage('Peixe Jovem', 3, '<o))))' '{T}'),
  FishStage('Peixe Adulto', 6, '<°)))))' '{T}'),
  FishStage('Peixe-anjo', 10, '<{°)))))}' '{T}'),
  FishStage('Tubarão', 15, '<=°))))))))))' '{T}'),
  FishStage('Dragão Marinho', 20, '<§°)))~)))~)))' '{T}'),
];

const _tailFrames = ['><', '>-'];

const _mirrorMap = {
  '<': '>', '>': '<', '(': ')', ')': '(', '/': r'\', r'\': '/', '{': '}', '}': '{',
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

  static String frame(int level, {required bool facingRight, required int tail}) {
    final left = stageFor(level).body.replaceFirst('{T}', _tailFrames[tail % _tailFrames.length]);
    return facingRight ? mirrorSprite(left) : left;
  }

  static int widthFor(int level) => frame(level, facingRight: false, tail: 0).length;
}
