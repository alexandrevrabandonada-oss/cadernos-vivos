# CV — Step B3: V2 safe load + fallbacks (additive)

- when: 20260105-190436
- changed files: **2**

## PATCH
- src\lib\v2\load.ts (backup: 20260105-190436-load.ts.bak)
- src\lib\v2\normalize.ts (backup: 20260105-190436-normalize.ts.bak)

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
Ô£ô Compiled successfully in 4.3s
  Running TypeScript ...
Failed to compile.

./src/lib/v2/load.ts:42:10
Type error: Cannot find name 'pathP'. Did you mean 'path'?

  40 |
  41 | function cvCadernoRoot(slug: string): string {
> 42 |   return pathP.join(process.cwd(), "content", "cadernos", slug);
     |          ^
  43 | }
  44 |
  45 | export async function cvReadMetaLoose(slug: string): Promise<import("./contract").MetaLoose> {
Next.js build worker exited with code: 1 and signal: null
Exception: C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_bootstrap.ps1:41
Line |
  41 |  . DE -ne 0) { throw ('[STOP] falhou (exit ' + $LASTEXITCODE + '): ' + $ .
     |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | [STOP] falhou (exit 1): C:\Program Files\nodejs\npm.cmd run build
```

## NEXT
- ⚠️ Verify falhou. Corrigir o erro apontado e re-rodar.