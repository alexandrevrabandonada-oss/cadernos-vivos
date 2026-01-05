# CV — Hotfix v0_39 — Next params Promise + ReadingControls stable + V2Nav keys + MapaDock props

## O que entrou
- ReadingControls: hidrata sem setState em effect; usa store externo para hydrated; prefs via storage e evento cv:prefs.
- V2Nav: key inclui index para evitar warning.
- MapaV2: garante mapa={mapa} no MapaDockV2.
- Pages V2: props.params.slug passa a usar await (Next 16.1 params Promise).

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
