# Tijolo B7C — CoreNodes como fonte única — 20260108-224331

Repo: C:\Projetos\Cadernos Vivos\cadernos-vivos

## Git status (pre)  On branch master
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	reports/20260108-222746-cv-step-b7b-core-nodes-diag.md
	reports/20260108-223304-cv-step-b7b-core-nodes-diag-v0_2.md
	tools/cv-step-b7b-core-nodes-diag-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_2.ps1
	tools/cv-step-b7c-core-nodes-single-source-v0_1.ps1

nothing added to commit but untracked files present (use "git add" to track) 

## Patch: types.ts
- OK: MetaV2.coreNodes + CoreNodesV2/CoreNodeV2

## Patch: normalize.ts
- OK: normalizeMetaV2 inclui meta.coreNodes (max 9) + helper normalizeCoreNodesV2

## Patch: Cv2CoreNodes.tsx
- OK: Cv2CoreNodes agora renderiza props.coreNodes (MetaV2) e vira bloco padrão do núcleo

## Patch: V2 pages
- OK: Cv2CoreNodes aparece antes do V2Portals em todas as portas; Hub recebe coreNodes explicitamente

## Patch: globals.css
- OK: estilos cv2-core + cv2-pill

## cv-verify.ps1 (se existir)  [OK] Guard V2 passou.
[RUN] C:\Program Files\nodejs\npm.cmd run lint

> cadernos-vivos@0.1.0 lint
> eslint


C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\debate\page.tsx
  10:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  18:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  27:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\linha-do-tempo\page.tsx
  11:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  16:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  24:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  39:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\linha\page.tsx
  10:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  18:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  27:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\mapa\page.tsx
  11:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  20:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  55:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\provas\page.tsx
  13:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  27:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  35:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\trilhas\[id]\page.tsx
   15:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
   20:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
   28:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
   62:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
   91:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  106:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  117:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  129:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  166:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  239:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\trilhas\page.tsx
  10:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  18:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  28:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\Cv2CoreNodes.tsx
  28:22  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\lib\v2\normalize.ts
  33:22  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any
  59:48  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any
  59:75  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any

Ô£û 33 problems (4 errors, 29 warnings)

