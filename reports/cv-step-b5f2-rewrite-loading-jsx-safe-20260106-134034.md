# CV — Step B5f2: rewrite loading.tsx JSX-safe (no multiline string props)

- when: 20260106-134034
- repo: C:\Projetos\Cadernos Vivos\cadernos-vivos

## ACTIONS
- Rewrote JSX-safe loading.tsx: src\app\c\[slug]\v2\loading.tsx
- Rewrote JSX-safe loading.tsx: src\app\c\[slug]\v2\trilhas\loading.tsx
- Rewrote JSX-safe loading.tsx: src\app\c\[slug]\v2\trilhas\[id]\loading.tsx
- Rewrote JSX-safe loading.tsx: src\app\c\[slug]\v2\provas\loading.tsx

## BACKUPS
- 20260106-134034-src_app_c__slug__v2_loading_tsx-loading.tsx.bak
- 20260106-134034-src_app_c__slug__v2_trilhas_loading_tsx-loading.tsx.bak
- 20260106-134034-src_app_c__slug__v2_trilhas__id__loading_tsx-loading.tsx.bak
- 20260106-134034-src_app_c__slug__v2_provas_loading_tsx-loading.tsx.bak

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
Ô£ô Compiled successfully in 2.2s
  Running TypeScript ...
Failed to compile.

./src/app/c/[slug]/v2/loading.tsx:12:7
Type error: Type '"\nhub\n"' is not assignable to type '"hub" | "list" | undefined'. Did you mean '"hub"'?

  10 | 6
  11 | }
> 12 |       mode="
     |       ^
  13 | hub
  14 | "
  15 |     />
Next.js build worker exited with code: 1 and signal: null
Exception: C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_bootstrap.ps1:41
Line |
  41 |  . DE -ne 0) { throw ('[STOP] falhou (exit ' + $LASTEXITCODE + '): ' + $ .
     |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | [STOP] falhou (exit 1): C:\Program Files\nodejs\npm.cmd run build

--- VERIFY OUTPUT END ---
