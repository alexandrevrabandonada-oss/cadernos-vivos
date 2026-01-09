# Tijolo B7B — CoreNodes DIAG v0_2 (grep real) — 20260108-223304

Repo: C:\Projetos\Cadernos Vivos\cadernos-vivos

## Git status  On branch master
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	reports/20260108-222746-cv-step-b7b-core-nodes-diag.md
	tools/cv-step-b7b-core-nodes-diag-v0_1.ps1
	tools/cv-step-b7b-core-nodes-diag-v0_2.ps1

nothing added to commit but untracked files present (use "git add" to track) 
## Git log (5)  0929bc4 chore(cv): V2 Concreto Zen (map-first + portais + rails + core nodes)
546a8f3 chore(cv): hotfix params Promise + provas export/download + ui polish
98df9cb fix(cv): Next 16 params Promise + provas export/download
64051e6 chore(cv): V2 pages use safe motor (loadCadernoV2 + metadata)
966d33f v2: add zod contract (meta loose) + fix lint/export conflicts 
## Inventário rápido — V2 pages

- src\app\c\[slug]\v2\page.tsx
- src\app\c\[slug]\v2\debate\page.tsx
- src\app\c\[slug]\v2\linha\page.tsx
- src\app\c\[slug]\v2\linha-do-tempo\page.tsx
- src\app\c\[slug]\v2\mapa\page.tsx
- src\app\c\[slug]\v2\provas\page.tsx
- src\app\c\[slug]\v2\trilhas\page.tsx
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx

## CoreNodes: onde aparece

### Pattern: coreNodes

