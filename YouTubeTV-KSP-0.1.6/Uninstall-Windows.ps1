[CmdletBinding()]
param(
    [string]$KspRoot = '',
    [switch]$NoFolderPrompt
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

. ([System.IO.Path]::Combine($PSScriptRoot, 'Windows', 'WindowsTools.ps1'))

try {
    $resolvedKspRoot = Find-KspRoot -PreferredPath $KspRoot -AllowPrompt (-not $NoFolderPrompt)
    $target = [System.IO.Path]::Combine($resolvedKspRoot, 'GameData', 'YouTubeTV')
    if ([System.IO.Directory]::Exists($target)) {
        Remove-Item -LiteralPath $target -Recurse -Force
        Write-Host "Removed: $target" -ForegroundColor Green
    }
    else {
        Write-Host 'YouTube TV was not installed in this KSP folder.' -ForegroundColor Yellow
    }
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
