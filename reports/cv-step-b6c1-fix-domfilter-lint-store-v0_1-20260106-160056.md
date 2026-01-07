# CV — Step B6c1: Fix domfilter lint (external store)

- when: 20260106-160056
- file: src\components\v2\Cv2DomFilterClient.tsx
- backup: tools/_patch_backup/20260106-160056-Cv2DomFilterClient.tsx.bak

## ACTIONS
- Removed setState inside useEffect by using useSyncExternalStore + bus.publish().
- Removed unused eslint-disable directives.

## VERIFY
- tools/cv-verify.ps1