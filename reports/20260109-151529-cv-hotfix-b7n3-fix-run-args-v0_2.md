# CV HOTFIX B7N3 v0_2 — Fix Run args binding — 20260109-151529

Target: tools\cv-step-b7n-map-core-highlights-v0_2.ps1

[OK] patch aplicado em tools\cv-step-b7n-map-core-highlights-v0_2.ps1
- backup: tools\_patch_backup\20260109-151529\cv-step-b7n-map-core-highlights-v0_2.ps1

## RE-RUN B7N v0_2

[RUN] pwsh -NoProfile -ExecutionPolicy Bypass -File tools\cv-step-b7n-map-core-highlights-v0_2.ps1

----
== CV B7N MAP CORE HIGHLIGHTS v0_2 == 20260109-151529
[PATCH] wrote -> src\components\v2\Cv2CoreHighlights.tsx
[OK] css already has core highlights
[OK] Map page already references Cv2CoreHighlights
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
Exception: C:\Projetos\Cadernos Vivos\cadernos-vivos\tools\cv-step-b7n-map-core-highlights-v0_2.ps1:41
Line |
  41 |  . DE -ne 0) { throw ("Command failed: " + $cmd + " " + ($args -join " " .
     |                ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Command failed: C:\Program Files\nodejs\npm.cmd
----

[OK] B7N executado (veja log acima).