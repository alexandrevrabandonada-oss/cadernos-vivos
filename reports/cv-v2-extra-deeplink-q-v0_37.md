# CV — V2 Extra v0_37 — Deep links por query (?q=)

## O que entrou
- ProvasV2 aceita initialQuery e inicia a busca por prop (sem effect).
- /v2/provas lê ?q= (searchParams) e passa initialQuery.
- Tentativa best-effort para Debate (component/page) se já existir padrão de q.

## Como usar
- /c/SEU-SLUG/v2/provas?q=palavra
- /c/SEU-SLUG/v2/provas#id (continua funcionando)

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
