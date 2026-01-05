# CV — Tijolo Infra v0_19c — Bootstrap + Guards + Verify

## O que mudou
- tools/_bootstrap.ps1: RunCmd robusto (sem param $args), ResolveExe, GetNpmCmd, WriteReport.
- tools/cv-guard-v2.ps1: trava se aparecer:
  - href={/c//...} (regex/divisão em TSX)
  - import com backslash em module specifier (ex: "@/components/v2\V2Nav")
- tools/cv-verify.ps1: roda Guard → npm run lint → npm run build.

## Como usar
- pwsh -NoProfile -ExecutionPolicy Bypass -File tools/cv-verify.ps1
