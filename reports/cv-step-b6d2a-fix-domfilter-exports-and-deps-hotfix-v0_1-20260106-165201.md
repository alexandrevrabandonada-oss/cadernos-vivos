# CV — Step B6d2a: Hotfix domfilter exports + deps

- when: 20260106-165201
- file: src\components\v2\Cv2DomFilterClient.tsx
- backup: tools/_patch_backup/20260106-165201-Cv2DomFilterClient.tsx.bak

## Changes
- Remove invalid xport { default as ... } (se existir).
- Ensure oldText(input: unknown): string.
- Add skipSelector to deps (caso padrão).
- Ensure named export xport { Cv2DomFilterClient }; (válido).

## Verify
- tools/cv-verify.ps1