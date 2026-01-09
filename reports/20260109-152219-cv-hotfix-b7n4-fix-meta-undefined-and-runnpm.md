# CV HOTFIX B7N4 — meta undefined + RunNpm robusto — 20260109-152219

Root: C:\Projetos\Cadernos Vivos\cadernos-vivos

## DIAG

- map page exists (LiteralPath): True
- core component exists: True
- b7n script exists: True

## PATCH A — /v2/mapa: remover meta={meta} em <Cv2CoreHighlights ...>

[OK] atualizado: src\app\c\[slug]\v2\mapa\page.tsx
- backup: tools\_patch_backup\20260109-152219\page.tsx

## PATCH B — Cv2CoreHighlights: tornar props.meta opcional

[OK] atualizado: src\components\v2\Cv2CoreHighlights.tsx
- backup: tools\_patch_backup\20260109-152219\Cv2CoreHighlights.tsx

## PATCH C — B7N v0_2: Run() robusto (sem $args)

[OK] atualizado: tools\cv-step-b7n-map-core-highlights-v0_2.ps1
- backup: tools\_patch_backup\20260109-152219\cv-step-b7n-map-core-highlights-v0_2.ps1

## VERIFY

[OK] lint/build OK