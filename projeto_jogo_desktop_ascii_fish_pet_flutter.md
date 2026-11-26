# Projeto: ASCII Fish Pet — Jogo Desktop em Flutter (Windows)

## 1. Visão Geral
Criar um **jogo desktop leve e fluido** em **Flutter (Windows)** inspirado em aquários minimalistas em arte ASCII (`<o))))><` / `>((((o>`).
O jogo deve funcionar como um **companheiro/mascote no canto da tela do Windows** que **não sobrepõe outros aplicativos por padrão** (mas oferece a opção *"Sempre no topo"* ativável pelo usuário), combinando uma simulação visual fluida de aquário ASCII com **progressão de jogo, cuidados, desbloqueáveis e opções**.

---

## 2. Objetivos e Requisitos Principais

### 2.1 Comportamento de Janela (Windows Desktop)
- **Posição inicial:** abrir em tamanho compacto (ex.: `340x240` px, redimensionável dentro de limites mínimos/máximos) posicionado no canto inferior direito da área útil da tela (ou restaurar a última posição salva).
- **Sobreposição opcional:**
  - **Padrão:** `alwaysOnTop = false` (funciona como janela normal; ao focar outro app, fica atrás).
  - **Configurável:** toggle *"Sempre no topo"* (`alwaysOnTop = true/false`) acessível rapidamente no menu/HUD.
- **Janela limpa e arrastável:**
  - Barra de título customizada minimalista ou janela sem bordas (`frameless` / `TitleBarStyle.hidden`) com área de arraste discreta para mover pelo desktop.
  - Opção de *"Encaixar no canto"* (resetar posição para o canto da tela).
- **Persistência de janela:** salvar `windowX`, `windowY`, `windowWidth`, `windowHeight` e `alwaysOnTop` localmente.

### 2.2 Estética e Fluidez Visual (ASCII Render)
- **Movimento líquido (60 FPS):**
  - A lógica física usa coordenadas contínuas em ponto flutuante (`double x, y`, `vx, vy`), atualizadas via `deltaTime` (`dt`), evitando movimentos travados célula por célula.
  - A renderização converte posições contínuas para um grid/canvas monoespaçado (`CustomPainter` + `Ticker`) com fonte monoespaçada fixa e sub-pixel ou alinhamento suave para manter a estética ASCII fluida.
- **Elementos do Aquário:**
  - **Peixe principal:** sprite ASCII dinâmico que inverte direção suavemente (`<o))))><` esquerda, `>((((o>` direita), anima a cauda conforme velocidade e muda variação visual conforme evolução/nível.
  - **Bolhas:** partículas (`o`, `°`, `.`) geradas pela boca do peixe e pelo fundo, subindo com leve deriva senoidal até o topo.
  - **Plantas aquáticas:** colunas na base do aquário feitas com caracteres ondulados (`(`, `)`, `~`, `|`) oscilando continuamente com `sin(time * freq + phase)`.
  - **Comida:** flocos (`*`, `•`, `.`) que caem com arrasto da água e oscilação horizontal leve até serem comidos ou chegarem ao fundo.
  - **Sujeira / Qualidade da água (opcional leve):** partículas no fundo ao longo do tempo que podem ser limpas com clique/ferramenta, rendendo XP.

---

## 3. Mecânicas de Jogo e Progressão

### 3.1 Loop de Cuidado e Interação
- **Status do Peixe:**
  - `hunger` (0–100): cai gradualmente com o tempo. Alimentar no momento certo dá bônus de XP e moedas.
  - `happiness` (0–100): sobe ao alimentar, interagir (clicar/atrair o peixe, limpar o aquário) e manter boa qualidade da água.
  - `cleanliness` (0–100): cai lentamente com restos de comida/tempo; limpar dá XP e mantém o peixe mais ativo.
