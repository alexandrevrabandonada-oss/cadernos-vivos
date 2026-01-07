# CV — B6f: Stabilize Provas V2 grouped panel

- when: 20260106-192002
- component: src\components\v2\Cv2ProvasGroupedClient.tsx
- page: src\app\c\[slug]\v2\provas\page.tsx
- css: src\app\globals.css

## O que muda
- Reescreve Cv2ProvasGroupedClient.tsx (parser-safe) com named + default export.
- Garante import + uso do componente na page.tsx (sem 'importado e não usado').
- Garante wrapper data-cv2-provas-list="1" ao redor do ProvasV2.
- Adiciona CSS mínimo para details/summary (aditivo).

## VERIFY
- tools/cv-verify.ps1