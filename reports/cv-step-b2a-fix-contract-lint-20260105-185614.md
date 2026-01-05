# CV — Step B2a: Fix contract.ts lint (no any)

- when: 20260105-185614
- target: `src\lib\v2\contract.ts`
- backup: `20260105-185614-contract.ts.bak`

## VERIFY
- exit: **1**

```
[OK] Guard V2 passou.
[RUN] C:\Program Files\nodejs\npm.cmd run lint

> cadernos-vivos@0.1.0 lint
> eslint

[RUN] C:\Program Files\nodejs\npm.cmd run build

> cadernos-vivos@0.1.0 build
> next build

Ôû▓ Next.js 16.1.1 (Turbopack)

  Creating an optimized production build ...
Ô£ô Compiled successfully in 2.1s
  Running TypeScript ...
Failed to compile.

./src/lib/v2/index.ts:7:1
Type error: Module "./types" has already exported a member named 'UiDefault'. Consider explicitly re-exporting to resolve the ambiguity.

  5 | export { loadCadernoV2 } from './load';
  6 | export * from "./trilhas";
> 7 | export * from "./contract";
    | ^
  8 |
Next.js build worker exited with code: 1 and signal: null
Exception: C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_bootstrap.ps1:41
Line |
  41 |  . DE -ne 0) { throw ('[STOP] falhou (exit ' + $LASTEXITCODE + '): ' + $ .
     |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | [STOP] falhou (exit 1): C:\Program Files\nodejs\npm.cmd run build
```

## NEXT
- ⚠️ Verify falhou. Corrigir o erro apontado e re-rodar.