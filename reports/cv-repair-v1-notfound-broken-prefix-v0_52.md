# CV — Repair v0_52 — conserta prefix quebrado em pages V1 (/c/[slug])

## O que aconteceu
- Linhas foram corrompidas com prefixo colado const data = await getCaderno(slug); no começo de várias linhas, gerando múltiplas defs/const reassign e quebrando build.

## O que foi feito
- Remove prefixo colado linha-a-linha.
- Remove linha pura const data = await getCaderno(slug); (pra não sobrar const).
- Garante import de 
otFound quando necessário.

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\acervo\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\debate\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\mapa\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\pratica\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\quiz\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\registro\page.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\trilha\page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)