- **Interações diretas no Aquário:**
  - **Clique / Botão Alimentar:** solta flocos de comida no topo da água; o peixe detecta a comida mais próxima, muda para o estado `seekingFood` e nada até ela.
  - **Hover / Toque na água:** atrai a atenção do peixe ou faz ele soltar bolhas.
  - **Limpar:** remove partículas de sujeira acumulada no fundo.
  - **Entrada externa opcional (NFC / Serial / Atalho):** arquitetura preparada para receber evento externo `triggerFeed()` (ex.: tecla `F` ou futuro leitor NFC USB).

### 3.2 Sistema de Progressão
- **XP e Níveis (`level`, `xp`, `xpToNextLevel`):**
  - Ações de cuidado (alimentar, limpar, interagir, manter status altos) concedem XP.
  - **Evolução visual por nível:**
    - Nv. 1–2: Alevino (`<o))><`)
    - Nv. 3–5: Peixe Jovem (`<o))))><`)
    - Nv. 6–9: Peixe Adulto ornamentado (`<°)))))><`)
    - Nv. 10+: Formas especiais desbloqueáveis (ex.: peixe-anjo, tubarão ASCII, dragão marinho).
- **Moedas (`pearls` / `coins`):**
  - Ganhas ao cuidar bem do peixe, subir de nível e completar marcos diários.
