# CV — Step B3a: Fix load.ts pathP/fsP references

- when: 20260105-193920
- file: `src\lib\v2\load.ts`
- backup: `20260105-193920-load.ts.bak`

## ACTIONS
- Replaced pathP. -> path. (existing import).
- Inserted import: readFile as cvReadFile; replaced fsP.readFile -> cvReadFile.

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
Ô£ô Compiled successfully in 2.2s
  Running TypeScript ...
Failed to compile.

./src/lib/v2/load.ts:57:72
Type error: Cannot find name 'UiDefault'.

  55 | }
  56 |
> 57 | export async function cvResolveUiDefaultForSlug(slug: string): Promise<UiDefault | undefined> {
     |                                                                        ^
  58 |   const meta = await cvReadMetaLoose(slug);
  59 |   const ui = cvAsRecord(meta.ui);
  60 |   const uiDefault = ui ? ui["default"] : undefined;
Next.js build worker exited with code: 1 and signal: null
Exception: C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\_bootstrap.ps1:41
Line |
  41 |  . DE -ne 0) { throw ('[STOP] falhou (exit ' + $LASTEXITCODE + '): ' + $ .
     |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | [STOP] falhou (exit 1): C:\Program Files\nodejs\npm.cmd run build
```

## NEXT
- ⚠️ Verify falhou. Corrigir o erro apontado e re-rodar.