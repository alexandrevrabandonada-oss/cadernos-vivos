# Tijolo B7F — Core Order (single source) — 20260108-231311

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
	src/components/v2/Cv2PortalsCurated.tsx
	tools/cv-hotfix-b7c2-core-nodes-lint-build-v0_1.ps1
	tools/cv-hotfix-b7c3-core-nodes-expr-and-lintignore-v0_1.ps1
	tools/cv-hotfix-b7e2-portals-curated-no-any-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_2.ps1
	tools/cv-step-b7c-core-nodes-single-source-v0_1.ps1
	tools/cv-step-b7d-mapfirst-nucleus-top-v0_1.ps1
	tools/cv-step-b7e-portals-curated-by-core-v0_1.ps1
	tools/cv-step-b7f-core-order-single-source-v0_1.ps1

no changes added to commit (use "git add" and/or "git commit -a") 
## DIAG — sinais de core order

src\components\v2\Cv2PortalsCurated.tsx:2: import type { CoreNodesV2 } from "@/lib/v2/types";
src\components\v2\Cv2PortalsCurated.tsx:4: type DoorId = "hub" | "mapa" | "linha" | "linha-do-tempo" | "provas" | "trilhas" | "debate";
src\components\v2\Cv2PortalsCurated.tsx:7: type Props = { slug: string; active?: string; current?: string; coreNodes?: CoreNodesV2 };
src\components\v2\Cv2PortalsCurated.tsx:11:   { id: "mapa", title: "Mapa", desc: "A porta central (comece por aqui).", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/mapa" },
src\components\v2\Cv2PortalsCurated.tsx:12:   { id: "linha", title: "Linha", desc: "Fatos em ordem e fio narrativo.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha" },
src\components\v2\Cv2PortalsCurated.tsx:13:   { id: "linha-do-tempo", title: "Linha do tempo", desc: "Marcos e sequência histórica.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha-do-tempo" },
src\components\v2\Cv2PortalsCurated.tsx:14:   { id: "provas", title: "Provas", desc: "Fontes, docs e evidências.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/provas" },
src\components\v2\Cv2PortalsCurated.tsx:15:   { id: "trilhas", title: "Trilhas", desc: "Caminhos guiados e prática.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/trilhas" },
src\components\v2\Cv2PortalsCurated.tsx:16:   { id: "debate", title: "Debate", desc: "Camadas de conversa e disputa.", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/debate" },
src\components\v2\Cv2PortalsCurated.tsx:30: function coreToDoorOrder(coreNodes?: CoreNodesV2): DoorId[] {
src\components\v2\Cv2PortalsCurated.tsx:31:   const base: DoorId[] = ["mapa","linha","provas","trilhas","debate"];
src\components\v2\Cv2PortalsCurated.tsx:32:   if (!coreNodes || !coreNodes.length) return base;
src\components\v2\Cv2PortalsCurated.tsx:35:   for (const v of coreNodes) {
src\components\v2\Cv2PortalsCurated.tsx:62:   return DOOR_SET.has(raw) ? (raw as DoorId) : "mapa";
src\components\v2\Cv2PortalsCurated.tsx:66:   if (!order.length) return "mapa";
src\components\v2\Cv2PortalsCurated.tsx:71:   return n === active ? "mapa" : n;
src\components\v2\Cv2PortalsCurated.tsx:81:   for (const d of ["hub","mapa","linha","linha-do-tempo","provas","trilhas","debate"] as DoorId[]) {
src\components\v2\Cv2PortalsCurated.tsx:91:   const order = coreToDoorOrder(props.coreNodes);
src\components\v2\Cv2PortalsCurated.tsx:110:         {active !== "mapa" ? (
src\components\v2\Cv2PortalsCurated.tsx:111:           <Link className="cv2-portal-pill" href={doorById("mapa").href(props.slug)} title="Comece pelo mapa">
src\components\v2\Cv2PortalsCurated.tsx:112:             Comece pelo Mapa
src\components\v2\Cv2MapRail.tsx:7: type RailProps = {
src\components\v2\Cv2MapRail.tsx:13: type RailPage = {
src\components\v2\Cv2MapRail.tsx:19: const PAGES: RailPage[] = [
src\components\v2\Cv2MapRail.tsx:21:   { id: "mapa", label: "Mapa", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/mapa" },
src\components\v2\Cv2MapRail.tsx:22:   { id: "linha", label: "Linha", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha" },
src\components\v2\Cv2MapRail.tsx:23:   { id: "linha-do-tempo", label: "Tempo", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/linha-do-tempo" },
src\components\v2\Cv2MapRail.tsx:24:   { id: "provas", label: "Provas", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/provas" },
src\components\v2\Cv2MapRail.tsx:25:   { id: "trilhas", label: "Trilhas", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/trilhas" },
src\components\v2\Cv2MapRail.tsx:26:   { id: "debate", label: "Debate", href: (s) => "/c/" + encodeURIComponent(s) + "/v2/debate" },
src\components\v2\Cv2MapRail.tsx:33: export function Cv2MapRail(props: RailProps) {
src\components\v2\Cv2MapRail.tsx:39:     <aside className="cv2-mapRail" aria-label="Corredor de portas">
src\components\v2\Cv2MapRail.tsx:40:       <div className="cv2-mapRail__inner">
src\components\v2\Cv2MapRail.tsx:41:         <div className="cv2-mapRail__title">
src\components\v2\Cv2MapRail.tsx:42:           <div className="cv2-mapRail__kicker">Eixo</div>
src\components\v2\Cv2MapRail.tsx:43:           <div className="cv2-mapRail__name">{title}</div>
src\components\v2\Cv2MapRail.tsx:46:         <nav className="cv2-mapRail__nav" aria-label="Portas do universo">
src\components\v2\Cv2MapRail.tsx:48:             <Link key={p.id} className={"cv2-mapRail__a" + (p.id === "mapa" ? " is-axis" : "")} href={p.href(slug)}>
src\components\v2\Cv2MapRail.tsx:49:               <span className="cv2-mapRail__dot" aria-hidden="true" />
src\components\v2\Cv2MapRail.tsx:50:               <span className="cv2-mapRail__txt">{p.label}</span>
src\components\v2\Cv2MapRail.tsx:55:         <div className="cv2-mapRail__hint">Mapa é o eixo. O resto são portas.</div>
src\components\v2\Cv2MapRail.tsx:61: export default Cv2MapRail;
src\components\v2\Cv2MindmapHubClient.tsx:5: type NodeId = "mapa" | "linha" | "provas" | "trilhas" | "debate";
src\components\v2\Cv2MindmapHubClient.tsx:15: export default function Cv2MindmapHubClient(props: { slug: string; title?: string }) {
src\components\v2\Cv2MindmapHubClient.tsx:20:     { id: "mapa",   label: "Mapa",   desc: "Explorar por lugares e conexões", href: "/c/" + slug + "/v2/mapa",              x: 50, y: 44 },
src\components\v2\Cv2MindmapHubClient.tsx:21:     { id: "linha",  label: "Linha",  desc: "Narrativa em fluxo (o que levou ao quê)", href: "/c/" + slug + "/v2/linha",      x: 22, y: 52 },
src\components\v2\Cv2MindmapHubClient.tsx:22:     { id: "provas", label: "Provas", desc: "Fontes, documentos e checagens", href: "/c/" + slug + "/v2/provas",             x: 78, y: 52 },
src\components\v2\Cv2MindmapHubClient.tsx:23:     { id: "trilhas",label: "Trilhas",desc: "Caminhos de leitura (do básico ao avançado)", href: "/c/" + slug + "/v2/trilhas", x: 30, y: 74 },
src\components\v2\Cv2MindmapHubClient.tsx:24:     { id: "debate", label: "Debate", desc: "Perguntas e conversa em camadas", href: "/c/" + slug + "/v2/debate",             x: 70, y: 74 }
src\components\v2\Cv2MindmapHubClient.tsx:58:     <section className="cv2-mindmap" aria-label="Mapa mental do caderno">
src\components\v2\Cv2MindmapHubClient.tsx:60:         className="cv2-mindmapFrame"
src\components\v2\Cv2MindmapHubClient.tsx:63:         aria-roledescription="Mapa mental navegável"
src\components\v2\Cv2MindmapHubClient.tsx:66:         <svg className="cv2-mindmapSvg" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
src\components\v2\Cv2MindmapHubClient.tsx:68:             <line key={n.id} x1={cx0} y1={cy0} x2={n.x} y2={n.y} className="cv2-mindmapLine" />
src\components\v2\Cv2MindmapHubClient.tsx:70:           <circle cx={cx0} cy={cy0} r="1.6" className="cv2-mindmapDot" />
src\components\v2\Cv2MindmapHubClient.tsx:73:         <div className="cv2-mindmapCenter">
src\components\v2\Cv2MindmapHubClient.tsx:74:           <div className="cv2-card cv2-mindmapCenterCard">
src\components\v2\Cv2MindmapHubClient.tsx:77:             <div className="cv2-mindmapHint">Dica: setas navegam • Enter abre</div>
src\components\v2\Cv2MindmapHubClient.tsx:82:           <div key={n.id} className="cv2-mindmapNode" style={{ left: n.x + "%", top: n.y + "%" }}>

## Patch A
- criado/atualizado: src\lib\v2\doors.ts

## Patch B
- Cv2PortalsCurated agora usa src/lib/v2/doors.ts

## Patch C
[OK] patched src\components\v2\Cv2MapRail.tsx
[OK] patched src\components\v2\Cv2MindmapHubClient.tsx

## npm run lint  
> cadernos-vivos@0.1.0 lint
> eslint --ignore-pattern tools/_patch_backup/**


C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\Cv2MapRail.tsx
  4:10  warning  'coreNodesToDoorOrder' is defined but never used  @typescript-eslint/no-unused-vars

C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\Cv2MindmapHubClient.tsx
  4:10  warning  'coreNodesToDoorOrder' is defined but never used  @typescript-eslint/no-unused-vars

Ô£û 2 problems (0 errors, 2 warnings) 
## npm run build  
> cadernos-vivos@0.1.0 build
> next build

Ôû▓ Next.js 16.1.1 (Turbopack)

  Creating an optimized production build ...
Ô£ô Compiled successfully in 3.1s
  Running TypeScript ...
  Collecting page data using 11 workers ...
  Generating static pages using 11 workers (0/5) ...
  Generating static pages using 11 workers (1/5) 
  Generating static pages using 11 workers (2/5) 
  Generating static pages using 11 workers (3/5) 
Ô£ô Generating static pages using 11 workers (5/5) in 158.9ms
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
	src/components/v2/Cv2PortalsCurated.tsx
	src/lib/v2/doors.ts
	tools/cv-hotfix-b7c2-core-nodes-lint-build-v0_1.ps1
	tools/cv-hotfix-b7c3-core-nodes-expr-and-lintignore-v0_1.ps1
	tools/cv-hotfix-b7e2-portals-curated-no-any-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_2.ps1
	tools/cv-step-b7c-core-nodes-single-source-v0_1.ps1
	tools/cv-step-b7d-mapfirst-nucleus-top-v0_1.ps1
	tools/cv-step-b7e-portals-curated-by-core-v0_1.ps1
	tools/cv-step-b7f-core-order-single-source-v0_1.ps1

no changes added to commit (use "git add" and/or "git commit -a") 
