# CV — Step B6b1c2: Fix domfilter skip selector string

- when: 20260106-152751
- file: src\components\v2\Cv2DomFilterClient.tsx
- backup: tools\_patch_backup\20260106-152751-Cv2DomFilterClient.tsx.bak
- action: set skip selector to [data-cv2-filter-ui="1"] using single-quoted TS string

Verify: tools/cv-verify.ps1