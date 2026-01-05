param(
  [Parameter(Mandatory=$true)][string]$Name,
  [Parameter(Mandatory=$true)][string]$Title,
  [string]$Version = "v0_1",
  [string]$ReportName = "",
  [switch]$NoVerify
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/_bootstrap.ps1"

$repo = Get-Location
EnsureDir (Join-Path $repo "tools")

$safeName = $Name.Trim()
if ($safeName.EndsWith(".ps1")) { $safeName = $safeName.Substring(0, $safeName.Length - 4) }
$file = Join-Path $repo ("tools\" + $safeName + "-" + $Version + ".ps1")

if ([string]::IsNullOrWhiteSpace($ReportName)) {
  $ReportName = $safeName + "-" + $Version + ".md"
}

$lines = @(
  "# " + $Title + " — " + $Version,
  "# DIAG → PATCH → VERIFY → REPORT",
  "$ErrorActionPreference = ""Stop""",
  "",
  ". ""$PSScriptRoot/_bootstrap.ps1""",
  "",
  "$repo = Get-Location",
  "Write-Host (""[DIAG] Repo: "" + $repo)",
  "",
  "# PATCH",
  "# - use BackupFile + WriteUtf8NoBom / WriteLinesUtf8NoBom",
  "# - evite variáveis reservadas (ex: `$HOME). Prefira `$homePath / `$homeFile etc.",
  "",
  "# VERIFY",
  "if (-not $NoVerify) {",
  "  $npm = GetNpmCmd",
  "  RunCmd $npm @(""run"",""lint"")",
  "  RunCmd $npm @(""run"",""build"")",
  "}",
  "",
  "# REPORT",
  "$report = @(",
  "  ""# " + $Title + " — "" + $Version + "" (gerado)""",
  "  """" ,",
  "  ""## Mudanças"" ,",
  "  ""- ..."" ,",
  "  """" ,",
  "  ""## Verify"" ,",
  "  ""- npm run lint"" ,",
  "  ""- npm run build"" ,",
  "  """"",
  ") -join ""`n""",
  "WriteReport """ + $ReportName + """ $report | Out-Null",
  "Write-Host ""[OK] "" + $Title + "" — "" + $Version + "" aplicado e verificado."" "
)

WriteLinesUtf8NoBom $file $lines
Write-Host ("[OK] wrote: " + $file)
Write-Host ("[TIP] Rode com: pwsh -NoProfile -ExecutionPolicy Bypass -File " + $file)
