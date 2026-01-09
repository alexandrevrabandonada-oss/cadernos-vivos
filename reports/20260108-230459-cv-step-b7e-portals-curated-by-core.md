# Tijolo B7E — Portais curados pelo núcleo (coreNodes) — 20260108-230459

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
	modified:   src/components/v2/Cv2CoreNodes.tsx
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
	tools/cv-hotfix-b7c2-core-nodes-lint-build-v0_1.ps1
	tools/cv-hotfix-b7c3-core-nodes-expr-and-lintignore-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_2.ps1
	tools/cv-step-b7c-core-nodes-single-source-v0_1.ps1
	tools/cv-step-b7d-mapfirst-nucleus-top-v0_1.ps1
	tools/cv-step-b7e-portals-curated-by-core-v0_1.ps1

no changes added to commit (use "git add" and/or "git commit -a") 
## Patch A
- criado/atualizado: src\components\v2\Cv2PortalsCurated.tsx

## Patch B
- globals.css: estilos cv2-portals-curated

## Patch C
- portas V2: trocar V2Portals -> Cv2PortalsCurated (+ coreNodes)

## npm run lint  
> cadernos-vivos@0.1.0 lint
> eslint --ignore-pattern tools/_patch_backup/**


C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\Cv2PortalsCurated.tsx
  30:93  error  Unexpected any. Specify a different type  @typescript-eslint/no-explicit-any

Ô£û 1 problem (1 error, 0 warnings) 
## npm run build  
> cadernos-vivos@0.1.0 build
> next build

Ôû▓ Next.js 16.1.1 (Turbopack)

  Creating an optimized production build ...
Ô£ô Compiled successfully in 2.4s
  Running TypeScript ...
  Collecting page data using 11 workers ...
  Generating static pages using 11 workers (0/5) ...
  Generating static pages using 11 workers (1/5) 
  Generating static pages using 11 workers (2/5) 
  Generating static pages using 11 workers (3/5) 
Ô£ô Generating static pages using 11 workers (5/5) in 161.9ms
  Finalizing page optimization ...

Route (app)
Ôöî Ôùï /
Ôö£ Ôùï /_not-found
Ôö£ Ôùï /c
Ôö£ ãÆ /c/[slug]
Ôö£ ãÆ /c/[slug]/a/[aula]
Ôö£ ãÆ /c/[slug]/acervo
Ôö£ ãÆ /c/[slug]/debate
Ôö£ ãÆ /c/[slug]/mapa
Ôö£ ãÆ /c/[slug]/pratica
Ôö£ ãÆ /c/[slug]/quiz
Ôö£ ãÆ /c/[slug]/registro
Ôö£ ãÆ /c/[slug]/status
Ôö£ ãÆ /c/[slug]/trilha
Ôö£ ãÆ /c/[slug]/v2
Ôö£ ãÆ /c/[slug]/v2/debate
Ôö£ ãÆ /c/[slug]/v2/linha
Ôö£ ãÆ /c/[slug]/v2/linha-do-tempo
Ôö£ ãÆ /c/[slug]/v2/mapa
Ôö£ ãÆ /c/[slug]/v2/provas
Ôö£ ãÆ /c/[slug]/v2/trilhas
Ôöö ãÆ /c/[slug]/v2/trilhas/[id]


Ôùï  (Static)   prerendered as static content
ãÆ  (Dynamic)  server-rendered on demand 
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
	src/components/v2/Cv2PortalsCurated.tsx
	tools/cv-hotfix-b7c2-core-nodes-lint-build-v0_1.ps1
	tools/cv-hotfix-b7c3-core-nodes-expr-and-lintignore-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_2.ps1
	tools/cv-step-b7c-core-nodes-single-source-v0_1.ps1
	tools/cv-step-b7d-mapfirst-nucleus-top-v0_1.ps1
	tools/cv-step-b7e-portals-curated-by-core-v0_1.ps1

no changes added to commit (use "git add" and/or "git commit -a") 
