enum FishMode { wandering, seekingFood, curious, jumping }

class FishState {
  double x = 5;
  double y = 4;
  double vx = 0;
  double vy = 0;
  int facing = 1; // 1 = direita, -1 = esquerda
  int width = 8;
  FishMode mode = FishMode.wandering;
  double tailPhase = 0;

  /// Fase e amplitude da onda do corpo (integradas no tempo: sem saltos ao mudar de velocidade).
  double wavePhase = 0;
  double waveAmp = 1;

  double get mouthX => facing > 0 ? x + width : x;
}

/// Companheiros (peixe pequeno / camarão).
class Critter {
  Critter(this.kind, this.x, this.y);
  final String kind; // 'fish' | 'shrimp'
  double x;
  double y;
  int facing = 1;
  double tx = 0;
  double ty = 0;
  double timer = 0;
  double vx = 0;
  double vy = 0;
  int width = 5;
}
