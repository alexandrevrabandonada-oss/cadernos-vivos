# CV HOTFIX B7I3 — Fix runner do B7I + rerun

- Stamp: 20260109-171621
- Root: C:\Projetos\Cadernos Vivos\cadernos-vivos

## DIAG

- npm resolved: C:\Program Files\nodejs\npm.cmd
- b7i script: tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1

## PATCH

- RunNpm patch: no RunNpm() found
[OK] patched: tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1
- backup: tools\_patch_backup\20260109-171621\cv-step-b7i-portals-curated-everywhere-v0_1.ps1.20260109-171621.bak

## RUN (B7I)

[RUN] C:\Program Files\PowerShell\7\pwsh.exe -NoProfile -ExecutionPolicy Bypass -File tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1
[RUN] C:\Program Files\nodejs\npm.ps1 
Unknown command: "cmd"

To see a list of supported npm commands, run:
  npm help
Exception: C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1:120
Line |
 120 |  . DE -ne 0) { throw ("Command failed: " + $cmd + " " + ($args -join " " .
     |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Command failed: C:\Program Files\nodejs\npm.ps1

## VERIFY (lint/build)

[RUN] npm run lint

> cadernos-vivos@0.1.0 lint
> eslint --ignore-pattern tools/_patch_backup/**

[RUN] npm run build

> cadernos-vivos@0.1.0 build
> next build

Ôû▓ Next.js 16.1.1 (Turbopack)

  Creating an optimized production build ...
Ô£ô Compiled successfully in 2.6s
  Running TypeScript ...
  Collecting page data using 11 workers ...
  Generating static pages using 11 workers (0/5) ...
  Generating static pages using 11 workers (1/5) 
  Generating static pages using 11 workers (2/5) 
  Generating static pages using 11 workers (3/5) 
Ô£ô Generating static pages using 11 workers (5/5) in 183.4ms
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

[OK] lint/build ok