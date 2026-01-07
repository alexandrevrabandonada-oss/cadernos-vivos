# CV — Step B5c: V2 card component + unify cards

- when: 20260106-125008
- repo: C:\Projetos\Cadernos Vivos\cadernos-vivos

## ACTIONS
- globals.css: added CV2 interactive card microinteraction + title/desc styles.
- Created src/components/v2/Cv2Card.tsx.
- No changes needed: src\components\v2\HomeV2Hub.tsx
- No changes needed: src\components\v2\ProvasV2.tsx
- No changes needed: src\components\v2\TrilhasV2.tsx

## BACKUPS
- 20260106-125008-globals.css.bak

## VERIFY
- exit: 0

--- VERIFY OUTPUT START ---
[OK] Guard V2 passou.
[RUN] C:\Program Files\nodejs\npm.cmd run lint

> cadernos-vivos@0.1.0 lint
> eslint

[RUN] C:\Program Files\nodejs\npm.cmd run build

> cadernos-vivos@0.1.0 build
> next build

Ôû▓ Next.js 16.1.1 (Turbopack)

  Creating an optimized production build ...
Ô£ô Compiled successfully in 2.2s
  Running TypeScript ...
  Collecting page data using 11 workers ...
  Generating static pages using 11 workers (0/5) ...
  Generating static pages using 11 workers (1/5) 
  Generating static pages using 11 workers (2/5) 
  Generating static pages using 11 workers (3/5) 
Ô£ô Generating static pages using 11 workers (5/5) in 154.3ms
  Finalizing page optimization ...

Route (app)
Ôöî Ôùï /
Ôö£ Ôùï /_not-found
Ôö£ Ôùï /c
Ôö£ ãÆ /c/[slug]
Ôö£ ãÆ /c/[slug]/a/[aula]
Ôö£ ãÆ /c/[slug]/acervo
Ôö£ ãÆ /c/[slug]/debate
Ôö£ ãÆ /c/[slug]/mapa
Ôö£ ãÆ /c/[slug]/pratica
Ôö£ ãÆ /c/[slug]/quiz
Ôö£ ãÆ /c/[slug]/registro
Ôö£ ãÆ /c/[slug]/status
Ôö£ ãÆ /c/[slug]/trilha
Ôö£ ãÆ /c/[slug]/v2
Ôö£ ãÆ /c/[slug]/v2/debate
Ôö£ ãÆ /c/[slug]/v2/linha
Ôö£ ãÆ /c/[slug]/v2/linha-do-tempo
Ôö£ ãÆ /c/[slug]/v2/mapa
Ôö£ ãÆ /c/[slug]/v2/provas
Ôö£ ãÆ /c/[slug]/v2/trilhas
Ôöö ãÆ /c/[slug]/v2/trilhas/[id]


Ôùï  (Static)   prerendered as static content
ãÆ  (Dynamic)  server-rendered on demand

[OK] verify OK (guard+lint+build).

--- VERIFY OUTPUT END ---

## NEXT
- B5d: Hub como mapa mental (nos + conectores) usando os mesmos cards.
- B5e: teclado de verdade (setas/enter) no Hub e melhorias de aria-label onde faltar.