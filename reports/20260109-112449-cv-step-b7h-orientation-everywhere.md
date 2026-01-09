# Tijolo B7H — Orientação Everywhere (V2) — 20260109-112449

Repo: C:\Projetos\Cadernos Vivos\cadernos-vivos

## Git status (pre)  On branch master
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   package.json
	modified:   src/app/c/[slug]/v2/debate/page.tsx
	modified:   src/app/c/[slug]/v2/linha-do-tempo/page.tsx
	modified:   src/app/c/[slug]/v2/linha/page.tsx
	modified:   src/app/c/[slug]/v2/mapa/page.tsx
	modified:   src/app/c/[slug]/v2/page.tsx
	modified:   src/app/c/[slug]/v2/provas/page.tsx
	modified:   src/app/c/[slug]/v2/trilhas/[id]/page.tsx
	modified:   src/app/c/[slug]/v2/trilhas/page.tsx
	modified:   src/app/globals.css
	modified:   src/components/v2/Cv2CoreNodes.tsx
	modified:   src/components/v2/Cv2MapRail.tsx
	modified:   src/components/v2/Cv2MindmapHubClient.tsx
	modified:   src/lib/v2/normalize.ts
	modified:   src/lib/v2/types.ts

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	reports/20260108-222746-cv-step-b7b-core-nodes-diag.md
	reports/20260108-223304-cv-step-b7b-core-nodes-diag-v0_2.md
	reports/20260108-224331-cv-step-b7c-core-nodes-single-source.md
	reports/20260108-225048-cv-hotfix-b7c2-core-nodes-lint-build.md
	reports/20260108-225522-cv-hotfix-b7c3-core-nodes-expr-and-lintignore.md
	reports/20260108-230028-cv-step-b7d-mapfirst-nucleus-top.md
	reports/20260108-230459-cv-step-b7e-portals-curated-by-core.md
	reports/20260108-230736-cv-hotfix-b7e2-portals-curated-no-any.md
	reports/20260108-231311-cv-step-b7f-core-order-single-source.md
	reports/20260108-232411-cv-hotfix-b7f2-core-order-lint-warnings.md
	reports/20260108-232640-cv-hotfix-b7f3-maprail-meta-compat.md
	reports/20260108-234605-cv-step-b7g-mindmap-guided-by-core.md
	reports/20260109-111503-cv-hotfix-b7g2-mindmap-no-setstate-in-effect.md
	src/components/v2/Cv2PortalsCurated.tsx
	src/lib/v2/doors.ts
	tools/cv-hotfix-b7c2-core-nodes-lint-build-v0_1.ps1
	tools/cv-hotfix-b7c3-core-nodes-expr-and-lintignore-v0_1.ps1
	tools/cv-hotfix-b7e2-portals-curated-no-any-v0_1.ps1
	tools/cv-hotfix-b7f2-core-order-lint-warnings-v0_1.ps1
	tools/cv-hotfix-b7f3-maprail-meta-compat-v0_1.ps1
	tools/cv-hotfix-b7g2-mindmap-no-setstate-in-effect-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_2.ps1
	tools/cv-step-b7c-core-nodes-single-source-v0_1.ps1
	tools/cv-step-b7d-mapfirst-nucleus-top-v0_1.ps1
	tools/cv-step-b7e-portals-curated-by-core-v0_1.ps1
	tools/cv-step-b7f-core-order-single-source-v0_1.ps1
	tools/cv-step-b7g-mindmap-guided-by-core-v0_1.ps1
	tools/cv-step-b7g-mindmap-guided-by-core-v0_2.ps1
	tools/cv-step-b7h-orientation-everywhere-v0_1.ps1

no changes added to commit (use "git add" and/or "git commit -a") 
## Patch A
- wrote: src\components\v2\Cv2DoorGuide.tsx

## Patch B
- globals.css: added cv2-doorGuide styles

## Patch C
- inserted Cv2DoorGuide (mapa): src\app\c\[slug]\v2\mapa\page.tsx

## Patch C
- inserted Cv2DoorGuide (linha): src\app\c\[slug]\v2\linha\page.tsx

## Patch C
- inserted Cv2DoorGuide (linha-do-tempo): src\app\c\[slug]\v2\linha-do-tempo\page.tsx

## Patch C
- inserted Cv2DoorGuide (provas): src\app\c\[slug]\v2\provas\page.tsx

## Patch C
- inserted Cv2DoorGuide (trilhas): src\app\c\[slug]\v2\trilhas\page.tsx

## Patch C
- inserted Cv2DoorGuide (debate): src\app\c\[slug]\v2\debate\page.tsx

