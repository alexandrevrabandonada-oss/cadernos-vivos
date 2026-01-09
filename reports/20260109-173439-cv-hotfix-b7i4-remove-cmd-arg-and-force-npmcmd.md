# CV HOTFIX B7I4 — Remover 'cmd' do npm no B7I + forcar npm.cmd

- Stamp: 20260109-173439
- Root: C:\Projetos\Cadernos Vivos\cadernos-vivos

## DIAG

- npm(cmd) resolved: C:\Program Files\nodejs\npm.cmd
- b7i script: tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1

## PATCH

[OK] patched: tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1
- backup: tools\_patch_backup\20260109-173439\cv-step-b7i-portals-curated-everywhere-v0_1.ps1.20260109-173439.bak

## RUN (B7I)

[RUN] C:\Program Files\PowerShell\7\pwsh.exe -NoProfile -ExecutionPolicy Bypass -File tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1
[RUN] C:\Program Files\nodejs\npm.cmd 
npm <command>

Usage:

npm install        install all the dependencies in your project
npm install <foo>  add the <foo> dependency to your project
npm test           run this project's tests
npm run <foo>      run the script named <foo>
npm <command> -h   quick help on <command>
npm -l             display usage info for all commands
npm help <term>    search for help on <term> (in a browser)
npm help npm       more involved overview (in a browser)

All commands:

    access, adduser, audit, bugs, cache, ci, completion,
    config, dedupe, deprecate, diff, dist-tag, docs, doctor,
    edit, exec, explain, explore, find-dupes, fund, get, help,
    help-search, hook, init, install, install-ci-test,
    install-test, link, ll, login, logout, ls, org, outdated,
    owner, pack, ping, pkg, prefix, profile, prune, publish,
    query, rebuild, repo, restart, root, run-script, sbom,
    search, set, shrinkwrap, star, stars, start, stop, team,
    test, token, uninstall, unpublish, unstar, update, version,
    view, whoami

Specify configs in the ini-formatted file:
    C:\Users\Micro\.npmrc
or on the command line via: npm <command> --key=value

More configuration info: npm help config
Configuration fields: npm help 7 config

npm@10.9.3 C:\Program Files\nodejs\node_modules\npm
Exception: C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\cv-step-b7i-portals-curated-everywhere-v0_1.ps1:120
Line |
 120 |  . DE -ne 0) { throw ("Command failed: " + $cmd + " " + ($args -join " " .
     |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Command failed: C:\Program Files\nodejs\npm.cmd

## VERIFY (lint/build)

[RUN] npm run lint

> cadernos-vivos@0.1.0 lint
> eslint --ignore-pattern tools/_patch_backup/**

[RUN] npm run build

> cadernos-vivos@0.1.0 build
> next build

Ôû▓ Next.js 16.1.1 (Turbopack)

  Creating an optimized production build ...
Ô£ô Compiled successfully in 2.9s
  Running TypeScript ...
  Collecting page data using 11 workers ...
  Generating static pages using 11 workers (0/5) ...
  Generating static pages using 11 workers (1/5) 
  Generating static pages using 11 workers (2/5) 
  Generating static pages using 11 workers (3/5) 
Ô£ô Generating static pages using 11 workers (5/5) in 866.9ms
  Finalizing page optimization ...

Route (app)
Ôöî Ôùï /
Ôö£ Ôùï /_not-found
Ôö£ Ôùï /c
Ôö£ ãÆ /c/[slug]
Ôö£ ãÆ /c/[slug]/a/[aula]
Ôö£ ãÆ /c/[slug]/acervo
Ôö£ ãÆ /c/[slug]/debate
Ôö£ ãÆ /c/[slug]/mapa
Ôö£ ãÆ /c/[slug]/pratica
Ôö£ ãÆ /c/[slug]/quiz
Ôö£ ãÆ /c/[slug]/registro
Ôö£ ãÆ /c/[slug]/status
Ôö£ ãÆ /c/[slug]/trilha
Ôö£ ãÆ /c/[slug]/v2
Ôö£ ãÆ /c/[slug]/v2/debate
Ôö£ ãÆ /c/[slug]/v2/linha
Ôö£ ãÆ /c/[slug]/v2/linha-do-tempo
Ôö£ ãÆ /c/[slug]/v2/mapa
Ôö£ ãÆ /c/[slug]/v2/provas
Ôö£ ãÆ /c/[slug]/v2/trilhas
Ôöö ãÆ /c/[slug]/v2/trilhas/[id]


Ôùï  (Static)   prerendered as static content
ãÆ  (Dynamic)  server-rendered on demand

[OK] lint/build ok