import 'package:flutter/material.dart';

import '../../app/game_controller.dart';
import '../../core/models/ascii_theme.dart';
import '../../core/models/critter_sprites.dart';
import '../../core/models/fish_sprites.dart';
import '../../core/models/shop_catalog.dart';
import '../../core/simulation/progression_service.dart';
import '../../platform/startup_service.dart';
import '../painter/aquarium_painter.dart';

/// Painel interno compacto: Status, Loja e Opções.
class SideDrawerMenu extends StatefulWidget {
  const SideDrawerMenu(this.game, {super.key});
  final GameController game;

  @override
  State<SideDrawerMenu> createState() => _SideDrawerMenuState();
}

class _SideDrawerMenuState extends State<SideDrawerMenu> {
  int _tab = 0;
  ShopCategory _shopCat = ShopCategory.theme;
  bool _onlyNew = false; // loja: esconde o que já foi comprado

  GameController get g => widget.game;

  @override
  Widget build(BuildContext context) {
    final th = g.theme;
    final base = TextStyle(fontFamily: kMonoFamily, fontSize: 12, color: th.fg);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: Material(
        color: th.bg.withValues(alpha: 0.96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: th.fg.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: DefaultTextStyle(
          style: base,
          child: Column(
            children: [
              SizedBox(
                height: 34,
                child: Row(
                  children: [
                    const SizedBox(width: 6),
                    for (final (i, t) in _tabs.indexed)
                      InkWell(
                        onTap: () => setState(() => _tab = i),
                        child: Container(
                          height: 34,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                width: 2,
                                color: _tab == i
                                    ? th.accent
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          child: Text(
                            t,
                            style: base.copyWith(
                              color: _tab == i
                                  ? th.accent
                                  : th.fg.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '● ${g.progress.pearls}',
                      style: base.copyWith(color: th.food),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      color: th.fg,
                      icon: const Icon(Icons.close),
                      onPressed: () => g.setMenu(false),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: th.fg.withValues(alpha: 0.25)),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: ListView(
                    key: ValueKey(_tab == 1 ? 'shop-$_shopCat-$_onlyNew' : 'tab-$_tab'),
                    padding: const EdgeInsets.all(10),
                    children: switch (_tab) {
                      0 => _status(th, base),
                      1 => _shop(th, base),
                      _ => [..._options(th, base), ..._debug(th, base)],
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vermelho de alerta (mais escuro no tema claro, para manter o contraste).
  Color get _warn =>
      g.theme.isDark ? const Color(0xFFE5533D) : const Color(0xFFB3261E);
  static const _tabs = ['Status', 'Loja', 'Opções'];
  static const _catTitles = {
    ShopCategory.theme: 'Temas',
    ShopCategory.fishColor: 'Cores',
    ShopCategory.food: 'Rações',
    ShopCategory.decor: 'Decoração',
    ShopCategory.light: 'Luzes',
    ShopCategory.companion: 'Amigos',
  };

  // ------------------------------------------------------------ helpers

  Widget _card(
    AsciiTheme th,
    TextStyle base, {
    String? title,
    required Widget child,
    Color? border,
    double? width,
    EdgeInsets pad = const EdgeInsets.all(10),
  }) {
    return Container(
      width: width,
      margin: width == null ? const EdgeInsets.only(bottom: 8) : null,
      padding: pad,
      decoration: BoxDecoration(
        color: th.fg.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border ?? th.fg.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(title, style: base.copyWith(color: th.accent)),
            const SizedBox(height: 6),
          ],
          child,
        ],
      ),
    );
  }

  static String _bar(double v, double max, {int w = 20}) {
    final n = max <= 0 ? 0 : (v / max * w).round().clamp(0, w);
    return '[${'#' * n}${'.' * (w - n)}]';
  }

  Widget _meter(
    AsciiTheme th,
    TextStyle base,
    String label,
    double v,
    double max, {
    String? right,
    bool warnLow = true,
  }) {
    final low = warnLow && v / max < 0.3;
    final c = low ? _warn : th.fg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 54, child: Text(label, style: base)),
          Expanded(
            child: Text(
              _bar(v, max),
              style: base.copyWith(color: c),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              right ?? '${(v / max * 100).round()}%',
              textAlign: TextAlign.right,
              style: base.copyWith(color: c, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  String _mood(double h) => h >= 80
      ? ':D  Radiante'
      : h >= 60
      ? ':)  Contente'
      : h >= 35
      ? ':|  Meio assim'
      : ':(  Triste';

  // -------------------------------------------------------------- status

  List<Widget> _status(AsciiTheme th, TextStyle base) {
    final p = g.progress;
    final dim = base.copyWith(
      fontSize: 11,
      color: th.fg.withValues(alpha: 0.65),
    );
    final sprite = FishSprites.frame(p.level, facingRight: false, tail: 0);
    final next = kStages.where((s) => s.minLevel > p.level).firstOrNull;
    final rainbowT = DateTime.now().millisecondsSinceEpoch / 1000.0;

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: base.copyWith(
              fontSize: 16,
              color: th.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: dim.copyWith(fontSize: 10)),
        ],
      ),
    );

    return [
      _card(
        th,
        base,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: th.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: g.fishPalette(rainbowT).spans(
                      sprite,
                      FishSprites.zones(
                        p.level,
                        facingRight: false,
                        stripes: g.fishStripes,
                      ),
                    ),
                  ),
                  style: base.copyWith(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  g.stage.name,
                  style: base.copyWith(fontSize: 14, color: th.accent),
                ),
                const Spacer(),
                Text('Nível ${p.level}', style: base.copyWith(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            _meter(
              th,
              base,
              'XP',
              p.xp.toDouble(),
              p.xpToNextLevel.toDouble(),
              right: '${p.xp}/${p.xpToNextLevel}',
              warnLow: false,
            ),
            Text(
              next == null
                  ? 'Forma máxima alcançada!'
                  : 'Próxima forma: ${next.name} no nível ${next.minLevel}',
              style: dim,
            ),
          ],
        ),
      ),
      _card(
        th,
        base,
        title: 'Como ele está',
        child: Column(
          children: [
            _meter(th, base, 'Fome', p.hunger, 100),
            _meter(th, base, 'Humor', p.happiness, 100),
            _meter(th, base, 'Limpeza', p.cleanliness, 100),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _mood(p.happiness),
                style: dim.copyWith(
                  color: p.happiness < 35
                      ? _warn
                      : th.fg.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
      _card(
        th,
        base,
        pad: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            stat('${p.feedCount}', 'refeições'),
            stat('${p.cleanCount}', 'limpezas'),
            stat('${p.interactCount}', 'carinhos'),
            stat('${p.daysCared.length}', 'dias'),
          ],
        ),
      ),
      _card(
        th,
        base,
        title: 'Conquistas  ${p.achievements.length}/${kAchievements.length}',
        child: Column(
          children: [
            for (final a in kAchievements) _achievement(th, base, dim, a),
          ],
        ),
      ),
      _card(
        th,
        base,
        title: 'Como deixar o peixe feliz e ganhar pérolas',
        child: Text(
          '• Alimentar com fome < 60: +1 pérola por floco\n'
          '• Tocar no peixe: carinho, corações e +humor\n'
          '• Manter a água limpa e o peixe alimentado\n'
          '• Companheiros e decorações aumentam o humor\n'
          '• Limpar 3+ sujeiras de uma vez: +1 pérola\n'
          '• Subir de nível: +10 + nível · Conquista: +15',
          style: dim,
        ),
      ),
    ];
  }

  Widget _achievement(
    AsciiTheme th,
    TextStyle base,
    TextStyle dim,
    Achievement a,
  ) {
    final p = g.progress;
    final done = p.achievements.contains(a.id);
    final v = achievementValue(a.id, p).clamp(0, a.target);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            done ? '★' : '☆',
            style: base.copyWith(
              fontSize: 18,
              color: done ? th.food : th.fg.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.name,
                  style: base.copyWith(
                    color: done ? th.accent : th.fg.withValues(alpha: 0.85),
                  ),
                ),
                Text(a.desc, style: dim.copyWith(fontSize: 10)),
                if (!done)
                  Text(
                    '${_bar(v.toDouble(), a.target.toDouble(), w: 12)} $v/${a.target}',
                    style: dim.copyWith(fontSize: 10),
                  ),
              ],
            ),
          ),
          if (done)
            Text('+15●', style: dim.copyWith(color: th.food, fontSize: 10)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- loja

  List<Widget> _shop(AsciiTheme th, TextStyle base) {
    final all = kShopItems.where((i) => i.category == _shopCat).toList();
    final items = _onlyNew ? all.where((i) => !g.owns(i)).toList() : all;
    int ownedIn(ShopCategory c) =>
        kShopItems.where((i) => i.category == c && g.owns(i)).length;
    int totalIn(ShopCategory c) =>
        kShopItems.where((i) => i.category == c).length;
    return [
      Row(
        children: [
          Text(
            '● ${g.progress.pearls} pérolas',
            style: base.copyWith(
              color: th.food,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _onlyNew = !_onlyNew),
            child: _pill(
              _onlyNew ? '✓ Só novidades' : 'Só novidades',
              th.accent,
              filled: _onlyNew,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in ShopCategory.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _shopCat = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _shopCat == c
                          ? th.accent.withValues(alpha: 0.18)
                          : null,
                      border: Border.all(
                        color: _shopCat == c
                            ? th.accent
                            : th.fg.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      '${_catTitles[c]!} ${ownedIn(c)}/${totalIn(c)}',
                      style: base.copyWith(
                        fontSize: 11,
                        color: _shopCat == c ? th.accent : th.fg,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Você já tem tudo desta categoria! ✓',
              style: base.copyWith(color: th.fg.withValues(alpha: 0.6)),
            ),
          ),
        ),
      LayoutBuilder(
        builder: (_, box) {
          final w = (box.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final it in items) _shopCard(it, th, base, w)],
          );
        },
      ),
    ];
  }

  Widget _shopCard(ShopItem it, AsciiTheme th, TextStyle base, double w) {
    final owned = g.owns(it);
    final equipped = g.isEquipped(it);
    final selectable =
        it.category == ShopCategory.theme ||
        it.category == ShopCategory.fishColor ||
        it.category == ShopCategory.light ||
        it.category == ShopCategory.food;
    final levelOk = g.progress.level >= it.minLevel;
    final canPay = g.progress.pearls >= it.price;
    final small = base.copyWith(fontSize: 10);

    final Widget status;
    VoidCallback? onTap;
    if (owned) {
      if (selectable) {
        status = _pill(
          equipped ? 'EM USO' : 'Usar',
          th.accent,
          filled: equipped,
        );
        onTap = equipped ? null : () => g.equip(it);
      } else {
        status = _pill('✓ Comprado', th.fg.withValues(alpha: 0.6));
      }
    } else {
      onTap = () => g.buy(it);
      status = Row(
        children: [
          Text(
            '● ${it.price}',
            style: base.copyWith(
              color: canPay ? th.food : th.fg.withValues(alpha: 0.45),
            ),
          ),
          const Spacer(),
          if (!levelOk)
            _pill('Nv ${it.minLevel}', _warn)
          else if (canPay)
            _pill('Comprar', th.accent)
          else
            Text('faltam ${it.price - g.progress.pearls}', style: small),
        ],
      );
    }

    return _card(
      th,
      base,
      width: w,
      pad: const EdgeInsets.all(8),
      border: equipped ? th.accent : null,
      child: Opacity(
        opacity: !owned && !levelOk ? 0.7 : 1,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: th.bg.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _preview(it, th),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                it.name,
                style: base,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(
                height: 26,
                child: Text(
                  it.desc,
                  style: small.copyWith(color: th.fg.withValues(alpha: 0.65)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 20,
                child: Align(alignment: Alignment.centerLeft, child: status),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String t, Color c, {bool filled = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: filled ? c.withValues(alpha: 0.2) : null,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.withValues(alpha: 0.8)),
    ),
    child: Text(
      t,
      style: TextStyle(fontFamily: kMonoFamily, fontSize: 10, color: c),
    ),
  );

  /// Pré-visualização do item (tema, cor, ração, decoração ou bicho).
  Widget _preview(ShopItem it, AsciiTheme th) {
    TextStyle art(Color c, {double size = 13}) => TextStyle(
      fontFamily: kMonoFamily,
      fontSize: size,
      height: 1.05,
      color: c,
    );
    switch (it.category) {
      case ShopCategory.theme:
        final t = themeById(it.id);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: t.fg.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('~  ~  ~', style: art(t.accent, size: 11)),
              Text('<o))))><', style: art(t.fish)),
              Text('.:.,.:.,.', style: art(t.dirt, size: 11)),
            ],
          ),
        );
      case ShopCategory.fishColor:
        final fc = kFishColors.firstWhere(
          (c) => c.id == it.id,
          orElse: () => kFishColors.first,
        );
        final color = fc.rainbow
            ? g.fishColor(DateTime.now().millisecondsSinceEpoch / 1000.0)
            : (fc.color ?? th.fish);
        return Text.rich(
          TextSpan(
            children: FishPalette.from(
              color,
              accent: fc.accent,
            ).spans('<°)))><', fc.stripes ? 'BCABABB' : 'BCAAABB'),
          ),
          style: art(color, size: 20),
        );
      case ShopCategory.food:
        final bright = it.id == 'food_bright';
        final c = bright ? th.accent : th.food;
        final n = it.id == 'food_nutritious' ? 5 : 3;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < n; i++)
              Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.fromLTRB(3, i.isEven ? 0 : 10, 3, 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c,
                  boxShadow: bright
                      ? [
                          BoxShadow(
                            color: c.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
          ],
        );
      case ShopCategory.decor:
        return switch (it.id) {
          'decor_plants' => Text(
            '  ~   ~\n  | ) |\n  ) | )\n  ( | (',
            style: art(th.plant, size: 11),
          ),
          'decor_rocks' => Text(
            '   /\\\n _/  \\_  /\\',
            style: art(th.fg.withValues(alpha: 0.75)),
          ),
          'decor_coral' => Text(
            '\\|/ Y\n |\\/|\n \\||/',
            style: art(const Color(0xFFFF7A6B), size: 12),
          ),
          'decor_anemone' => Text(
            '\\|/|\\|/\n(_____)',
            style: art(const Color(0xFFFF8AD0), size: 12),
          ),
          'decor_shells' => Text('@    @', style: art(th.food, size: 16)),
          'decor_castle' => Text(
            '|^|^|^|\n|[_ _]|\n|_| |_|',
            style: art(th.fg.withValues(alpha: 0.85), size: 11),
          ),
          _ => Text(' o\n°\n .\n°', style: art(th.bubble, size: 11)),
        };
      case ShopCategory.light:
        final lc = switch (it.id) {
          'light_blue' => const Color(0xFF4DA3FF),
          'light_purple' => const Color(0xFFB07CFF),
          _ => null,
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: lc == null
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      lc.withValues(alpha: 0.55),
                      lc.withValues(alpha: 0.1),
                    ],
                  ),
          ),
          child: Text('<o))))><', style: art(th.fish)),
        );
      case ShopCategory.companion:
        return switch (it.id) {
          'comp_fish' => Text(
            CritterSprites.fish(false, 0),
            style: art(g.fishColor(0), size: 18),
          ),
          'comp_crab' => Text(
            CritterSprites.crab(0, false),
            style: art(const Color(0xFFE5533D), size: 11),
          ),
          _ => Text(
            CritterSprites.squid(false, 0),
            style: art(const Color(0xFFB48CFF), size: 18),
          ),
        };
    }
  }

  String _fmtHour(double h) {
    final hh = h.floor() % 24;
    final mm = ((h - h.floor()) * 60).round() % 60;
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  List<Widget> _debug(AsciiTheme th, TextStyle base) {
    Widget b(String label, VoidCallback f) => Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide(color: th.accent.withValues(alpha: 0.6)),
        ),
        onPressed: f,
        child: Text(
          label,
          style: base.copyWith(fontSize: 11, color: th.accent),
        ),
      ),
    );
    return [
      const SizedBox(height: 10),
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text('Modo debug (testes)', style: base),
        value: g.settings.debugMode,
        onChanged: g.setDebugMode,
      ),
      if (g.settings.debugMode)
        Wrap(
          children: [
            b('+500 pérolas', () => g.debugAddPearls(500)),
            b('+1 nível', () => g.debugAddLevels(1)),
            b('+5 níveis', () => g.debugAddLevels(5)),
            b('Desbloquear tudo', g.debugUnlockAll),
            b('Sujar a água', g.debugSpawnDirt),
            b('Pular agora', g.debugJump),
            b('Fome 10%', () => g.debugSetHunger(10)),
            b('Fome 100%', () => g.debugSetHunger(100)),
            b('Resetar progresso', g.debugReset),
          ],
        ),
      if (g.settings.debugMode) ...[
        Text(
          'Hora do dia (debug): ${_fmtHour(g.debugHour)}',
          style: base.copyWith(fontSize: 11),
        ),
        Slider(
          min: 0,
          max: 24,
          divisions: 96,
          value: g.debugHour.clamp(0, 24).toDouble(),
          onChanged: g.setDebugHour,
        ),
        Wrap(
          children: [
            b('Madrugada 3h', () => g.setDebugHour(3)),
            b('Manhã 7h', () => g.setDebugHour(7)),
            b('Dia 13h', () => g.setDebugHour(13)),
            b('Entardecer 18h', () => g.setDebugHour(18)),
            b('Noite 23h', () => g.setDebugHour(23)),
          ],
        ),
      ],
    ];
  }

  List<Widget> _options(AsciiTheme th, TextStyle base) {
    final s = g.settings;
    Widget sw(String label, bool v, ValueChanged<bool> on) => SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: base),
      value: v,
      onChanged: on,
    );
    return [
      sw(
        'Modo widget (sob os apps, sobre o desktop)',
        s.widgetMode,
        g.setWidgetMode,
      ),
      sw('Sempre no topo', s.alwaysOnTop, g.setAlwaysOnTop),
      sw(
        'Peixe reage ao mouse (seguir / pular no clique)',
        s.fishReacts,
        g.setFishReacts,
      ),
      sw('Esconder HUD automaticamente', s.autoHideHud, g.setAutoHideHud),
      sw('Ciclo dia e noite (segue o relógio)', s.dayNight, g.setDayNight),
      sw(
        StartupService.available
            ? 'Iniciar com o Windows'
            : 'Iniciar com o Windows (só no app instalado)',
        g.launchAtStartup,
        (v) => StartupService.available ? g.setLaunchAtStartup(v) : null,
      ),
      sw('Procurar atualizações ao abrir', s.autoUpdate, g.setAutoUpdate),
      Row(
        children: [
          Expanded(
            child: Text(
              'Versão ${g.appVersion.isEmpty ? '...' : g.appVersion}'
              '${g.updateMsg.isEmpty ? '' : '\n${g.updateMsg}'}',
              style: base.copyWith(fontSize: 11),
            ),
          ),
          TextButton(
            onPressed: g.updateBusy
                ? null
                : (g.update != null ? g.installUpdate : g.checkUpdates),
            child: Text(
              g.update != null
                  ? '[ Instalar ${g.update!.version} ]'
                  : '[ Procurar ]',
              style: base.copyWith(color: th.accent, fontSize: 11),
            ),
          ),
        ],
      ),
      Row(
        children: [
          Text('Quadros por segundo', style: base),
          const Spacer(),
          for (final f in const [60, 30, 20])
            TextButton(
              onPressed: () => g.setFps(f),
              child: Text(
                s.fps == f ? '[$f]' : ' $f ',
                style: base.copyWith(
                  color: s.fps == f ? th.accent : th.fg.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 4),
      Text('Tamanho da fonte: ${s.fontSize.round()}'),
      Slider(
        min: 10,
        max: 20,
        divisions: 10,
        value: s.fontSize.clamp(10, 20).toDouble(),
        onChanged: g.setFontSize,
      ),
      Text('Altura do aquário: ${(s.windowHeight ?? 200).round()} px'),
      Slider(
        min: 140,
        max: 420,
        divisions: 28,
        value: (s.windowHeight ?? 200).clamp(140, 420).toDouble(),
        onChanged: g.setWindowHeight,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: g.snapToCorner,
          child: Text(
            '[ Reencaixar na barra de tarefas ]',
            style: base.copyWith(color: th.accent, fontSize: 11),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text('Atalhos', style: base.copyWith(color: th.accent)),
      Text(
        'Ctrl+clique alimentar onde clicar (na água)\nCtrl+Alt+F  alimentar no X do mouse (global)\nF / Espaço  idem (com a janela em foco)\nC            limpar\nEsc          fechar menu\nClique       limpar sujeira / carinho no peixe',
        style: base.copyWith(fontSize: 11),
      ),
    ];
  }
}