- src\app\c\[slug]\v2\page.tsx:33  import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
- src\app\c\[slug]\v2\page.tsx:321  <Cv2CoreNodes slug={slug} title={title0} />
- src\components\v2\Cv2CoreNodes.tsx:24  export default function Cv2CoreNodes(props: { slug: string; title?: string }) {
- src\components\v2\V2CoreNodes.tsx:14  export default function V2CoreNodes({ slug }: { slug: string }) {

### Pattern: CoreNodes

- src\app\c\[slug]\v2\page.tsx:33  import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
- src\app\c\[slug]\v2\page.tsx:321  <Cv2CoreNodes slug={slug} title={title0} />
- src\components\v2\Cv2CoreNodes.tsx:24  export default function Cv2CoreNodes(props: { slug: string; title?: string }) {
- src\components\v2\V2CoreNodes.tsx:14  export default function V2CoreNodes({ slug }: { slug: string }) {

### Pattern: Cv2CoreNodes

- src\app\c\[slug]\v2\page.tsx:33  import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
- src\app\c\[slug]\v2\page.tsx:321  <Cv2CoreNodes slug={slug} title={title0} />
- src\components\v2\Cv2CoreNodes.tsx:24  export default function Cv2CoreNodes(props: { slug: string; title?: string }) {

### Pattern: V2CoreNodes

- src\app\c\[slug]\v2\page.tsx:33  import Cv2CoreNodes from "@/components/v2/Cv2CoreNodes";
- src\app\c\[slug]\v2\page.tsx:321  <Cv2CoreNodes slug={slug} title={title0} />
- src\components\v2\Cv2CoreNodes.tsx:24  export default function Cv2CoreNodes(props: { slug: string; title?: string }) {
- src\components\v2\V2CoreNodes.tsx:14  export default function V2CoreNodes({ slug }: { slug: string }) {

## Consumo: Portals / Rails / Mindmap

### Pattern: V2Portals

- src\app\c\[slug]\v2\page.tsx:34  import V2Portals from "@/components/v2/V2Portals";
- src\app\c\[slug]\v2\page.tsx:413  <V2Portals slug={slug} active="hub" />
- src\app\c\[slug]\v2\debate\page.tsx:3  import V2Portals from "@/components/v2/V2Portals";
- src\app\c\[slug]\v2\debate\page.tsx:46  <V2Portals slug={slug} active="debate" />
- src\app\c\[slug]\v2\linha\page.tsx:3  import V2Portals from "@/components/v2/V2Portals";
- src\app\c\[slug]\v2\linha\page.tsx:46  <V2Portals slug={slug} active="linha" />
- src\app\c\[slug]\v2\linha-do-tempo\page.tsx:9  import V2Portals from "@/components/v2/V2Portals";
- src\app\c\[slug]\v2\linha-do-tempo\page.tsx:56  <V2Portals slug={slug} active="linha-do-tempo" />
- src\app\c\[slug]\v2\mapa\page.tsx:10  import V2Portals from "@/components/v2/V2Portals";
- src\app\c\[slug]\v2\mapa\page.tsx:57  <V2Portals slug={slug} active="mapa" />
- src\app\c\[slug]\v2\provas\page.tsx:11  import V2Portals from "@/components/v2/V2Portals";
- src\app\c\[slug]\v2\provas\page.tsx:54  <V2Portals slug={slug} active="provas" />
- src\app\c\[slug]\v2\trilhas\page.tsx:8  import V2Portals from "@/components/v2/V2Portals";
- src\app\c\[slug]\v2\trilhas\page.tsx:46  <V2Portals slug={slug} active="trilhas" />
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:12  import V2Portals from "@/components/v2/V2Portals";
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:199  <V2Portals slug={slug} active="trilhas" />
- src\components\v2\V2Portals.tsx:50  export default function V2Portals(props: Props) {

### Pattern: Cv2MapRail

- src\app\c\[slug]\v2\mapa\page.tsx:6  import Cv2MapRail from "@/components/v2/Cv2MapRail";
- src\app\c\[slug]\v2\mapa\page.tsx:54  <Cv2MapRail slug={slug} title={title} meta={data.meta} />
- src\components\v2\Cv2MapRail.tsx:33  export function Cv2MapRail(props: RailProps) {
- src\components\v2\Cv2MapRail.tsx:61  export default Cv2MapRail;

### Pattern: Cv2UniverseRail

- src\app\c\[slug]\v2\page.tsx:36  import Cv2UniverseRail from "@/components/v2/Cv2UniverseRail";
- src\app\c\[slug]\v2\page.tsx:298  <Cv2UniverseRail slug={slug} active="hub" />
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:14  import Cv2UniverseRail from "@/components/v2/Cv2UniverseRail";
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:120  <Cv2UniverseRail slug={slug} active="trilhas" />
- src\components\v2\Cv2UniverseRail.tsx:22  export default function Cv2UniverseRail(props: { slug: string; active?: string; current?: string; title?: string }) {

### Pattern: Cv2MindmapHubClient

- src\app\c\[slug]\v2\page.tsx:4  import Cv2MindmapHubClient from "@/components/v2/Cv2MindmapHubClient";
- src\app\c\[slug]\v2\page.tsx:323  <Cv2MindmapHubClient slug={slug} />
- src\components\v2\Cv2MindmapHubClient.tsx:15  export default function Cv2MindmapHubClient(props: { slug: string; title?: string }) {

### Pattern: V2QuickNav

- src\app\c\[slug]\v2\page.tsx:13  import V2QuickNav from "@/components/v2/V2QuickNav";
- src\app\c\[slug]\v2\page.tsx:317  <V2QuickNav />
- src\app\c\[slug]\v2\debate\page.tsx:2  import V2QuickNav from "@/components/v2/V2QuickNav";
- src\app\c\[slug]\v2\debate\page.tsx:41  <V2QuickNav />
- src\app\c\[slug]\v2\linha\page.tsx:2  import V2QuickNav from "@/components/v2/V2QuickNav";
- src\app\c\[slug]\v2\linha\page.tsx:41  <V2QuickNav />
- src\app\c\[slug]\v2\linha-do-tempo\page.tsx:3  import V2QuickNav from "@/components/v2/V2QuickNav";
- src\app\c\[slug]\v2\linha-do-tempo\page.tsx:53  <V2QuickNav />
- src\app\c\[slug]\v2\mapa\page.tsx:4  import V2QuickNav from "@/components/v2/V2QuickNav";
- src\app\c\[slug]\v2\mapa\page.tsx:48  <V2QuickNav />
- src\app\c\[slug]\v2\provas\page.tsx:3  import V2QuickNav from "@/components/v2/V2QuickNav";
- src\app\c\[slug]\v2\provas\page.tsx:44  <V2QuickNav />
- src\app\c\[slug]\v2\trilhas\page.tsx:2  import V2QuickNav from "@/components/v2/V2QuickNav";
- src\app\c\[slug]\v2\trilhas\page.tsx:41  <V2QuickNav />
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:7  import V2QuickNav from "@/components/v2/V2QuickNav";
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:123  <V2QuickNav />
- src\components\v2\V2QuickNav.tsx:48  export default function V2QuickNav() {

### Pattern: Cv2MapFirstCta

- src\app\c\[slug]\v2\page.tsx:35  import Cv2MapFirstCta from "@/components/v2/Cv2MapFirstCta";
- src\app\c\[slug]\v2\page.tsx:318  <Cv2MapFirstCta slug={slug} current="hub" />
- src\app\c\[slug]\v2\debate\page.tsx:9  import Cv2MapFirstCta from "@/components/v2/Cv2MapFirstCta";
- src\app\c\[slug]\v2\debate\page.tsx:42  <Cv2MapFirstCta slug={slug} current="debate" />
- src\app\c\[slug]\v2\linha\page.tsx:9  import Cv2MapFirstCta from "@/components/v2/Cv2MapFirstCta";
- src\app\c\[slug]\v2\linha\page.tsx:42  <Cv2MapFirstCta slug={slug} current="linha" />
- src\app\c\[slug]\v2\linha-do-tempo\page.tsx:10  import Cv2MapFirstCta from "@/components/v2/Cv2MapFirstCta";
- src\app\c\[slug]\v2\linha-do-tempo\page.tsx:54  <Cv2MapFirstCta slug={slug} current="linha-do-tempo" />
- src\app\c\[slug]\v2\provas\page.tsx:12  import Cv2MapFirstCta from "@/components/v2/Cv2MapFirstCta";
- src\app\c\[slug]\v2\provas\page.tsx:45  <Cv2MapFirstCta slug={slug} current="provas" />
- src\app\c\[slug]\v2\trilhas\page.tsx:9  import Cv2MapFirstCta from "@/components/v2/Cv2MapFirstCta";
- src\app\c\[slug]\v2\trilhas\page.tsx:42  <Cv2MapFirstCta slug={slug} current="trilhas" />
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:13  import Cv2MapFirstCta from "@/components/v2/Cv2MapFirstCta";
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:124  <Cv2MapFirstCta slug={slug} current="trilhas" />
- src\components\v2\Cv2MapFirstCta.tsx:9  export default function Cv2MapFirstCta(props: Props) {

## Meta / data layer candidates

### Pattern: meta.ui.default

- src\lib\v2\contract.ts:25  // meta.ui.default pode ser string OU function (legado).

### Pattern: uiDefault

- src\app\c\[slug]\page.tsx:25  function uiDefault(meta: unknown): string {
- src\app\c\[slug]\page.tsx:32  const d2 = (meta as AnyObj)["uiDefault"];
- src\app\c\[slug]\page.tsx:69  const ui = (typeof uiDefault === "function")
- src\app\c\[slug]\page.tsx:71  ? (uiDefault as unknown as (m: unknown) => string)(data.meta)
- src\app\c\[slug]\page.tsx:73  : (uiDefault as unknown as string);
- src\lib\v2\contract.ts:2  import type { UiDefault } from "./types";
- src\lib\v2\contract.ts:21  function isUiDefault(v: unknown): v is UiDefault {
- src\lib\v2\contract.ts:26  export function resolveUiDefault(uiDefault: unknown): UiDefault | undefined {
- src\lib\v2\contract.ts:27  if (isUiDefault(uiDefault)) return uiDefault;
- src\lib\v2\contract.ts:29  if (typeof uiDefault === "function") {
- src\lib\v2\contract.ts:31  const fn = uiDefault as unknown as (() => unknown);
- src\lib\v2\contract.ts:33  if (isUiDefault(v)) return v;
- src\lib\v2\load.ts:3  import type { JsonValue, CadernoV2, UiDefault } from "./types";
- src\lib\v2\load.ts:5  import { parseMetaLoose, resolveUiDefault, safeJsonParse } from "./contract";
- src\lib\v2\load.ts:57  export async function cvResolveUiDefaultForSlug(slug: string): Promise<UiDefault | undefined> {
- src\lib\v2\load.ts:60  const uiDefault = ui ? ui["default"] : undefined;
- src\lib\v2\load.ts:61  return resolveUiDefault(uiDefault);
- src\lib\v2\normalize.ts:2  AcervoV2, CadernoV2, DebateV2, JsonValue, MapaV2, MetaV2, RegistroV2, UiDefault
- src\lib\v2\normalize.ts:38  const uiDefault = (uiDefRaw as UiDefault | undefined) || "v1";
- src\lib\v2\normalize.ts:40  const meta: MetaV2 = { slug, title, mood, ui: { default: uiDefault } };
- src\lib\v2\types.ts:4  export type UiDefault = "v1" | "v2";
- src\lib\v2\types.ts:16  ui?: { default?: UiDefault };

### Pattern: normalize

- src\components\UniverseShell.tsx:17  function normalizeMood(s: string): string {
- src\components\UniverseShell.tsx:33  const normalized = normalizeMood(moodProp || "");
- src\components\UniverseShell.tsx:34  const mood = normalized ? normalized : moodFromSlug(slug);
- src\components\v2\AcervoV2.tsx:46  function normalizeAcervo(acervo: unknown): AcervoItem[] {
- src\components\v2\AcervoV2.tsx:73  const items = useMemo(() => normalizeAcervo(props.acervo), [props.acervo]);
- src\components\v2\Cv2ProvasGroupedClient.tsx:54  function normalizeText(input: unknown): string {
- src\components\v2\Cv2ProvasGroupedClient.tsx:145  const text = normalizeText(a.textContent);
- src\components\v2\Cv2ProvasGroupedClient.tsx:146  const dom = normalizeText(a.getAttribute("data-domain"));
- src\components\v2\LinhaDoTempoV2.tsx:55  function normalizeTimeline(raw: unknown, mapa: unknown): TimelineItem[] {
- src\components\v2\LinhaDoTempoV2.tsx:91  const base = normalizeTimeline(props.linha, props.mapa);
- src\components\v2\LinhaV2.tsx:43  function normalize(items: unknown[]): TimelineItem[] {
- src\components\v2\LinhaV2.tsx:94  if (arr && arr.length) items = normalize(arr);
- src\components\v2\MapaCanvasV2.tsx:57  function normalizeNodes(input: unknown): NodeItem[] {
- src\components\v2\MapaCanvasV2.tsx:97  const nodes = useMemo(() => normalizeNodes(props.mapa), [props.mapa]);
- src\components\v2\MapaDockV2.tsx:63  function normalizeNodes(input: unknown): NodeItem[] {
- src\components\v2\MapaDockV2.tsx:90  const nodes = useMemo(() => normalizeNodes(props.mapa), [props.mapa]);
- src\components\v2\TimelineV2.tsx:108  function normalize(items: unknown[]): TimelineEvent[] {
- src\components\v2\TimelineV2.tsx:131  const events = useMemo(() => normalize(props.items || []), [props.items]);
- src\components\v2\TrilhasV2.tsx:49  function normalizeItem(v: unknown): TrailItem {
- src\components\v2\TrilhasV2.tsx:82  if (Array.isArray(today)) out.today = today.map(normalizeItem);
- src\components\v2\TrilhasV2.tsx:83  if (Array.isArray(week)) out.week = week.map(normalizeItem);
- src\components\v2\TrilhasV2.tsx:84  if (Array.isArray(month)) out.month = month.map(normalizeItem);
- src\components\v2\TrilhasV2.tsx:155  if (arr) items = arr.map(normalizeItem);
- src\lib\v2\index.ts:2  export * from "./normalize";
- src\lib\v2\load.ts:4  import { normalizeCadernoV2 } from "./normalize";
- src\lib\v2\load.ts:34  return normalizeCadernoV2(input, slug);
- src\lib\v2\normalize.ts:27  export function normalizeMetaV2(raw: unknown, fallbackSlug: string): MetaV2 {
- src\lib\v2\normalize.ts:56  export function normalizeCadernoV2(input: unknown, fallbackSlug: string): CadernoV2 {
- src\lib\v2\normalize.ts:58  const meta = normalizeMetaV2(o["meta"], fallbackSlug);
- src\lib\v2\normalize.ts:82  // CV:B3 normalize helpers
- src\lib\v2\types.ts:34  // Contrato do loader/normalize V2 (superset; não interfere na V1)

### Pattern: frontmatter

(sem hits)

### Pattern: getCaderno

- src\app\c\[slug]\layout.tsx:5  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\layout.tsx:34  const data = (await getCaderno(slug)) as unknown;
- src\app\c\[slug]\page.tsx:4  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\page.tsx:42  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\page.tsx:48  data = await getCaderno(slug);
- src\app\c\[slug]\acervo\page.tsx:3  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\acervo\page.tsx:16  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\acervo\page.tsx:18  data = await getCaderno(slug);
- src\app\c\[slug]\debate\page.tsx:2  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\debate\page.tsx:9  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\debate\page.tsx:11  data = await getCaderno(slug);
- src\app\c\[slug]\mapa\page.tsx:4  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\mapa\page.tsx:23  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\mapa\page.tsx:25  data = await getCaderno(slug);
- src\app\c\[slug]\pratica\page.tsx:2  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\pratica\page.tsx:9  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\pratica\page.tsx:11  data = await getCaderno(slug);
- src\app\c\[slug]\quiz\page.tsx:2  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\quiz\page.tsx:9  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\quiz\page.tsx:11  data = await getCaderno(slug);
- src\app\c\[slug]\registro\page.tsx:2  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\registro\page.tsx:9  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\registro\page.tsx:11  data = await getCaderno(slug);
- src\app\c\[slug]\trilha\page.tsx:2  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\trilha\page.tsx:9  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\trilha\page.tsx:11  data = await getCaderno(slug);
- src\lib\cadernos.ts:42  export async function getCaderno(slug: string) {

### Pattern: loadCaderno

- src\app\c\[slug]\v2\page.tsx:14  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\page.tsx:225  const caderno = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\debate\page.tsx:5  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\debate\page.tsx:30  const caderno = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\linha\page.tsx:5  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\linha\page.tsx:30  const caderno = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\linha-do-tempo\page.tsx:5  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\linha-do-tempo\page.tsx:40  const data = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\mapa\page.tsx:7  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\mapa\page.tsx:31  let data: Awaited<ReturnType<typeof loadCadernoV2>>;
- src\app\c\[slug]\v2\mapa\page.tsx:33  data = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\provas\page.tsx:5  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\provas\page.tsx:35  const data = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\trilhas\page.tsx:4  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\trilhas\page.tsx:33  const caderno = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:9  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:100  let data: Awaited<ReturnType<typeof loadCadernoV2>>;
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:102  data = await loadCadernoV2(slug);
- src\lib\v2\index.ts:5  export { loadCadernoV2 } from './load';
- src\lib\v2\load.ts:22  export async function loadCadernoV2(slug: string): Promise<CadernoV2> {

### Pattern: caderno

- src\app\layout.tsx:5  title: "Cadernos Vivos • VR Abandonada",
- src\app\layout.tsx:6  description: "Hub de cadernos interativos: estudo, debate e prática no território.",
- src\app\page.tsx:2  import { listCadernos } from "@/lib/cadernos-index";
- src\app\page.tsx:7  const items = await listCadernos();
- src\app\page.tsx:13  <h1 className="text-2xl font-semibold mt-1">Cadernos Vivos</h1>
- src\app\page.tsx:15  Um acervo vivo: leitura, prática, debate e registro. Cada caderno nasce do território.
- src\app\page.tsx:26  <h2 className="text-xl font-semibold">Cadernos</h2>
- src\app\page.tsx:32  <div className="text-lg font-semibold">Nenhum caderno encontrado</div>
- src\app\page.tsx:34  Crie uma pasta em content/cadernos/NOME e adicione caderno.json para aparecer aqui.
- src\app\page.tsx:51  <div className="mt-3 text-sm accent">Abrir caderno</div>
- src\app\c\page.tsx:2  import { listCadernos } from "@/lib/cadernos-index";
- src\app\c\page.tsx:7  const items = await listCadernos();
- src\app\c\page.tsx:13  <h1 className="text-2xl font-semibold mt-1">Todos os cadernos</h1>
- src\app\c\page.tsx:15  Lista gerada a partir de content/cadernos. Cada pasta vira um caderno.
- src\app\c\page.tsx:26  <div className="text-lg font-semibold">Nenhum caderno encontrado</div>
- src\app\c\page.tsx:27  <p className="muted mt-2">Crie um em content/cadernos para ele aparecer aqui.</p>
- src\app\c\page.tsx:43  <div className="mt-3 text-sm accent">Abrir caderno</div>
- src\app\c\[slug]\layout.tsx:5  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\layout.tsx:23  export default async function CadernoLayout({
- src\app\c\[slug]\layout.tsx:34  const data = (await getCaderno(slug)) as unknown;
- src\app\c\[slug]\page.tsx:4  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\page.tsx:10  import CadernoShell from "@/components/CadernoShell";
- src\app\c\[slug]\page.tsx:42  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\page.tsx:48  data = await getCaderno(slug);
- src\app\c\[slug]\page.tsx:86  <CadernoShell title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} style={s}>
- src\app\c\[slug]\page.tsx:119  </CadernoShell>
- src\app\c\[slug]\acervo\page.tsx:3  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\acervo\page.tsx:5  import CadernoShell from "@/components/CadernoShell";
- src\app\c\[slug]\acervo\page.tsx:16  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\acervo\page.tsx:18  data = await getCaderno(slug);
- src\app\c\[slug]\acervo\page.tsx:27  <CadernoShell title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} style={s}>
- src\app\c\[slug]\acervo\page.tsx:29  </CadernoShell>
- src\app\c\[slug]\debate\page.tsx:2  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\debate\page.tsx:4  import CadernoShell from "@/components/CadernoShell";
- src\app\c\[slug]\debate\page.tsx:9  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\debate\page.tsx:11  data = await getCaderno(slug);
- src\app\c\[slug]\debate\page.tsx:24  <CadernoShell title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} style={s}>
- src\app\c\[slug]\debate\page.tsx:30  </CadernoShell>
- src\app\c\[slug]\mapa\page.tsx:4  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\mapa\page.tsx:7  import CadernoShell from "@/components/CadernoShell";
- src\app\c\[slug]\mapa\page.tsx:11  const p = path.join(process.cwd(), "content", "cadernos", slug, "mapa.json");
- src\app\c\[slug]\mapa\page.tsx:23  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\mapa\page.tsx:25  data = await getCaderno(slug);
- src\app\c\[slug]\mapa\page.tsx:34  <CadernoShell title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} style={s}>
- src\app\c\[slug]\mapa\page.tsx:36  </CadernoShell>
- src\app\c\[slug]\pratica\page.tsx:2  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\pratica\page.tsx:4  import CadernoShell from "@/components/CadernoShell";
- src\app\c\[slug]\pratica\page.tsx:9  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\pratica\page.tsx:11  data = await getCaderno(slug);
- src\app\c\[slug]\pratica\page.tsx:19  <CadernoShell title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} style={s}>
- src\app\c\[slug]\pratica\page.tsx:25  </CadernoShell>
- src\app\c\[slug]\quiz\page.tsx:2  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\quiz\page.tsx:4  import CadernoShell from "@/components/CadernoShell";
- src\app\c\[slug]\quiz\page.tsx:9  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\quiz\page.tsx:11  data = await getCaderno(slug);
- src\app\c\[slug]\quiz\page.tsx:19  <CadernoShell title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} style={s}>
- src\app\c\[slug]\quiz\page.tsx:25  </CadernoShell>
- src\app\c\[slug]\registro\page.tsx:2  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\registro\page.tsx:4  import CadernoShell from "@/components/CadernoShell";
- src\app\c\[slug]\registro\page.tsx:9  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\registro\page.tsx:11  data = await getCaderno(slug);
- src\app\c\[slug]\registro\page.tsx:19  <CadernoShell title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} style={s}>
- src\app\c\[slug]\registro\page.tsx:21  </CadernoShell>
- src\app\c\[slug]\status\page.tsx:57  const base = path.join(process.cwd(), "content", "cadernos", slug);
- src\app\c\[slug]\status\page.tsx:116  <div className="text-xs muted">Status do Caderno</div>
- src\app\c\[slug]\status\page.tsx:163  <p className="text-xs muted mt-3">Dica: se algo estiver faltando, isso é sobre conteúdo em content/cadernos/
- src\app\c\[slug]\trilha\page.tsx:2  import { getCaderno } from "@/lib/cadernos";
- src\app\c\[slug]\trilha\page.tsx:4  import CadernoShell from "@/components/CadernoShell";
- src\app\c\[slug]\trilha\page.tsx:9  let data: Awaited<ReturnType<typeof getCaderno>>;
- src\app\c\[slug]\trilha\page.tsx:11  data = await getCaderno(slug);
- src\app\c\[slug]\trilha\page.tsx:19  <CadernoShell title={data.meta.title} subtitle={data.meta.subtitle} ethos={data.meta.ethos} style={s}>
- src\app\c\[slug]\trilha\page.tsx:25  {data.trilha ? <Markdown markdown={data.trilha} /> : <p className="muted">Sem trilha ainda. (Crie content/cadernos/[slug]/trilha.md)</p>}
- src\app\c\[slug]\trilha\page.tsx:27  </CadernoShell>
- src\app\c\[slug]\v2\error.tsx:8  <p style={{ marginTop: 8, opacity: 0.8 }}>Deu ruim ao carregar esta página do caderno.</p>
- src\app\c\[slug]\v2\page.tsx:14  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\page.tsx:180  return { title: title0 + " • Cadernos Vivos", description };
- src\app\c\[slug]\v2\page.tsx:225  const caderno = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\page.tsx:243  caderno && typeof (caderno as unknown as { title?: string }).title === "string"
- src\app\c\[slug]\v2\page.tsx:252  ? (caderno as unknown as { title: string }).title
- src\app\c\[slug]\v2\debate\page.tsx:5  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\debate\page.tsx:25  return { title: title + " • Cadernos Vivos", description };
- src\app\c\[slug]\v2\debate\page.tsx:30  const caderno = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\debate\page.tsx:32  caderno && typeof (caderno as unknown as { title?: string }).title === "string"
- src\app\c\[slug]\v2\debate\page.tsx:33  ? (caderno as unknown as { title: string }).title
- src\app\c\[slug]\v2\linha\page.tsx:5  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\linha\page.tsx:25  return { title: title + " • Cadernos Vivos", description };
- src\app\c\[slug]\v2\linha\page.tsx:30  const caderno = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\linha\page.tsx:32  caderno && typeof (caderno as unknown as { title?: string }).title === "string"
- src\app\c\[slug]\v2\linha\page.tsx:33  ? (caderno as unknown as { title: string }).title
- src\app\c\[slug]\v2\linha-do-tempo\page.tsx:5  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\linha-do-tempo\page.tsx:34  title: title + " • Cadernos Vivos",
- src\app\c\[slug]\v2\linha-do-tempo\page.tsx:40  const data = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\mapa\page.tsx:7  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\mapa\page.tsx:24  title: title + " • Cadernos Vivos",
- src\app\c\[slug]\v2\mapa\page.tsx:31  let data: Awaited<ReturnType<typeof loadCadernoV2>>;
- src\app\c\[slug]\v2\mapa\page.tsx:33  data = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\provas\page.tsx:5  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\provas\page.tsx:29  title: title + " • Cadernos Vivos",
- src\app\c\[slug]\v2\provas\page.tsx:35  const data = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\trilhas\page.tsx:4  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\trilhas\page.tsx:27  title: title + " • Cadernos Vivos",
- src\app\c\[slug]\v2\trilhas\page.tsx:33  const caderno = await loadCadernoV2(slug);
- src\app\c\[slug]\v2\trilhas\page.tsx:34  const title = (caderno && (caderno as unknown as { title?: string }).title) ? (caderno as unknown as { title: string }).title : slug;
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:9  import { loadCadernoV2 } from "@/lib/v2";
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:61  const p = join(process.cwd(), "content", "cadernos", slug, "trilhas.json");
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:92  title: title + " • Cadernos Vivos",
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:100  let data: Awaited<ReturnType<typeof loadCadernoV2>>;
- src\app\c\[slug]\v2\trilhas\[id]\page.tsx:102  data = await loadCadernoV2(slug);
- src\components\AcervoClient.tsx:56  Arquivos do caderno. Aqui é base material: PDFs, DOCs, imagens, planilhas.
- src\components\AcervoClient.tsx:96  ? ("/cadernos/" + encodeURIComponent(resolvedSlug) + "/acervo/" + encodeURIComponent(it.file))
- src\components\AcervoClient.tsx:131  Sem itens ainda. Coloque arquivos em public/cadernos/&lt;slug&gt;/acervo e liste no content/cadernos/&lt;slug&gt;/acervo.json
- src\components\AtaMutirao.tsx:173  Isto aqui e ferramenta do Cadernos Vivos: memoria do territorio + organizacao. Nao e o app ECO.
- src\components\AulaProgress.tsx:34  {slug ? <div className="text-xs muted mt-1">caderno: {slug}</div> : null}
- src\components\CadernoHeader.tsx:6  export function CadernoHeader({
- src\components\CadernoHeader.tsx:33  export default CadernoHeader;
- src\components\CadernoShell.tsx:3  import CadernoHeader from "@/components/CadernoHeader";
- src\components\CadernoShell.tsx:8  export default function CadernoShell({
- src\components\CadernoShell.tsx:37  <CadernoHeader title={title} subtitle={subtitle} ethos={ethos} />
- src\components\DebateBoard.tsx:98  <div className="muted mt-2">Abra este painel dentro de um caderno (/c/slug/debate).</div>
- src\components\NavPills.tsx:23  { key: "home", label: "Caderno", href: "/c/" + s },
- src\components\NavPills.tsx:39  <nav aria-label="Seções do caderno" className="my-3">
- src\components\TerritoryMap.tsx:90  {slug ? <div className="text-xs muted">caderno: {slug}</div> : null}
- src\components\v2\AcervoV2.tsx:104  <div style={{ fontSize: 12, opacity: 0.8 }}>Caderno</div>
- src\components\v2\AcervoV2.tsx:153  Nada por aqui ainda. (Se o seu caderno ainda não tem acervo, a gente já tem o componente pronto.)
- src\components\v2\Cv2MindmapHubClient.tsx:58  <section className="cv2-mindmap" aria-label="Mapa mental do caderno">
- src\components\v2\DebateBoardV2.tsx:93  Nenhum conteúdo de debate encontrado neste caderno. Você pode adicionar em meta.json ou debate.json (ou equivalente), e a UI vai renderizar aqui.
- src\components\v2\DebateV2.tsx:52  const root = path.join(process.cwd(), "content", "cadernos", slug);
- src\components\v2\DebateV2.tsx:112  Crie <code>{"content/cadernos/" + slug + "/debate.md"}</code> ou <code>{"content/cadernos/" + slug + "/debate.json"}</code> para alimentar esta tela.
- src\components\v2\HomeV2.tsx:14  desc: "Conecta temas, lugares e relações. O caderno como território navegável.",
- src\components\v2\HomeV2.tsx:47  <div style={{ fontSize: 12, opacity: 0.75, fontWeight: 800 }}>Caderno Vivo — V2</div>
- src\components\v2\HomeV2.tsx:61  title="Assinatura do caderno (accent)"
- src\components\v2\HomeV2.tsx:106  title="Abrir a versão V1 deste caderno"
- src\components\v2\HomeV2Hub.tsx:69  <div style={small}>{typeof nodes === "number" ? (nodes + " nós detectados") : "abrir o mapa do caderno"}</div>
- src\components\v2\LinhaDoTempoV2.tsx:192  Nada por aqui ainda. Coloque <span className="font-mono">linhaDoTempo</span> (array) no JSON do caderno, ou dentro de <span className="font-mono">mapa</span>.
- src\components\v2\LinhaV2.tsx:80  const root = path.join(process.cwd(), "content", "cadernos", slug);
- src\components\v2\LinhaV2.tsx:110  Aqui entram marcos, eventos, etapas e viradas do caderno. Por enquanto, lê <code>linha.md</code> / <code>linha.json</code> (ou <code>timeline.*</code>).
- src\components\v2\LinhaV2.tsx:149  Crie <code>{"content/cadernos/" + slug + "/linha.md"}</code> ou <code>{"content/cadernos/" + slug + "/linha.json"}</code> para alimentar esta tela.
- src\components\v2\MapaCanvasV2.tsx:214  Nenhum no encontrado no mapa deste caderno.
- src\components\v2\MapaV2Client.tsx:205  Crie <code>content/cadernos/{slug}/mapa.json</code> (com <code>nodes</code> e opcional <code>edges</code>) para habilitar o mapa interativo.
- src\components\v2\MapaV2Interactive.tsx:25  const root = path.join(process.cwd(), "content", "cadernos", slug);
... (truncado)

