# CV — Polish — clean warnings + redirect uiDefault v2 (v0_80)

## O que foi ajustado
- /c/[slug]: se uiDefault === "v2", redireciona para /c/<slug>/v2 (usa redirect e uiDefault, limpando warnings).
- /c/[slug]: remove import Link se não houver <Link>.
- /v2/linha: remove import JsonValue quando estiver sobrando.
- /v2/trilhas/[id]: renomeia title para _title se estiver sobrando (best-effort).

## Arquivos alterados

## Verify
- tools/cv-verify.ps1 (guard + lint + build)