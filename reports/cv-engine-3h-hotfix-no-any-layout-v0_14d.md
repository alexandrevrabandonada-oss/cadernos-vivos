# CV Engine-3H Hotfix — No Any Layout v0.14d — 2025-12-27 20:37

## O que mudou
- Removeu uso de any no layout do caderno.
- getCaderno() agora é tratado como unknown com guards para extrair meta.
- pickMoodFromMeta() usa Record<string, unknown> com coerção segura.
