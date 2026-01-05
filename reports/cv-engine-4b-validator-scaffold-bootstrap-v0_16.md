# CV Engine-4B — Validator + Scaffold + Bootstrap — 2025-12-27 21:16

## O que foi criado
- tools/_bootstrap.ps1 (funções padrão)
- tools/cv-validate-content.ps1 (valida content/cadernos)
- tools/cv-new-caderno.ps1 (cria um caderno novo completo)

## Como usar (exemplo)
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/cv-new-caderno.ps1 -Slug exemplo -Title "Exemplo de Caderno"
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/cv-validate-content.ps1 -Fix

## Próximo
- Engine-4C: gerador de checklist por caderno (o que falta preencher) + painel /c/[slug]/status
