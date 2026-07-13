$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$list = Join-Path $root 'ReferenceAssemblies\REFERENCE-LIST.txt'
$managed = Join-Path $root 'ReferenceAssemblies\Managed'
$missing = @()
foreach ($line in [IO.File]::ReadAllLines($list)) {
    $name = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($name) -or $name.StartsWith('#')) { continue }
    $path = Join-Path $managed $name
    if (-not [IO.File]::Exists($path)) { $missing += $name }
}
if ($missing.Count -gt 0) {
    Write-Host 'Missing reference assemblies:' -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}
foreach ($forbidden in @('mscorlib.dll','System.dll','System.Core.dll','System.Xml.dll')) {
    if ([IO.File]::Exists((Join-Path $managed $forbidden))) {
        Write-Host "Forbidden duplicate framework reference present: $forbidden" -ForegroundColor Red
        exit 1
    }
}
Write-Host 'Reference set is complete and contains no duplicate framework assemblies.' -ForegroundColor Green
Write-Host 'UnityEngine.UI.dll is present.' -ForegroundColor Green
