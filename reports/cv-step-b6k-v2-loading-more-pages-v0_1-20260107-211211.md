# CV — Step B6k: V2 loading.tsx (more pages) + skeleton css

- when: 20260107-211211
- repo: C:\Projetos\Cadernos Vivos\cadernos-vivos

## ACTIONS
- globals.css: ensure CV2 Skeleton block exists (scoped to .cv-v2).
- Ensure src/components/v2/Cv2Skeleton.tsx exports SkelScreen/SkelCard.
- Added canonical loading.tsx for: debate, linha, linha-do-tempo, mapa.

## VERIFY
- exit: 0

--- VERIFY OUTPUT START ---
[OK] Guard V2 passou.
[RUN] C:\Program Files\nodejs\npm.cmd run lint

> cadernos-vivos@0.1.0 lint
> eslint

[RUN] C:\Program Files\nodejs\npm.cmd run build

> cadernos-vivos@0.1.0 build
> next build

Ôû▓ Next.js 16.1.1 (Turbopack)

  Creating an optimized production build ...

> Build error occurred
Error: Turbopack build failed with 4 errors:
./src/app/c/[slug]/v2/loading.tsx:1:1
Export Cv2SkelScreen doesn't exist in target module
> 1 | import { Cv2SkelScreen } from "@/components/v2/Cv2Skeleton";
    | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  2 |
  3 | export default function Loading() {
  4 |   return (

The export Cv2SkelScreen was not found in module [project]/src/components/v2/Cv2Skeleton.tsx [app-rsc] (ecmascript).
Did you mean to import SkelScreen?
All exports of the module are statically known (It doesn't have dynamic exports). So it's known statically that the requested export doesn't exist.


./src/app/c/[slug]/v2/provas/loading.tsx:1:1
Export Cv2SkelScreen doesn't exist in target module
> 1 | import { Cv2SkelScreen } from "@/components/v2/Cv2Skeleton";
    | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  2 |
  3 | export default function Loading() {
  4 |   return (

The export Cv2SkelScreen was not found in module [project]/src/components/v2/Cv2Skeleton.tsx [app-rsc] (ecmascript).
Did you mean to import SkelScreen?
All exports of the module are statically known (It doesn't have dynamic exports). So it's known statically that the requested export doesn't exist.


./src/app/c/[slug]/v2/trilhas/[id]/loading.tsx:1:1
Export Cv2SkelScreen doesn't exist in target module
> 1 | import { Cv2SkelScreen } from "@/components/v2/Cv2Skeleton";
    | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  2 |
  3 | export default function Loading() {
  4 |   return (

The export Cv2SkelScreen was not found in module [project]/src/components/v2/Cv2Skeleton.tsx [app-rsc] (ecmascript).
Did you mean to import SkelScreen?
All exports of the module are statically known (It doesn't have dynamic exports). So it's known statically that the requested export doesn't exist.


./src/app/c/[slug]/v2/trilhas/loading.tsx:1:1
Export Cv2SkelScreen doesn't exist in target module
> 1 | import { Cv2SkelScreen } from "@/components/v2/Cv2Skeleton";
    | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  2 |
  3 | export default function Loading() {
  4 |   return (

The export Cv2SkelScreen was not found in module [project]/src/components/v2/Cv2Skeleton.tsx [app-rsc] (ecmascript).
Did you mean to import SkelScreen?
All exports of the module are statically known (It doesn't have dynamic exports). So it's known statically that the requested export doesn't exist.


    at <unknown> (./src/app/c/[slug]/v2/loading.tsx:1:1)
    at <unknown> (./src/app/c/[slug]/v2/provas/loading.tsx:1:1)
    at <unknown> (./src/app/c/[slug]/v2/trilhas/[id]/loading.tsx:1:1)
    at <unknown> (./src/app/c/[slug]/v2/trilhas/loading.tsx:1:1)
Exception: C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_bootstrap.ps1:41
Line |
  41 |  . DE -ne 0) { throw ('[STOP] falhou (exit ' + $LASTEXITCODE + '): ' + $ .
     |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | [STOP] falhou (exit 1): C:\Program Files\nodejs\npm.cmd run build
--- VERIFY OUTPUT END ---
