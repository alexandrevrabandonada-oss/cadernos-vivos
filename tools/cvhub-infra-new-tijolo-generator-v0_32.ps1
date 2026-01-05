# CV — Infra — Gerador de Tijolos (template DIAG→PATCH→VERIFY→REPORT) — v0_32
$ErrorActionPreference = "Stop"

$repo = Get-Location
$bootstrap = Join-Path $repo "tools\_bootstrap.ps1"
if (-not (Test-Path -LiteralPath $bootstrap)) { throw "[STOP] tools/_bootstrap.ps1 não encontrado (rode o tijolo infra antes)." }
. $bootstrap

Write-Host ("[DIAG] Repo: " + $repo)

$toolsDir = Join-Path $repo "tools"
EnsureDir $toolsDir

$genPath = Join-Path $toolsDir "cv-new-tijolo.ps1"
$bk = BackupFile $genPath

$genLines = @(
'param(',
'  [Parameter(Mandatory=$true)][string]$Name,',
'  [Parameter(Mandatory=$true)][string]$Title,',
'  [string]$Version = "v0_1",',
'  [string]$ReportName = "",',
'  [switch]$NoVerify',
')',
'',
'$ErrorActionPreference = "Stop"',
'. "$PSScriptRoot/_bootstrap.ps1"',
'',
'$repo = Get-Location',
'EnsureDir (Join-Path $repo "tools")',
'',
'$safeName = $Name.Trim()',
'if ($safeName.EndsWith(".ps1")) { $safeName = $safeName.Substring(0, $safeName.Length - 4) }',
'$file = Join-Path $repo ("tools\" + $safeName + "-" + $Version + ".ps1")',
'',
'if ([string]::IsNullOrWhiteSpace($ReportName)) {',
'  $ReportName = $safeName + "-" + $Version + ".md"',
'}',
'',
'$lines = @(',
'  "# " + $Title + " — " + $Version,',
'  "# DIAG → PATCH → VERIFY → REPORT",',
'  "$ErrorActionPreference = ""Stop""",',
'  "",',
'  ". ""$PSScriptRoot/_bootstrap.ps1""",',
'  "",',
'  "$repo = Get-Location",',
'  "Write-Host (""[DIAG] Repo: "" + $repo)",',
'  "",',
'  "# PATCH",',
'  "# - use BackupFile + WriteUtf8NoBom / WriteLinesUtf8NoBom",',
'  "# - evite variáveis reservadas (ex: `$HOME). Prefira `$homePath / `$homeFile etc.",',
'  "",',
'  "# VERIFY",',
'  "if (-not $NoVerify) {",',
'  "  $npm = GetNpmCmd",',
'  "  RunCmd $npm @(""run"",""lint"")",',
'  "  RunCmd $npm @(""run"",""build"")",',
'  "}",',
'  "",',
'  "# REPORT",',
'  "$report = @(",',
'  "  ""# " + $Title + " — "" + $Version + "" (gerado)""",',
'  "  """" ,",',
'  "  ""## Mudanças"" ,",',
'  "  ""- ..."" ,",',
'  "  """" ,",',
'  "  ""## Verify"" ,",',
'  "  ""- npm run lint"" ,",',
'  "  ""- npm run build"" ,",',
'  "  """"",',
'  ") -join ""`n""",',
'  "WriteReport """ + $ReportName + """ $report | Out-Null",',
'  "Write-Host ""[OK] "" + $Title + "" — "" + $Version + "" aplicado e verificado."" "',
')',
'',
'WriteLinesUtf8NoBom $file $lines',
'Write-Host ("[OK] wrote: " + $file)',
'Write-Host ("[TIP] Rode com: pwsh -NoProfile -ExecutionPolicy Bypass -File " + $file)',
'')

WriteLinesUtf8NoBom $genPath $genLines
Write-Host ("[OK] wrote: " + $genPath)
if ($bk) { Write-Host ("[BK] " + $bk) }

# VERIFY geral (pra garantir que nada quebrou)
$verify = Join-Path $toolsDir "cv-verify.ps1"
Write-Host ("[RUN] " + $verify)
& $verify

# REPORT
$rep = @(
"# CV — Infra v0_32 — Gerador de Tijolos",
"",
"## O que foi adicionado",
"- tools/cv-new-tijolo.ps1: cria um novo tijolo com template padrão DIAG→PATCH→VERIFY→REPORT.",
"",
"## Como usar",
"Exemplo:",
"- pwsh -NoProfile -ExecutionPolicy Bypass -File tools/cv-new-tijolo.ps1 -Name ""cvhub-v2-tijolo-x"" -Title ""CV — V2 Tijolo X"" -Version ""v0_1""",
"",
"## Verify",
"- tools/cv-verify.ps1",
""
) -join "`n"

WriteReport "cv-infra-new-tijolo-generator-v0_32.md" $rep | Out-Null
Write-Host "[OK] v0_32 aplicado e verificado."