- **Loja & Desbloqueáveis:**
  - **Temas / Paletas de Cor:** *OLED Dark*, *Ciano Aquário (estilo vidro luminoso)*, *Fósforo Verde (Retro Terminal)*, *Âmbar*, *Paper Light*.
  - **Tipos de Ração:** *Floco Básico*, *Ração Nutritiva (+XP)*, *Ração Brilhante (efeito visual + bolhas extras)*.
  - **Decorações ASCII:** tipos extras de plantas, pedras (`/\`), conchas (`@`), castelo ASCII ou bolhas de oxigênio contínuas.
  - **Companheiros (End-game):** desbloquear um segundo peixinho menor ou camarão ASCII no fundo.
- **Conquistas / Marcos:**
  - Ex.: *"Primeira Refeição"*, *"Água Cristalina"*, *"Nível 5"*, *"Colecionador de Temas"*, *"3 Dias de Cuidado"*.

### 3.3 Progressão Offline Justa
- Ao fechar e reabrir o jogo, calcular o tempo decorrido (`lastSavedAt`) com **teto máximo** (ex.: no máximo 8–12 horas de decaimento suave) para que o peixe nunca "morra" ou fique irreversivelmente punido se o jogador passar dias sem abrir o PC.

---

## 4. Arquitetura do Projeto Flutter

Manter **separação estrita** entre o motor de simulação/jogo (Dart puro), a renderização (`CustomPainter`), o gerenciamento de estado e a camada de janela Windows.

```text
lib/
├── main.dart                        # Inicialização do window_manager, storage e App
├── app/
│   └── app.dart                     # MaterialApp, temas e configuração global
├── core/
│   ├── models/
│   │   ├── fish_state.dart          # Posição, velocidade, direção, estado AI, espécie/estágio
│   │   ├── particle.dart            # Bolhas, flocos de comida e sujeira
│   │   ├── plant.dart               # Estrutura das plantas ondulantes
│   │   ├── game_progress.dart       # Nível, XP, moedas, inventário, conquistas, stats
│   │   └── app_settings.dart        # alwaysOnTop, tema, posição da janela, som, FPS
│   ├── simulation/
│   │   ├── aquarium_engine.dart     # Loop físico (update(dt)), colisões, IA do peixe
│   │   └── progression_service.dart # Cálculo de XP, level up, moedas, decaimento offline
│   └── storage/
│       └── save_repository.dart     # Persistência JSON local (path_provider) + auto-save
├── ui/
│   ├── painter/
│   │   └── aquarium_painter.dart    # CustomPainter monoespaçado de alta fluidez
│   ├── widgets/
│   │   ├── hud_overlay.dart         # Barra discreta (auto-hide no hover) com status e ações
│   │   ├── top_drag_bar.dart        # Área de arraste da janela + botão pin (alwaysOnTop)
│   │   └── side_drawer_menu.dart    # Menu compacto para Loja, Status, Conquistas e Opções
│   └── screens/
│       └── aquarium_screen.dart     # Tela principal integrando Ticker, gestos e HUD
└── platform/
    └── windows_window_service.dart  # Abstração para window_manager (posição, pin, resize)
```

---

## 5. Dependências Recomendadas (`pubspec.yaml`)
- `window_manager`: controle da janela no Windows (tamanho, posição no canto, `setAlwaysOnTop`, janela sem bordas/arrastável).
- `path_provider`: diretório seguro no Windows (`AppData`) para salvar o JSON de progresso e configurações.
- `google_fonts` (ou fonte monoespaçada embarcada em `assets/fonts/`, ex.: *JetBrains Mono* ou *Fira Code*): garante métricas consistentes de largura/altura dos caracteres sem depender de rede.

*(Evitar dependências pesadas desnecessárias; manter o gerenciamento de estado enxuto com `ChangeNotifier` / `ValueNotifier` ou `Riverpod` simples).*

---

## 6. Especificação de UI / UX (Espaço Compacto)

1. **Modo Aquário Limpo (Padrão quando o mouse está fora):**
   - Mostra apenas o aquário animado + opcionalmente um indicador discreto de nível/fome se estiver baixo.
2. **Hover na Janela (Mouse sobre o aquário):**
   - Exibe suavemente (`AnimatedOpacity`):
     - **Topo:** alça de arraste, ícone de **Pin (`Sempre no topo`)** e botão de **Menu (`⚙`)**.
     - **Base:** botões rápidos (**Alimentar**, **Limpar**) e barras compactas de **Fome**, **Humor** e **XP**.
3. **Painel de Opções & Jogo (Modal/Overlay interno):**
   - **Aba Status:** Nível atual, estágio do peixe, estatísticas e conquistas.
   - **Aba Loja:** Compra/equipe de temas visuais, rações e decorações.
   - **Aba Opções:**
     - Toggle: *Sempre no topo (`alwaysOnTop`)*
     - Toggle: *Esconder HUD automaticamente*
     - Botão: *Reposicionar no canto inferior direito*
     - Seletor: *Tamanho da fonte / densidade ASCII*
     - Atalho de teclado (`Espaço` ou `F` para alimentar)

---

## 7. Plano de Implementação em Etapas (Checklist para Desenvolvimento)

- **Etapa 1 — Setup Windows & Janela:**
  - Configurar projeto Flutter Windows com `window_manager`.
  - Implementar abertura no canto inferior direito, `alwaysOnTop = false` por padrão, arraste de janela e persistência de posição/estado.
- **Etapa 2 — Motor de Simulação & Renderer ASCII:**
  - Implementar `AquariumEngine` com `dt` contínuo (peixe com nado orgânico, curvas suaves, inversão de direção, bolhas e plantas senoidais).
  - Implementar `AquariumPainter` com fonte monoespaçada embarcada e `Ticker`.
- **Etapa 3 — Interação & Alimentação:**
  - Adicionar sistema de partículas de comida, IA de busca (`seekingFood`), consumo e limpeza de fundo.
  - Criar `HudOverlay` com auto-hide no hover e atalhos de teclado.
- **Etapa 4 — Progressão, Loja & Save:**
  - Implementar `ProgressionService` (XP, níveis, evolução do sprite do peixe, moedas e conquistas).
  - Criar menu de Loja (temas/paletas, decorações ASCII, rações) e Opções.
  - Implementar `SaveRepository` com auto-save periódico e cálculo justo de tempo offline.
- **Etapa 5 — Polimento & Build Release:**
  - Ajustar performance para consumo mínimo de CPU/GPU em background.
  - Testar `flutter build windows --release` e validar comportamento com múltiplas janelas abertas.