# CV Hotfix — Layout params Promise v0.14e — 2025-12-27 21:03

## Por que quebrou
- Next 16 tipou params do layout como Promise<{ slug: string }>.
- Nosso layout estava tipado como { slug: string }, então o typecheck falhou.

## O que mudou
- layout.tsx agora recebe params como Promise e faz await params para obter slug.
- Mantido mood vindo do meta via getCaderno(slug).
