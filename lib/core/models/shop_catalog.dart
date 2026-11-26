enum ShopCategory { theme, food, decor, companion }

class ShopItem {
  const ShopItem(
    this.id,
    this.name,
    this.desc,
    this.category,
    this.price, {
    this.minLevel = 1,
  });
  final String id;
  final String name;
  final String desc;
  final ShopCategory category;
  final int price;
  final int minLevel;
}

class FoodDef {
  const FoodDef(this.id, this.hunger, this.xp);
  final String id;
  final double hunger;
  final int xp;
}

const kFoods = [
  FoodDef('food_basic', 6, 2),
  FoodDef('food_nutritious', 8, 4),
  FoodDef('food_bright', 7, 3),
];

FoodDef foodById(String id) =>
    kFoods.firstWhere((f) => f.id == id, orElse: () => kFoods.first);

const kShopItems = [
  // Temas
  ShopItem('theme_oled', 'OLED Dark', 'Preto profundo.', ShopCategory.theme, 0),
  ShopItem(
    'theme_cyan',
    'Ciano Aquário',
    'Vidro luminoso.',
    ShopCategory.theme,
    60,
  ),
  ShopItem(
    'theme_phosphor',
    'Fósforo Verde',
    'Terminal retrô.',
    ShopCategory.theme,
    80,
  ),
  ShopItem('theme_amber', 'Âmbar', 'Monitor antigo.', ShopCategory.theme, 80),
  ShopItem(
    'theme_paper',
    'Paper Light',
    'Claro, tinta sobre papel.',
    ShopCategory.theme,
    100,
  ),
  // Rações
  ShopItem('food_basic', 'Floco Básico', 'Ração padrão.', ShopCategory.food, 0),
  ShopItem(
    'food_nutritious',
    'Ração Nutritiva',
    'Mais fome saciada e +XP.',
    ShopCategory.food,
    40,
  ),
  ShopItem(
    'food_bright',
    'Ração Brilhante',
    'Brilha e solta bolhas extras.',
    ShopCategory.food,
    80,
  ),
  // Decorações
  ShopItem(
    'decor_plants',
    'Jardim Alto',
    'Mais plantas, mais altas.',
    ShopCategory.decor,
    50,
  ),
  ShopItem(
    'decor_rocks',
    'Pedras',
    'Rochas no fundo: /\\',
    ShopCategory.decor,
    40,
  ),
  ShopItem(
    'decor_shells',
    'Conchas',
    'Conchas na areia: @',
    ShopCategory.decor,
    40,
  ),
  ShopItem(
    'decor_castle',
    'Castelo ASCII',
    'Um castelinho.',
    ShopCategory.decor,
    120,
    minLevel: 5,
  ),
  ShopItem(
    'decor_oxygen',
    'Oxigenador',
    'Bolhas contínuas no fundo.',
    ShopCategory.decor,
    70,
  ),
  // Companheiros
  ShopItem(
    'comp_fish',
    'Peixinho Amigo',
    'Um peixe pequeno nada junto.',
    ShopCategory.companion,
    150,
    minLevel: 8,
  ),
  ShopItem(
    'comp_shrimp',
    'Camarão',
    'Anda pelo fundo.',
    ShopCategory.companion,
    200,
    minLevel: 10,
  ),
];
