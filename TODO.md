# TODO — ASCII Fish Pet

> Feito e distribuído pela **Whiskline Studio**.

## 0. Identidade visual
- [x] **Ícone/logo do app** — peixe ASCII (`<o))))><`), legível em 16×16 até 256×256; gerar `.ico` multi-tamanho e `.png`
- [x] Aplicar o ícone no `.exe` (`windows/runner/resources/app_icon.ico`), na bandeja (`assets/app_icon.ico`) e no instalador
- [x] **Banners**
  - [x] Banner do README/GitHub (aquário ASCII + nome + Whiskline Studio)
  - [x] Banner lateral (164×314) e cabeçalho (55×55) do instalador
  - [x] Imagem de divulgação (`docs/promo.png`, 1920×1080, gerada por `tools/gen_identity.py`; ainda dá para trocar por uma captura real do app)
- [x] Guardar os arquivos-fonte em `installer/assets/` (e uma pasta `docs/` para o banner do README)

## 1. Instalador (Inno Setup)
Objetivo: um único `AsciiFishPet-Setup.exe`, bonito e sem atrito.

- [x] Instalar o Inno Setup 6 (`winget install JRSoftware.InnoSetup`)
- [x] Criar `installer/AsciiFishPet.iss` com:
  - [x] Nome: **ASCII Fish Pet** · Publisher: **Whiskline Studio** · versão vinda do `pubspec.yaml`
  - [x] `WizardStyle=modern`, idioma **pt-BR** (e talvez inglês como segundo idioma)
  - [x] Instalação por usuário (sem pedir administrador), pasta `%LOCALAPPDATA%\Programs\ASCII Fish Pet`
  - [x] **"Iniciar com o Windows" — marcado por padrão**, com opção de desmarcar
  - [x] Opções: atalho na área de trabalho, abrir ao terminar
  - [x] Fechar o app automaticamente se estiver rodando (ele vive na bandeja) ao instalar/atualizar/desinstalar
  - [x] Atualizar por cima sem perder o save (`%APPDATA%\com.asciifish\ascii_fish_pet\`)
  - [x] Desinstalador pergunta se quer apagar também o progresso salvo
  - [x] Info do arquivo (nome, versão, autor) e texto curto sobre o aviso do SmartScreen
- [x] Visual do instalador
  - [x] Logo da Whiskline Studio (ver `installer/assets/README.md`)
  - [x] Banner lateral (164×314) e cabeçalho (55×55) com aquário ASCII na paleta do app
  - [x] Ícone do peixe (`.ico` multi-tamanho) — hoje o app usa o ícone padrão do Flutter
  - [x] Trocar também o ícone do `.exe` (`windows/runner/resources/app_icon.ico`) e da bandeja (`assets/app_icon.ico`)
- [x] "Iniciar com o Windows" vem do instalador (chave `HKCU\...\Run`). Também há o interruptor em Opções (mesma chave do instalador; desativado em build de desenvolvimento)
- [x] Gerar o `Setup.exe` (`scripts/release.ps1`) e testar instalar/desinstalar em modo silencioso
- [x] Revisar visualmente cada tela do assistente (screenshots) — falta testar a interface, só rodei em modo silencioso
- [x] Assinatura de código: **decidido não assinar** (sem custo). SignPath Foundation exige licença OSI; o projeto usa PolyForm Noncommercial (`LICENSE`). Aviso do SmartScreen documentado no README/Releases; reputação melhora com o tempo. Reavaliar se um dia houver orçamento (Azure Artifact Signing / certificado OV) ou se a licença mudar

## 2. Otimização (CPU hoje ≈ 3%)
Meta: bem abaixo de 1% parado, mantendo 60 FPS enquanto visível.

- [x] Medir primeiro e separar. **Achados (build release, 12 núcleos):**
  - Sem o `Ticker` de 60 FPS o app fica em ~0,03%; com ele, 2,4–3,2% **mesmo com simulação e repintura desligadas**. Simular + desenhar custa só ~0,5–0,8%; o resto é custo fixo por frame (vsync + janela transparente larga). O polling do mouse quase não pesa (desligado: sem mudança).
  - O consumo **depende de a janela estar visível**: com outro app cobrindo a faixa mede ~1%; visível, 3–4,5%. Todo teste precisa ser feito com o aquário visível (ex.: Win+D).
  - **Causa real (medida em release, aquário visível):** o custo é por quadro apresentado (~0,45% de um núcleo por FPS), quase independente do que se desenha. O `Ticker` rodava na taxa do monitor (144 Hz aqui = ~144 FPS, ~43% de um núcleo). Sem ticker o app fica em ~0,9%.
  - **Feito:** sem `Ticker`; cada quadro agenda o próximo e a opção **Quadros por segundo (60/30/20)** em Opções limita a taxa. Medido a 144 Hz: 60 → ~48 FPS reais / 23%; 30 → ~24 / 9%; 20 → ~19 / 5% (de um núcleo).
  - Para chegar bem abaixo de 1% parado: pausar quando coberto (item abaixo) e/ou default de 30 FPS.
  - Alterações já feitas (sem ganho mensurável, mas inofensivas): cache da areia e do degradê da água, `alpha` das cáusticas em degraus (cache de glifos)
- [ ] Desenho dos bichos (parcial: sem alocar lista de runes por frame): hoje cada caractere é desenhado separado (onda). Cachear o sprite como `ui.Picture`/`Paragraph` por frame de cauda, ou reduzir chamadas por frame
- [x] `particles.where(...)` em `dirtCount`/`foodCount` aloca listas todo frame → contagem sem alocar
- [ ] Polling do cursor/clique/Ctrl a cada 50 ms (FFI + channel) → intervalo adaptativo (mais lento quando o mouse está parado/fora da janela)
- [ ] `notifyListeners` a 2 Hz reconstrói dock/menu → reconstruir só o que mudou (ValueNotifier por status)
- [x] Superfície da água: `Paint` reutilizado (passo de 6 px mantido para não alterar o visual)
- [ ] Quando o aquário está totalmente coberto por outro app (fullscreen/jogo), pausar ou reduzir a animação
- [x] Escondida na bandeja: lógica a 4 Hz e sem repintura
- [ ] Revisar `GlyphCache` (limite 800 entradas) e o cache de cores do arco-íris

## 3. Aparência: Status e Loja
- [x] **Status**: layout em cartões, peixe grande com a cor equipada, barras ASCII de Fome/Humor/Limpeza/XP, estágio + próximo estágio, estatísticas em grade, conquistas com ícone e progresso
- [x] **Loja**: itens em cartões/grade, pré-visualização (tema, cor do peixe, bicho animado), preço e requisito de nível bem visíveis, estado "comprado/em uso", abas por categoria em vez de lista única
- [x] Menu geral: tabs mais bonitas, espaçamento, rolagem, animação de abrir/fechar
- [x] Revisar contraste nos 5 temas (Paper Light ajustado: peixe, pérolas e alerta)

## 4. Pendências e ideias
- [x] Dar uso ao **humor**: mais bolhas, corações (o pulo não depende do humor), nada mais devagar quando triste (falta cor/brilho do peixe)
- [ ] Balanceamento: taxas de fome/limpeza, preços, ganho de pérolas (hoje são palpites)
- [ ] Alimentar: avaliar arrastar-e-soltar do botão e alimentador automático (item de loja)
- [x] Mover o projeto para **fora do OneDrive** (ex.: `C:\dev\AsciiFish`): ele apaga `windows/flutter/ephemeral/` e quebra o build
- [ ] Migrar da camada `legacy` de `window_manager` / `screen_retriever` / `tray_manager` para a API nativa
- [ ] Fonte monoespaçada embarcada (JetBrains Mono) no lugar de Consolas
- [x] Inicializar repositório git + primeiro commit

## 5. Atualizações automáticas (feito)
- [x] App procura a última Release do GitHub (Opções → Procurar, e 1x/dia ao abrir), baixa o `Setup.exe` e atualiza por cima, reabrindo o app; o save não é tocado
- [x] `.\publish` gera o instalador e cria a Release (`vX.Y.Z`) com o `Setup.exe`
- [ ] Publicar a primeira Release (1.1.0) e testar a atualização de ponta a ponta com uma 1.1.1
