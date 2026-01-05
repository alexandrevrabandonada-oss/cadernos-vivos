# Hotfix — ReadingControls hydration v0.18h — 2025-12-27 22:04

## Problema
- Hydration mismatch em aria-pressed (SSR false vs client true).

## Causa
- Preferência estava sendo aplicada antes do hydrate (localStorage/window no render ou no initializer do state).

## Mudança
- ReadingControls agora inicia com defaults estáveis e carrega preferências em useEffect.
- Persistência e aplicação em dataset/CSS vars só depois do mount.

## Resultado esperado
- Sem warning de hydration ao abrir qualquer /c/[slug].