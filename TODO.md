# TODO — ASCII Fish Pet

> Feito e distribuído pela **Whiskline Studio**.

## 0. Identidade visual
- [x] **Ícone/logo do app** — peixe ASCII (`<o))))><`), legível em 16×16 até 256×256; gerar `.ico` multi-tamanho e `.png`
- [x] Aplicar o ícone no `.exe` (`windows/runner/resources/app_icon.ico`), na bandeja (`assets/app_icon.ico`) e no instalador
- [ ] **Banners**
  - [x] Banner do README/GitHub (aquário ASCII + nome + Whiskline Studio)
  - [x] Banner lateral (164×314) e cabeçalho (55×55) do instalador
  - [x] Imagem de divulgação (`docs/promo.png`, 1920×1080, gerada por `tools/gen_identity.py`; ainda dá para trocar por uma captura real do app)
- [x] Guardar os arquivos-fonte em `installer/assets/` (e uma pasta `docs/` para o banner do README)

## 1. Instalador (Inno Setup)
Objetivo: um único `AsciiFishPet-Setup.exe`, bonito e sem atrito.

- [ ] Instalar o Inno Setup 6 (`winget install JRSoftware.InnoSetup`)
- [ ] Criar `installer/AsciiFishPet.iss` com:
  - [ ] Nome: **ASCII Fish Pet** · Publisher: **Whiskline Studio** · versão vinda do `pubspec.yaml`
  - [ ] `WizardStyle=modern`, idioma **pt-BR** (e talvez inglês como segundo idioma)
  - [ ] Instalação por usuário (sem pedir administrador), pasta `%LOCALAPPDATA%\Programs\ASCII Fish Pet`
  - [ ] **"Iniciar com o Windows" — marcado por padrão**, com opção de desmarcar
  - [ ] Opções: atalho na área de trabalho, abrir ao terminar
  - [ ] Fechar o app automaticamente se estiver rodando (ele vive na bandeja) ao instalar/atualizar/desinstalar
  - [ ] Atualizar por cima sem perder o save (`%APPDATA%\com.asciifish\ascii_fish_pet\`)
  - [ ] Desinstalador pergunta se quer apagar também o progresso salvo
  - [ ] Info do arquivo (nome, versão, autor) e texto curto sobre o aviso do SmartScreen
- [ ] Visual do instalador
  - [ ] Logo da Whiskline Studio (ver `installer/assets/README.md`)
  - [x] Banner lateral (164×314) e cabeçalho (55×55) com aquário ASCII na paleta do app
  - [ ] Ícone do peixe (`.ico` multi-tamanho) — hoje o app usa o ícone padrão do Flutter
  - [ ] Trocar também o ícone do `.exe` (`windows/runner/resources/app_icon.ico`) e da bandeja (`assets/app_icon.ico`)
- [ ] "Iniciar com o Windows": definir se vem do instalador (atalho em `shell:startup`) e/ou de uma opção em Opções
- [ ] Gerar o `Setup.exe`, instalar/desinstalar numa conta de teste e tirar screenshots de cada tela
- [ ] (Opcional) Certificado de assinatura de código para acabar com o SmartScreen

## 2. Otimização (CPU hoje ≈ 3%)
Meta: bem abaixo de 1% parado, mantendo 60 FPS enquanto visível.

- [ ] Medir primeiro (DevTools / Performance / Task Manager) e separar: raster vs. UI vs. polling
- [ ] Desenho dos bichos: hoje cada caractere é desenhado separado (onda). Cachear o sprite como `ui.Picture`/`Paragraph` por frame de cauda, ou reduzir chamadas por frame
- [ ] `particles.where(...)` em `dirtCount`/`foodCount` aloca listas todo frame → manter contadores
- [ ] Polling do cursor/clique/Ctrl a cada 50 ms (FFI + channel) → intervalo adaptativo (mais lento quando o mouse está parado/fora da janela)
- [ ] `notifyListeners` a 2 Hz reconstrói dock/menu → reconstruir só o que mudou (ValueNotifier por status)
- [ ] Superfície da água: `Path` com ~320 segmentos por frame → menos pontos / cachear
- [ ] Quando o aquário está totalmente coberto por outro app (fullscreen/jogo), pausar ou reduzir a animação
- [ ] Pausar a simulação quando a janela está escondida na bandeja (hoje só reduz)
- [ ] Revisar `GlyphCache` (limite 800 entradas) e o cache de cores do arco-íris

## 3. Aparência: Status e Loja
- [ ] **Status**: layout em cartões, peixe grande com a cor equipada, barras ASCII de Fome/Humor/Limpeza/XP, estágio + próximo estágio, estatísticas em grade, conquistas com ícone e progresso
- [ ] **Loja**: itens em cartões/grade, pré-visualização (tema, cor do peixe, bicho animado), preço e requisito de nível bem visíveis, estado "comprado/em uso", abas por categoria em vez de lista única
- [ ] Menu geral: tabs mais bonitas, espaçamento, rolagem, animação de abrir/fechar
- [ ] Revisar contraste nos 5 temas (principalmente Paper Light)

## 4. Pendências e ideias
- [ ] Dar uso ao **humor** (hoje só entra no XP passivo): bolhas, mais pulos, cor/brilho do peixe
- [ ] Balanceamento: taxas de fome/limpeza, preços, ganho de pérolas (hoje são palpites)
- [ ] Alimentar: avaliar arrastar-e-soltar do botão e alimentador automático (item de loja)
- [ ] Mover o projeto para **fora do OneDrive** (ex.: `C:\dev\AsciiFish`): ele apaga `windows/flutter/ephemeral/` e quebra o build
- [ ] Migrar da camada `legacy` de `window_manager` / `screen_retriever` / `tray_manager` para a API nativa
- [ ] Fonte monoespaçada embarcada (JetBrains Mono) no lugar de Consolas
- [x] Inicializar repositório git + primeiro commit
