class GameProgress {
  GameProgress({
    this.level = 1,
    this.xp = 0,
    this.pearls = 20,
    this.hunger = 80,
    this.happiness = 80,
    this.cleanliness = 100,
    Set<String>? owned,
    Set<String>? achievements,
    Set<String>? daysCared,
    this.foodId = 'food_basic',
    this.feedCount = 0,
    this.cleanCount = 0,
    this.interactCount = 0,
    this.colorChanges = 0,
    this.nightFeeds = 0,
    DateTime? lastSavedAt,
  }) : owned =
           owned ??
           {'theme_oled', 'food_basic', 'fcolor_default', 'light_none'},
       achievements = achievements ?? {},
       daysCared = daysCared ?? {},
       lastSavedAt = lastSavedAt ?? DateTime.now();

  int level;
  int xp;
  int pearls;
  double hunger;
  double happiness;
  double cleanliness;
  final Set<String> owned;
  final Set<String> achievements;
  final Set<String> daysCared; // yyyy-MM-dd
  String foodId;
  int feedCount;
  int cleanCount;
  int interactCount;
  int colorChanges; // trocas de cor/skin do peixe
  int nightFeeds; // refeições de madrugada (0h–5h)
  DateTime lastSavedAt;

  int get xpToNextLevel => 40 + level * 20;

  Map<String, dynamic> toJson() => {
    'level': level,
    'xp': xp,
    'pearls': pearls,
    'hunger': hunger,
    'happiness': happiness,
    'cleanliness': cleanliness,
    'owned': owned.toList(),
    'achievements': achievements.toList(),
    'daysCared': daysCared.toList(),
    'foodId': foodId,
    'feedCount': feedCount,
    'cleanCount': cleanCount,
    'interactCount': interactCount,
    'colorChanges': colorChanges,
    'nightFeeds': nightFeeds,
    'lastSavedAt': lastSavedAt.toIso8601String(),
  };

  factory GameProgress.fromJson(Map<String, dynamic> j) {
    Set<String> set(String k) =>
        ((j[k] as List?) ?? const []).cast<String>().toSet();
    final d = GameProgress();
    return GameProgress(
      level: j['level'] as int? ?? d.level,
      xp: j['xp'] as int? ?? d.xp,
      pearls: j['pearls'] as int? ?? d.pearls,
      hunger: (j['hunger'] as num?)?.toDouble() ?? d.hunger,
      happiness: (j['happiness'] as num?)?.toDouble() ?? d.happiness,
      cleanliness: (j['cleanliness'] as num?)?.toDouble() ?? d.cleanliness,
      owned: _migrate(set('owned')..addAll(d.owned)),
      achievements: set('achievements'),
      daysCared: set('daysCared'),
      foodId: j['foodId'] as String? ?? d.foodId,
      feedCount: j['feedCount'] as int? ?? 0,
      cleanCount: j['cleanCount'] as int? ?? 0,
      interactCount: j['interactCount'] as int? ?? 0,
      colorChanges: j['colorChanges'] as int? ?? 0,
      nightFeeds: j['nightFeeds'] as int? ?? 0,
      lastSavedAt:
          DateTime.tryParse(j['lastSavedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Camarão virou caranguejo: quem já tinha o camarão ganha o caranguejo.
Set<String> _migrate(Set<String> s) {
  if (s.remove('comp_shrimp')) s.add('comp_crab');
  return s;
}
