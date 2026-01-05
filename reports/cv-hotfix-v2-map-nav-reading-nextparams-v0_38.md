# CV — Hotfix v0_38 — Mapa fios quentes + keys + ReadingControls + Next params

## O que entrou
- ReadingControls reescrito: sem setState direto em effect; hidratação estável via useSyncExternalStore; aplica escala no DOM.
- V2Nav: key passa a incluir index para evitar warning de duplicidade.
- MapaV2: passa mapa={mapa} para MapaDockV2 (corrige build).
- MapaV2: fios quentes no Painel (Abrir Provas, Abrir Debate, Abrir Linha, Copiar link).
- Best-effort: pages V2 async usando await props.params em Next 16.1.

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
