import 'package:flutter/material.dart';

import '../../app/game_controller.dart';
import '../../core/models/ascii_theme.dart';
import '../../core/models/fish_sprites.dart';
import '../../core/models/shop_catalog.dart';
import '../../core/simulation/progression_service.dart';
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

  GameController get g => widget.game;

  @override
  Widget build(BuildContext context) {
    final th = g.theme;
    final base = TextStyle(fontFamily: kMonoFamily, fontSize: 12, color: th.fg);
    return Material(
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
              height: 28,
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  for (final (i, t) in const [
                    'Status',
                    'Loja',
                    'Opçõesss',
                  ].indexed)
                    InkWell(
                      onTap: () => setState(() => _tab = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: Text(
                          _tab == i ? '[$t]' : ' $t ',
                          style: base.copyWith(
                            color: _tab == i ? th.accent : th.fg,
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
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: switch (_tab) {
                  0 => _status(th, base),
                  1 => _shop(th, base),
                  _ => [..._options(th, base), ..._debug(th, base)],
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _status(AsciiTheme th, TextStyle base) {
    final p = g.progress;
    final sprite = FishSprites.frame(p.level, facingRight: false, tail: 0);
    return [
      Text(sprite, style: base.copyWith(color: g.fishColor(0), fontSize: 16)),
      Text('${g.stage.name} · Nível ${p.level}'),
      Text('XP ${p.xp}/${p.xpToNextLevel}'),
      const SizedBox(height: 6),
      Text(
        'Fome ${p.hunger.round()}  Humor ${p.happiness.round()}  Limpeza ${p.cleanliness.round()}',
      ),
      Text(
        'Refeições ${p.feedCount}  Limpezas ${p.cleanCount}  Dias ${p.daysCared.length}',
      ),
      const SizedBox(height: 10),
      Text('Como ganhar pérolas', style: base.copyWith(color: th.accent)),
      Text(
        '• Alimentar com fome < 60: +1 por floco\n'
        '• Subir de nível: +10 + nível\n'
        '• Limpar 3+ sujeiras de uma vez: +1\n'
        '• Cada conquista: +15',
        style: base.copyWith(fontSize: 11),
      ),
      const SizedBox(height: 10),
      Text('Conquistas', style: base.copyWith(color: th.accent)),
      for (final a in kAchievements)
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '${p.achievements.contains(a.id) ? '[x]' : '[ ]'} ${a.name}\n      ${a.desc}',
            style: base.copyWith(
              fontSize: 11,
              color: th.fg.withValues(
                alpha: p.achievements.contains(a.id) ? 1 : 0.5,
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _shop(AsciiTheme th, TextStyle base) {
    const titles = {
      ShopCategory.theme: 'Temas',
      ShopCategory.fishColor: 'Cores do peixe',
      ShopCategory.food: 'Rações',
      ShopCategory.decor: 'Decorações',
      ShopCategory.companion: 'Companheiros',
    };
    final out = <Widget>[];
    for (final cat in ShopCategory.values) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(titles[cat]!, style: base.copyWith(color: th.accent)),
        ),
      );
      for (final it in kShopItems.where((i) => i.category == cat)) {
        final owned = g.owns(it);
        final equipped = g.isEquipped(it);
        final selectable =
            cat == ShopCategory.theme ||
            cat == ShopCategory.fishColor ||
            cat == ShopCategory.food;
        String action;
        VoidCallback? onTap;
        if (!owned) {
          action =
              '[${it.price}●${it.minLevel > 1 ? ' Nv${it.minLevel}' : ''}]';
          onTap = () => g.buy(it);
        } else if (selectable) {
          action = equipped ? '[em uso]' : '[usar]';
          onTap = equipped ? null : () => g.equip(it);
        } else {
          action = '[ok]';
        }
        out.add(
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  if (cat == ShopCategory.fishColor) _swatch(it, th),
                  Expanded(
                    child: Text(
                      '${it.name}\n${it.desc}',
                      style: base.copyWith(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    action,
                    style: base.copyWith(color: owned ? th.fg : th.food),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return out;
  }

  Widget _swatch(ShopItem it, AsciiTheme th) {
    final fc = kFishColors.firstWhere(
      (c) => c.id == it.id,
      orElse: () => kFishColors.first,
    );
    final color = fc.color ?? th.fish;
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fc.rainbow ? null : color,
        gradient: fc.rainbow
            ? const SweepGradient(
                colors: [
                  Color(0xFFFF4D4D),
                  Color(0xFFFFC21A),
                  Color(0xFF4DFF88),
                  Color(0xFF4DA3FF),
                  Color(0xFFFF7AC8),
                  Color(0xFFFF4D4D),
                ],
              )
            : null,
        border: Border.all(color: th.fg.withValues(alpha: 0.5)),
      ),
    );
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
