# CV — Step B6d: Domain chips + copy toolbar (Provas V2)

- when: 20260106-162329
- component: src\components\v2\Cv2DomFilterClient.tsx
- css: src\app\globals.css
- backup(comp): tools/_patch_backup/20260106-162329-Cv2DomFilterClient.tsx.bak

## O QUE MUDA
- Chips por domínio (hostname) com contagem (top 14).
- Busca rápida + stats + copiar links/MD.
- Lint-safe: sem setState dentro do useEffect (store + useSyncExternalStore).

## VERIFY
- tools/cv-verify.ps1