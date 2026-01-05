# Hotfix — Meta.slug opcional + inferir do folder v0.18 — 2025-12-27 21:59

## Problema
- Zod falhou: meta.json sem campo slug (cadernos novos).

## Mudança
- CadernoMeta.slug agora é opcional.
- getCaderno(): após parse, força meta.slug = metaParsed.slug ?? slug.

## Resultado esperado
- /c/meu-novo-caderno funciona mesmo se meta.json não tiver slug.