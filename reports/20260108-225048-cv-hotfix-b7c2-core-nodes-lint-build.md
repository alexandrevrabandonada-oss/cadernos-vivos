# Hotfix B7C2 — CoreNodes (imports + no-any) — 20260108-225048

Repo: C:\Projetos\Cadernos Vivos\cadernos-vivos

## Git status (pre)  On branch master
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
	reports/20260108-224331-cv-step-b7c-core-nodes-single-source.md
	tools/cv-hotfix-b7c2-core-nodes-lint-build-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_2.ps1
	tools/cv-step-b7c-core-nodes-single-source-v0_1.ps1

no changes added to commit (use "git add" and/or "git commit -a") 

## Patch A
- Cv2CoreNodes.tsx reescrito sem any

## Patch B
- normalize.ts: helper coreNodes sem any + extractCoreNodesRaw

## Patch C
- Pages V2: imports Cv2CoreNodes limpos + uso garantido antes do V2Portals

## cv-verify.ps1  [OK] Guard V2 passou.
[RUN] C:\Program Files\nodejs\npm.cmd run lint

> cadernos-vivos@0.1.0 lint
> eslint


C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_patch_backup\20260108-225048-Cv2CoreNodes.tsx
  28:22  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any

C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_patch_backup\20260108-225048-normalize.ts
  33:22  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any
  59:48  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any
  59:75  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any

C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_patch_backup\20260108-225048-page.tsx
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

Ô£û 14 problems (4 errors, 10 warnings)

Exception: C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_bootstrap.ps1:41
Line |
  41 |  . DE -ne 0) { throw ('[STOP] falhou (exit ' + $LASTEXITCODE + '): ' + $ .
     |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | [STOP] falhou (exit 1): C:\Program Files\nodejs\npm.cmd run lint 
## npm run lint  
> cadernos-vivos@0.1.0 lint
> eslint


C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_patch_backup\20260108-225048-Cv2CoreNodes.tsx
  28:22  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any

C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_patch_backup\20260108-225048-normalize.ts
  33:22  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any
  59:48  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any
  59:75  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any

C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_patch_backup\20260108-225048-page.tsx
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

Ô£û 14 problems (4 errors, 10 warnings) 
## npm run build  
> cadernos-vivos@0.1.0 build
> next build

Ôû▓ Next.js 16.1.1 (Turbopack)

  Creating an optimized production build ...
Ô£ô Compiled successfully in 2.6s
  Running TypeScript ...
Failed to compile.

./src/app/c/[slug]/v2/debate/page.tsx:43:46
Type error: Cannot find name 'meta'.

  41 |           <DebateV2 slug={slug} title={title} />
  42 |         </div>
> 43 |         <Cv2CoreNodes slug={slug} coreNodes={meta.coreNodes} />
     |                                              ^
  44 |
  45 |         <V2Portals slug={slug} active="debate" />
  46 |       </main>
Next.js build worker exited with code: 1 and signal: null 
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
	reports/20260108-224331-cv-step-b7c-core-nodes-single-source.md
	tools/cv-hotfix-b7c2-core-nodes-lint-build-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_2.ps1
	tools/cv-step-b7c-core-nodes-single-source-v0_1.ps1

no changes added to commit (use "git add" and/or "git commit -a") 
