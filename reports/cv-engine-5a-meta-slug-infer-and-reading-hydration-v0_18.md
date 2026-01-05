# CV Engine-5A — Meta slug fallback + ReadingControls hydration-safe — 2025-12-27 22:10

## O que mudou
- ReadingControls: estado inicial fixo (server/client) + carrega preferências só após mount.
- cadernos.ts: se meta.json não tiver slug, inferimos pelo folder/rota (slug) antes do Zod parse.

## Por quê
- Evita ZodError ao abrir cadernos recém-criados sem slug no meta.
- Remove warnings de hydration causados por preferências lidas cedo demais.

## Próximo
- Padronizar spec do meta.json (mood/accent) e usar isso pra 'cada página ser um universo'.