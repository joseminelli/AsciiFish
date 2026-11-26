# Assets do instalador

| Arquivo | Origem |
|---|---|
| `whiskline.png` | logo da Whiskline Studio (branca/verde, para fundos escuros) — **fornecida** |
| `app_icon.ico` / `app_icon.png` | ícone do app — gerado por `tools/gen_identity.py` |
| `wizard-large.bmp` (164×314), `wizard-small.bmp` (55×55) | imagens do assistente do Inno Setup — geradas |

Para regenerar tudo: `python tools/gen_identity.py` (requer Pillow).
