# CV — Step B6d1: Fix DomFilter export + deps

- when: 20260106-163114
- file: src\components\v2\Cv2DomFilterClient.tsx
- backup: tools/_patch_backup/20260106-163114-Cv2DomFilterClient.tsx.bak

## O QUE MUDA
- Adiciona xport { default as Cv2DomFilterClient } pra compat com import { Cv2DomFilterClient } ....
- Ajusta skipSelector (useMemo) + deps do useEffect pra remover warning do exhaustive-deps.

## VERIFY
- tools/cv-verify.ps1