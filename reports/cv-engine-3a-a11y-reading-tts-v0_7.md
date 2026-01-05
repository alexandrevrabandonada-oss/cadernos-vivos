# CV-Engine-3A — A11y + Modo Leitura + TTS — 2025-12-27 18:07

## O que entrou
- Skip link no layout (pular para #cv-main).
- main das paginas ganhou id=cv-main + tabIndex=-1 + classe cv-reading.
- Novo componente ReadingControls (modo leitura, alto contraste, ouvir/parar).
- Padronizacao de linguagem: Registro (nao Recibo).

## Verificar manual
- Tab: o link de pular aparece e leva ao conteudo.
- Modo leitura altera tipografia/ritmo (se globals.css existir).
- Ouvir/Parar funciona em navegadores com Web Speech API.