## Patch C
- inserted Cv2DoorGuide (trilhas): src\app\c\[slug]\v2\trilhas\[id]\page.tsx

## npm run lint  
> cadernos-vivos@0.1.0 lint
> eslint --ignore-pattern tools/_patch_backup/** 
## npm run build  
> cadernos-vivos@0.1.0 build
> next build

Ôû▓ Next.js 16.1.1 (Turbopack)

  Creating an optimized production build ...
Ô£ô Compiled successfully in 2.3s
  Running TypeScript ...
Failed to compile.

./src/components/v2/Cv2DoorGuide.tsx:37:13
Type error: Property 'label' does not exist on type 'DoorDef'.

  35 | function labelOf(id: DoorId): string {
  36 |   const d = doorById(id);
> 37 |   return (d.label ? d.label : (d.title ? d.title : id));
     |             ^
  38 | }
  39 |
  40 | function nextAfter(ids: DoorId[], active: DoorId): DoorId {
Next.js build worker exited with code: 1 and signal: null 
## Git status (post)  On branch master
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   package.json
	modified:   src/app/c/[slug]/v2/debate/page.tsx
	modified:   src/app/c/[slug]/v2/linha-do-tempo/page.tsx
	modified:   src/app/c/[slug]/v2/linha/page.tsx
	modified:   src/app/c/[slug]/v2/mapa/page.tsx
	modified:   src/app/c/[slug]/v2/page.tsx
	modified:   src/app/c/[slug]/v2/provas/page.tsx
	modified:   src/app/c/[slug]/v2/trilhas/[id]/page.tsx
	modified:   src/app/c/[slug]/v2/trilhas/page.tsx
	modified:   src/app/globals.css
	modified:   src/components/v2/Cv2CoreNodes.tsx
	modified:   src/components/v2/Cv2MapRail.tsx
	modified:   src/components/v2/Cv2MindmapHubClient.tsx
	modified:   src/lib/v2/normalize.ts
	modified:   src/lib/v2/types.ts

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	reports/20260108-222746-cv-step-b7b-core-nodes-diag.md
	reports/20260108-223304-cv-step-b7b-core-nodes-diag-v0_2.md
	reports/20260108-224331-cv-step-b7c-core-nodes-single-source.md
	reports/20260108-225048-cv-hotfix-b7c2-core-nodes-lint-build.md
	reports/20260108-225522-cv-hotfix-b7c3-core-nodes-expr-and-lintignore.md
	reports/20260108-230028-cv-step-b7d-mapfirst-nucleus-top.md
	reports/20260108-230459-cv-step-b7e-portals-curated-by-core.md
	reports/20260108-230736-cv-hotfix-b7e2-portals-curated-no-any.md
	reports/20260108-231311-cv-step-b7f-core-order-single-source.md
	reports/20260108-232411-cv-hotfix-b7f2-core-order-lint-warnings.md
	reports/20260108-232640-cv-hotfix-b7f3-maprail-meta-compat.md
	reports/20260108-234605-cv-step-b7g-mindmap-guided-by-core.md
	reports/20260109-111503-cv-hotfix-b7g2-mindmap-no-setstate-in-effect.md
	src/components/v2/Cv2DoorGuide.tsx
	src/components/v2/Cv2PortalsCurated.tsx
	src/lib/v2/doors.ts
	tools/cv-hotfix-b7c2-core-nodes-lint-build-v0_1.ps1
	tools/cv-hotfix-b7c3-core-nodes-expr-and-lintignore-v0_1.ps1
	tools/cv-hotfix-b7e2-portals-curated-no-any-v0_1.ps1
	tools/cv-hotfix-b7f2-core-order-lint-warnings-v0_1.ps1
	tools/cv-hotfix-b7f3-maprail-meta-compat-v0_1.ps1
	tools/cv-hotfix-b7g2-mindmap-no-setstate-in-effect-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_2.ps1
	tools/cv-step-b7c-core-nodes-single-source-v0_1.ps1
	tools/cv-step-b7d-mapfirst-nucleus-top-v0_1.ps1
	tools/cv-step-b7e-portals-curated-by-core-v0_1.ps1
	tools/cv-step-b7f-core-order-single-source-v0_1.ps1
	tools/cv-step-b7g-mindmap-guided-by-core-v0_1.ps1
	tools/cv-step-b7g-mindmap-guided-by-core-v0_2.ps1
	tools/cv-step-b7h-orientation-everywhere-v0_1.ps1

no changes added to commit (use "git add" and/or "git commit -a") 
