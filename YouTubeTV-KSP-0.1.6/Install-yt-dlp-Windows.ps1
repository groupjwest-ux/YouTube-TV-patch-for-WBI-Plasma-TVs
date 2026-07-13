[CmdletBinding()]
param(
    [string]$KspRoot = '',
    [switch]$NoFolderPrompt
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$packageRoot = $PSScriptRoot
$destination = ''
$temporary = ''
. ([System.IO.Path]::Combine($packageRoot, 'Windows', 'WindowsTools.ps1'))

try {
    $resolvedKspRoot = Find-KspRoot -PreferredPath $KspRoot -AllowPrompt (-not $NoFolderPrompt)
    $destinationFolder = [System.IO.Path]::Combine($resolvedKspRoot, 'GameData', 'YouTubeTV', 'PluginData')
    $destination = [System.IO.Path]::Combine($destinationFolder, 'yt-dlp.exe')
    $temporary = $destination + '.download'

    [System.IO.Directory]::CreateDirectory($destinationFolder) | Out-Null
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    Write-Host 'Finding the latest official yt-dlp Windows release...' -ForegroundColor Cyan
    $headers = @{ 'User-Agent' = 'YouTubeTV-KSP-Windows-Installer' }
    $release = Invoke-RestMethod -UseBasicParsing -Headers $headers -Uri 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest'
    $asset = $release.assets | Where-Object { $_.name -eq 'yt-dlp.exe' } | Select-Object -First 1
    if ($null -eq $asset) {
        throw 'The latest yt-dlp release did not contain yt-dlp.exe.'
    }

    Write-Host "Downloading $($asset.name) from release $($release.tag_name)..."
    Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $asset.browser_download_url -OutFile $temporary

    $digestProperty = $asset.PSObject.Properties['digest']
    $digest = if ($null -ne $digestProperty) { [string]$digestProperty.Value } else { '' }
    if (-not [string]::IsNullOrWhiteSpace($digest) -and $digest -match '^sha256:([0-9a-fA-F]{64})$') {
        $expectedHash = $Matches[1].ToUpperInvariant()
        $actualHash = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($actualHash -ne $expectedHash) {
            Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
            throw 'The yt-dlp SHA-256 digest did not match the official GitHub release metadata.'
        }
        Write-Host 'SHA-256 verification passed.'
    }
    else {
        Write-Host 'GitHub did not provide a release-asset digest; the download was not hash-verified.' -ForegroundColor Yellow
    }

    Move-Item -LiteralPath $temporary -Destination $destination -Force
    Write-Host "Installed: $destination" -ForegroundColor Green
}
catch {
    if (-not [string]::IsNullOrWhiteSpace($temporary) -and [System.IO.File]::Exists($temporary)) {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
    Write-Host $_.Exception.Message -ForegroundColor Red
    throw
}
