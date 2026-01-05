# CV — Hotfix v0_38 — MapaDockV2: onHash restore

## Causa
- Script anterior removeu a definição de onHash, mas manteve addEventListener(..., onHash), quebrando build.

## Fix
- Reinseriu: const onHash = () => setSelectedId(readHashId()); antes do addEventListener('hashchange', onHash).

## Verify
- tools/cv-verify.ps1 (Guard → Lint → Build)
