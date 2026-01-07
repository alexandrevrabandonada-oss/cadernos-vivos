# CV — Step B6d2: Fix DomFilter export + Provas import

- when: 20260106-163610
- component: src\components\v2\Cv2DomFilterClient.tsx
- page: src\app\c\[slug]\v2\provas\page.tsx

## Changes
- Remove line invalid in-module: export { default as Cv2DomFilterClient };
- Change Provas V2 import to default import (robust for TS/Next/Turbopack).

## Verify
- tools/cv-verify.ps1