Exception: C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_bootstrap.ps1:41
Line |
  41 |  . DE -ne 0) { throw ('[STOP] falhou (exit ' + $LASTEXITCODE + '): ' + $ .
     |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | [STOP] falhou (exit 1): C:\Program Files\nodejs\npm.cmd run lint 
## npm run lint  
> cadernos-vivos@0.1.0 lint
> eslint


C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\debate\page.tsx
  10:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  18:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  27:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\linha-do-tempo\page.tsx
  11:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  16:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  24:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  39:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\linha\page.tsx
  10:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  18:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  27:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\mapa\page.tsx
  11:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  20:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  55:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\provas\page.tsx
  13:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  27:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  35:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\trilhas\[id]\page.tsx
   15:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
   20:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
   28:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
   62:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
   91:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  106:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  117:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  129:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  166:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  239:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\trilhas\page.tsx
  10:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  18:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars
  28:8  warning  'Cv2CoreNodes' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\Cv2CoreNodes.tsx
  28:22  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\lib\v2\normalize.ts
  33:22  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any
  59:48  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any
  59:75  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any

Ô£û 33 problems (4 errors, 29 warnings) 
## npm run build  
> cadernos-vivos@0.1.0 build
> next build

Ôû▓ Next.js 16.1.1 (Turbopack)

  Creating an optimized production build ...

> Build error occurred
Error: Turbopack build failed with 7 errors:
./src/app/c/[slug]/v2/debate/page.tsx:18:1
Parsing ecmascript source code failed
  16 |
  17 | async function getSlug(params: AnyParams): Promise<string> {
> 18 | import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
     | ^^^^^^
  19 |
  20 |   const p = await Promise.resolve(params as unknown as { slug: string });
  21 |   return p && typeof p.slug === "string" ? p.slug : "";

'import', and 'export' cannot be used outside of module code


./src/app/c/[slug]/v2/linha-do-tempo/page.tsx:16:1
Parsing ecmascript source code failed
  14 | async function getSlug(params: Promise<{ slug: string }>): Promise<string> {
  15 |   try {
> 16 | import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
     | ^^^^^^
  17 |
  18 |     const p = await params;
  19 | import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";

'import', and 'export' cannot be used outside of module code


./src/app/c/[slug]/v2/linha/page.tsx:18:1
Parsing ecmascript source code failed
  16 |
  17 | async function getSlug(params: AnyParams): Promise<string> {
> 18 | import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
     | ^^^^^^
  19 |
  20 |   const p = await Promise.resolve(params as unknown as { slug: string });
  21 |   return p && typeof p.slug === "string" ? p.slug : "";

'import', and 'export' cannot be used outside of module code


./src/app/c/[slug]/v2/mapa/page.tsx:20:1
Parsing ecmascript source code failed
  18 |
  19 | export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
> 20 | import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
     | ^^^^^^
  21 |
  22 |   const { slug } = await params;
  23 | import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";

'import', and 'export' cannot be used outside of module code


./src/app/c/[slug]/v2/provas/page.tsx:27:1
Parsing ecmascript source code failed
  25 |
  26 | async function getSlug(params: AnyParams): Promise<string> {
> 27 | import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
     | ^^^^^^
  28 |
  29 |   const p = await Promise.resolve(params as unknown as { slug: string });
  30 |   return (p && p.slug) ? p.slug : "";

'import', and 'export' cannot be used outside of module code


./src/app/c/[slug]/v2/trilhas/[id]/page.tsx:20:1
Parsing ecmascript source code failed
  18 | async function getSlug(params: Promise<{ slug: string; id: string }>): Promise<string> {
  19 |   try {
> 20 | import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
     | ^^^^^^
  21 |
  22 |     const p = await params;
  23 | import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";

'import', and 'export' cannot be used outside of module code


./src/app/c/[slug]/v2/trilhas/page.tsx:18:1
Parsing ecmascript source code failed
  16 |
  17 | async function getSlug(params: unknown): Promise<string> {
> 18 | import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
     | ^^^^^^
  19 |
  20 |   const p = (await Promise.resolve(params)) as Partial<SlugParams>;
  21 |   return typeof p?.slug === "string" ? p.slug : "";

'import', and 'export' cannot be used outside of module code


    at <unknown> (./src/app/c/[slug]/v2/debate/page.tsx:18:1)
    at <unknown> (./src/app/c/[slug]/v2/linha-do-tempo/page.tsx:16:1)
    at <unknown> (./src/app/c/[slug]/v2/linha/page.tsx:18:1)
    at <unknown> (./src/app/c/[slug]/v2/mapa/page.tsx:20:1)
    at <unknown> (./src/app/c/[slug]/v2/provas/page.tsx:27:1)
    at <unknown> (./src/app/c/[slug]/v2/trilhas/[id]/page.tsx:20:1)
    at <unknown> (./src/app/c/[slug]/v2/trilhas/page.tsx:18:1) 
## Git status (post)  On branch master
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   src/app/c/[slug]/v2/debate/page.tsx
	modified:   src/app/c/[slug]/v2/linha-do-tempo/page.tsx
	modified:   src/app/c/[slug]/v2/linha/page.tsx
	modified:   src/app/c/[slug]/v2/mapa/page.tsx
	modified:   src/app/c/[slug]/v2/page.tsx
	modified:   src/app/c/[slug]/v2/provas/page.tsx
	modified:   src/app/c/[slug]/v2/trilhas/[id]/page.tsx
	modified:   src/app/c/[slug]/v2/trilhas/page.tsx
	modified:   src/components/v2/Cv2CoreNodes.tsx
	modified:   src/lib/v2/normalize.ts
	modified:   src/lib/v2/types.ts

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	reports/20260108-222746-cv-step-b7b-core-nodes-diag.md
	reports/20260108-223304-cv-step-b7b-core-nodes-diag-v0_2.md
	tools/cv-step-b7b-core-nodes-diag-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_2.ps1
	tools/cv-step-b7c-core-nodes-single-source-v0_1.ps1

no changes added to commit (use "git add" and/or "git commit -a") 
