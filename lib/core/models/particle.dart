enum ParticleType { bubble, food, dirt }

/// Bolhas, flocos de comida e sujeira. Coordenadas em células (colunas/linhas), contínuas.
class Particle {
  Particle(this.type, this.x, this.y, this.ch, {this.tag = '', this.bright = false})
      : x0 = x;

  final ParticleType type;
  double x;
  double y;
  double x0; // âncora horizontal para a deriva senoidal
  double vy = 0;
  double phase = 0;
  double age = 0;
  String ch;
  String tag; // id da ração (food)
  bool bright;
  bool settled = false;
}
