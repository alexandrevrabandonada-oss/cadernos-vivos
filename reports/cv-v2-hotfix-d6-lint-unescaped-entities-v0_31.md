# CV — Hotfix v0_31 — D6 lint fix (unescaped quotes + eslint-disable unused)

## Fixes
- page.tsx (Trilhas V2): trocou 	ype: "trail" por 	ype: &quot;trail&quot; para passar eact/no-unescaped-entities.
- trilhas.ts: removeu /* eslint-disable ... */ não utilizado (warning).

## Verify
- tools/cv-verify.ps1 (Guard → Lint → Build)
