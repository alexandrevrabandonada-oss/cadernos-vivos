# CV — Step B6b1e: Fix noImplicitAny (Cv2DomFilterClient)

- when: 20260106-153329
- file: src\components\v2\Cv2DomFilterClient.tsx
- backup: tools\_patch_backup\20260106-153329-Cv2DomFilterClient.tsx.bak
- action: add minimal TS types (unknown/string, HTMLElement, props, useRef<HTMLElement[]>)

Verify: tools/cv-verify.ps1