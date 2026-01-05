# CV — Step D6 — Trilhas V2 (v0_64)

## O que entrou
- Componente TrilhasV2: renderiza trilhas (de 	rilhas ou derivadas do mapa via 	ype: trail).
- Rota /c/[slug]/v2/trilhas: carrega via loadCadernoV2, aplica --accent e usa V2Nav.
- Best-effort: tenta adicionar aba Trilhas no V2Nav se for lista de objetos.

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\TrilhasV2.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\app\c\[slug]\v2\trilhas\page.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)