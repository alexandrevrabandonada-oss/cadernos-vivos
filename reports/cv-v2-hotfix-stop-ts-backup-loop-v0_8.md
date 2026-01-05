# CV — Hotfix v0_8 — parar loop de build por backups TS

## Causa raiz
- O TypeScript/Next estava type-checkando arquivos dentro de tools/_patch_backup (backups .ts antigos).
- Isso derrubava o build mesmo quando o código atual já estava correto.

## Fix aplicado
- tsconfig.json: adicionou exclude para tools/_patch_backup/** e reports/**.
- Renomeou backups .ts/.tsx existentes para .bak (não destrói, só remove do build).
- tools/_bootstrap.ps1: BackupFile agora salva .ts/.tsx como .bak no futuro.

## Verify
- npm run lint
- npm run build
