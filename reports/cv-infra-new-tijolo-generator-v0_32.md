# CV — Infra v0_32 — Gerador de Tijolos

## O que foi adicionado
- tools/cv-new-tijolo.ps1: cria um novo tijolo com template padrão DIAG→PATCH→VERIFY→REPORT.

## Como usar
Exemplo:
- pwsh -NoProfile -ExecutionPolicy Bypass -File tools/cv-new-tijolo.ps1 -Name "cvhub-v2-tijolo-x" -Title "CV — V2 Tijolo X" -Version "v0_1"

## Verify
- tools/cv-verify.ps1
