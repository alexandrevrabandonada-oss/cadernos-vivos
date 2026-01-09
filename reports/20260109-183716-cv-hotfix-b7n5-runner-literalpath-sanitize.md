# CV HOTFIX B7N5 — runner + literalpath + sanitize

- Stamp: 20260109-183716
- Root: C:\Projetos\Cadernos Vivos\cadernos-vivos

## DIAG

- tools\cv-step-b7n-map-core-highlights-v0_1.ps1: True
- tools\cv-step-b7n-map-core-highlights-v0_2.ps1: True
- tools\cv-hotfix-b7o3-core-highlights-sanitize-inject.ps1: True
- tools\cv-hotfix-b7o4-fix-sanitize-script-and-verify-v0_2.ps1: True
- tools\cv-hotfix-b7o4-fix-sanitize-script-and-verify-v0_3.ps1: True

## PATCH

[OK] patched: tools\cv-step-b7n-map-core-highlights-v0_1.ps1
- backup: tools\_patch_backup\20260109-183716\cv-step-b7n-map-core-highlights-v0_1.ps1.20260109-183716.bak
- notes: RunCmd: not-found; RunNpm: not-found; Test-Path: literalized

[OK] no-change: tools\cv-step-b7n-map-core-highlights-v0_2.ps1
- notes: RunCmd: not-found; RunNpm: not-found

[OK] patched: tools\cv-hotfix-b7o3-core-highlights-sanitize-inject.ps1
- backup: tools\_patch_backup\20260109-183716\cv-hotfix-b7o3-core-highlights-sanitize-inject.ps1.20260109-183716.bak
- notes: RunCmd: not-found; RunNpm: replaced; Runner: injected

[OK] patched: tools\cv-hotfix-b7o4-fix-sanitize-script-and-verify-v0_2.ps1
- backup: tools\_patch_backup\20260109-183716\cv-hotfix-b7o4-fix-sanitize-script-and-verify-v0_2.ps1.20260109-183716.bak
- notes: RunCmd: not-found; RunNpm: replaced; Runner: injected; Sanitize: Replace(char,string) fixed

[OK] patched: tools\cv-hotfix-b7o4-fix-sanitize-script-and-verify-v0_3.ps1
- backup: tools\_patch_backup\20260109-183716\cv-hotfix-b7o4-fix-sanitize-script-and-verify-v0_3.ps1.20260109-183716.bak
- notes: RunCmd: not-found; RunNpm: replaced; Runner: injected; Sanitize: Replace(char,string) fixed

## VERIFY

[RUN] npm run lint
```

> cadernos-vivos@0.1.0 lint
> eslint --ignore-pattern tools/_patch_backup/**
```

[RUN] npm run build
```

> cadernos-vivos@0.1.0 build
> next build

Ôû▓ Next.js 16.1.1 (Turbopack)

  Creating an optimized production build ...
Ô£ô Compiled successfully in 2.4s
  Running TypeScript ...
  Collecting page data using 11 workers ...
  Generating static pages using 11 workers (0/5) ...
  Generating static pages using 11 workers (1/5) 
  Generating static pages using 11 workers (2/5) 
  Generating static pages using 11 workers (3/5) 
Ô£ô Generating static pages using 11 workers (5/5) in 160.7ms
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
```

[OK] lint/build ok