[CmdletBinding()]
param(
    [string]$KspRoot = '',
    [string]$ManagedPath = '',
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'

& ([System.IO.Path]::Combine($PSScriptRoot, 'Build-And-Install-Windows.ps1')) `
    -KspRoot $KspRoot `
    -ManagedPath $ManagedPath `
    -Configuration $Configuration `
    -NoInstall `
    -NoFolderPrompt

exit $LASTEXITCODE
