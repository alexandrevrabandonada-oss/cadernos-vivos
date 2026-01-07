# CV — Step B5f: skeletons + loading.tsx (V2)

- when: 20260106-133101
- repo: C:\Projetos\Cadernos Vivos\cadernos-vivos

## ACTIONS
- globals.css: added CV2 skeleton shimmer + lines (scoped to .cv-v2).
- Created src/components/v2/Cv2Skeleton.tsx (SkelCard + SkelScreen).
- Created src\app\c\[slug]\v2\loading.tsx
- Created src\app\c\[slug]\v2\trilhas\loading.tsx
- Created src\app\c\[slug]\v2\trilhas\[id]\loading.tsx
- Created src\app\c\[slug]\v2\provas\loading.tsx

## BACKUPS
- 20260106-133101-globals.css.bak

## VERIFY
- exit: 1

--- VERIFY OUTPUT START ---
[OK] Guard V2 passou.
[RUN] C:\Program Files\nodejs\npm.cmd run lint

> cadernos-vivos@0.1.0 lint
> eslint

[RUN] C:\Program Files\nodejs\npm.cmd run build

> cadernos-vivos@0.1.0 build
> next build

Ôû▓ Next.js 16.1.1 (Turbopack)

  Creating an optimized production build ...
Ô£ô Compiled successfully in 2.3s
  Running TypeScript ...
Failed to compile.

./src/app/c/[slug]/v2/loading.tsx:8:3
Type error: Type '"\nhub\n"' is not assignable to type '"hub" | "list" | undefined'. Did you mean '"hub"'?

   6 | " count={
   7 | 6
>  8 | } mode="
     |   ^
   9 | hub
  10 | " />;
  11 | }
Next.js build worker exited with code: 1 and signal: null
Exception: C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_bootstrap.ps1:41
Line |
  41 |  . DE -ne 0) { throw ('[STOP] falhou (exit ' + $LASTEXITCODE + '): ' + $ .
     |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | [STOP] falhou (exit 1): C:\Program Files\nodejs\npm.cmd run build

--- VERIFY OUTPUT END ---

## NEXT
- Corrigir verify e re-rodar.