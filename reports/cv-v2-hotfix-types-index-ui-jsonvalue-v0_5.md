# CV V2 Hotfix — types/index/ui/jsonvalue v0.5 — 2025-12-28 13:38

## Raiz do problema
- MetaV2 tinha index signature [k: string]: JsonValue; e propriedades opcionais viram T | undefined.
- ui.default opcional também vira UiDefault | undefined e isso não encaixa em JsonValue (JSON não tem undefined).

## Fix
- Index signature agora aceita JsonValue | undefined.
- ui.default agora é obrigatório (default: UiDefault).
- JsonValue garante suporte a objeto/array (JSON real).

## Arquivo
- src/lib/v2/types.ts