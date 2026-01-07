# CV — B6f2: rewrite seguro do ProvasGroupedClient + injeção na page

- when: 20260106-192908
- component: src\components\v2\Cv2ProvasGroupedClient.tsx
- page: src\app\c\[slug]\v2\provas\page.tsx

## O que muda
- Reescreve Cv2ProvasGroupedClient.tsx (parser-safe) com painel por domínio + Copiar (MD).
- Injeta uso do componente em /v2/provas/page.tsx e garante wrapper data-cv2-provas-list="1".

## VERIFY
- Rodar tools/cv-verify.ps1