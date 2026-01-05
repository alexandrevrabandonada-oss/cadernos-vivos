# CV — Hotfix v0_36 — V2Nav unique keys

## Causa
- Warning do React: keys duplicadas (provável repetição de it.key em itens do menu).

## Fix
- Troca key do map para usar href (tende a ser único): key={it.href}.

## Arquivo
- src/components/v2/V2Nav.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
