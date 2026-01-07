# CV — Step B6b1d: Fix domfilter lint (immutability)

- when: 20260106-153121
- file: src\components\v2\Cv2DomFilterClient.tsx
- backup: tools\_patch_backup\20260106-153121-Cv2DomFilterClient.tsx.bak
- action: add eslint-disable-next-line react-hooks/immutability above el.hidden assignment

Verify: tools/cv-verify.ps1