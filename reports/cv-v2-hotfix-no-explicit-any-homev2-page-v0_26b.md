# CV — Hotfix v0_26b — remove no-explicit-any (HomeV2 + /v2)

## Causa raiz
- PowerShell é case-insensitive: $home conflita com $HOME (read-only).
- ESLint @typescript-eslint/no-explicit-any não permite (data as any) / (pano as any).

## Fix
- Renomeou variáveis PowerShell para $homeFile e $v2PageFile.
- HomeV2: Record<string, unknown> + pano['hot'] (sem any).
- /v2 page: helpers asObj/asStr e extração segura (sem any).

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
