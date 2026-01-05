# CV — Hotfix v0_35 — Next 16.1 async params/searchParams (V2)

## Causa
- Em Next.js 16.1+ no dev, params/searchParams podem ser Promises; acessar .slug direto estoura erro.

## Fix
- Em pages async: props.params.* / params.* -> (await ...).*
- Também cobre searchParams pelo mesmo motivo.

## Arquivos alterados
- (nenhum — já estavam no padrão)

## Arquivos pulados (não-async)
- (nenhum)

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
