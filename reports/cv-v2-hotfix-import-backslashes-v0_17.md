# CV — Hotfix v0_17 — Corrige imports com backslash (escape JS)

## Causa raiz
- Em TS/JS, '\\' em string literal é escape. '@/components/v2\\V2Nav' vira '@/components/v2V2Nav', quebrando o alias do Next.

## Fix
- Substitui '@/components/v2\\' → '@/components/v2/' (e variantes).
- Substitui '@/lib/v2\\' → '@/lib/v2/' (e variantes).
- Guard final: falha se sobrar qualquer '@/...\\' em ts/tsx.

## Verify
- npm run lint
- npm run build
