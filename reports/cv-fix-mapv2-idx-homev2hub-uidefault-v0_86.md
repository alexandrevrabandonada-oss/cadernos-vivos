# CV — Fix — MapaV2 idx + HomeV2Hub warnings + uiDefault redirect (v0_86)

## O que foi corrigido
- MapaV2: corrigiu referencias idx -> _idx nos calculos e removeu o _idx do 2o map quando não usado.
- HomeV2Hub: removeu imports nao usados (useEffect/useSyncExternalStore) e removeu setLast do destructuring quando não usado.
- /c/[slug]: usa uiDefault === "v2" para redirect("/c/"+slug+"/v2") e garante import de redirect.

## Arquivos alterados
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\MapaV2.tsx
- C:\Projetos\Cadernos Vivos\cadernos-vivos\src\components\v2\HomeV2Hub.tsx

## Verify
- tools/cv-verify.ps1 (guard + lint + build)