[CmdletBinding()]
param(
    [string]$KspRoot = '',
    [string]$ManagedPath = '',
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [switch]$InstallYtDlp,
    [switch]$NoInstall,
    [switch]$NoFolderPrompt
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$packageRoot = $PSScriptRoot
. ([System.IO.Path]::Combine($packageRoot, 'Windows', 'WindowsTools.ps1'))

$responseFile = $null
$diagnosticFile = $null
$buildSucceeded = $false

function Get-RequiredManagedAssemblyNames {
    $listFile = [System.IO.Path]::Combine($packageRoot, 'ReferenceAssemblies', 'REFERENCE-LIST.txt')
    if (-not [System.IO.File]::Exists($listFile)) {
        throw "Reference list was not found: $listFile"
    }

    $names = New-Object System.Collections.Generic.List[string]
    foreach ($line in [System.IO.File]::ReadAllLines($listFile)) {
        $name = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($name) -or $name.StartsWith('#')) {
            continue
        }
        if ($name -match '(?i)^(mscorlib|System|System\.Core|System\.Xml)\.dll$') {
            throw "Unsafe framework assembly in reference list: $name"
        }
        $names.Add($name)
    }

    if ($names.Count -eq 0) {
        throw "The reference list is empty: $listFile"
    }
    return $names.ToArray()
}

function Test-ManagedFolder {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    foreach ($file in (Get-RequiredManagedAssemblyNames)) {
        if (-not [System.IO.File]::Exists([System.IO.Path]::Combine($Path, $file))) {
            return $false
        }
    }
    return $true
}

function Resolve-ManagedFolder {
    param(
        [string]$RequestedPath,
        [string]$ResolvedKspRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $candidate = ConvertTo-NormalizedPath -Path $RequestedPath
        if (-not (Test-ManagedFolder -Path $candidate)) {
            throw "The supplied Managed folder is incomplete: $RequestedPath"
        }
        return $candidate
    }

    $bundled = [System.IO.Path]::Combine($packageRoot, 'ReferenceAssemblies', 'Managed')
    if (Test-ManagedFolder -Path $bundled) {
        return $bundled
    }

    if (-not [string]::IsNullOrWhiteSpace($ResolvedKspRoot)) {
        $fromKsp = [System.IO.Path]::Combine($ResolvedKspRoot, 'KSP_x64_Data', 'Managed')
        if (Test-ManagedFolder -Path $fromKsp) {
            return $fromKsp
        }
    }

    throw @'
No complete KSP Managed assembly folder was found.

Keep the bundled ReferenceAssemblies\Managed folder beside this script, or pass:
  -ManagedPath "C:\Path\To\KSP_x64_Data\Managed"
'@
}

try {
    $resolvedKspRoot = $null
    if (-not $NoInstall) {
        $resolvedKspRoot = Find-KspRoot -PreferredPath $KspRoot -AllowPrompt (-not $NoFolderPrompt)
    }
    elseif (-not [string]::IsNullOrWhiteSpace($KspRoot) -and (Test-KspRoot -Path $KspRoot)) {
        $resolvedKspRoot = ConvertTo-NormalizedPath -Path $KspRoot
    }

    $managed = Resolve-ManagedFolder -RequestedPath $ManagedPath -ResolvedKspRoot $resolvedKspRoot
    $compiler = Find-CSharpCompiler
    $sourceFolder = [System.IO.Path]::Combine($packageRoot, 'Source', 'YouTubeTV')
    $buildFolder = [System.IO.Path]::Combine($sourceFolder, 'bin', $Configuration)
    $buildOutput = [System.IO.Path]::Combine($buildFolder, 'YouTubeTV.dll')
    $packagePluginFolder = [System.IO.Path]::Combine($packageRoot, 'GameData', 'YouTubeTV', 'Plugins')
    $packageDll = [System.IO.Path]::Combine($packagePluginFolder, 'YouTubeTV.dll')
    $diagnosticFile = [System.IO.Path]::Combine($buildFolder, 'Build-Diagnostics.txt')

    # Reference the complete non-framework dependency closure resolved from
    # Assembly-CSharp.dll and UnityEngine.VideoModule.dll. Framework assemblies
    # remain supplied by the Windows .NET Framework compiler to avoid CS1703.
    $referenceNames = Get-RequiredManagedAssemblyNames
    $references = @(
        foreach ($referenceName in $referenceNames) {
            [System.IO.Path]::Combine($managed, $referenceName)
        }
    )
    $sources = @(
        [System.IO.Path]::Combine($sourceFolder, 'WBIYouTubeTV.cs'),
        [System.IO.Path]::Combine($sourceFolder, 'YtDlpResolver.cs'),
        [System.IO.Path]::Combine($sourceFolder, 'MediaUrl.cs'),
        [System.IO.Path]::Combine($sourceFolder, 'Properties', 'AssemblyInfo.cs')
    )

    foreach ($requiredFile in @($references + $sources)) {
        if (-not [System.IO.File]::Exists($requiredFile)) {
            throw "Required build file was not found: $requiredFile"
        }
    }

    Write-Host ''
    Write-Host 'YouTube TV for Windows KSP - build 0.1.6' -ForegroundColor Cyan
    Write-Host "Game references:      $managed"
    Write-Host "Reference count:       $($references.Count)"
    Write-Host 'Framework references: Windows .NET Framework defaults'
    Write-Host "Compiler:             $compiler"
    Write-Host "Build:                $Configuration"
    Write-Host "Install:              $(-not $NoInstall)"
    if (-not $NoInstall) {
        Write-Host "KSP:                  $resolvedKspRoot"
    }
    Write-Host ''

    [System.IO.Directory]::CreateDirectory($buildFolder) | Out-Null
    [System.IO.Directory]::CreateDirectory($packagePluginFolder) | Out-Null

    # Delete artifacts left by older package versions before compiling.
    foreach ($oldFile in @($buildOutput, $packageDll, $diagnosticFile)) {
        if ([System.IO.File]::Exists($oldFile)) {
            Remove-Item -LiteralPath $oldFile -Force
        }
    }

    $responseFile = [System.IO.Path]::Combine($buildFolder, 'YouTubeTV.csc.rsp')
    $responseLines = New-Object System.Collections.Generic.List[string]
    $responseLines.Add('/nologo')
    $responseLines.Add('/target:library')
    $responseLines.Add('/platform:anycpu')
    $responseLines.Add('/langversion:4')
    $responseLines.Add('/warn:4')
    $responseLines.Add('/utf8output')

    if ($Configuration -eq 'Release') {
        $responseLines.Add('/optimize+')
        $responseLines.Add('/debug:pdbonly')
        $responseLines.Add('/define:TRACE')
    }
    else {
        $responseLines.Add('/optimize-')
        $responseLines.Add('/debug:full')
        $responseLines.Add('/define:DEBUG;TRACE')
    }

    $responseLines.Add('/out:"' + $buildOutput + '"')
    foreach ($reference in $references) {
        $responseLines.Add('/reference:"' + $reference + '"')
    }
    foreach ($source in $sources) {
        $responseLines.Add('"' + $source + '"')
    }

    # Guard against reintroducing the exact CS1703 cause.
    foreach ($line in $responseLines) {
        if ($line -match '(?i)(nostdlib|noconfig|\\mscorlib\.dll"|\\System\.dll"|\\System\.Core\.dll")') {
            throw "Unsafe compiler option/reference was generated: $line"
        }
    }

    [System.IO.File]::WriteAllLines(
        $responseFile,
        $responseLines.ToArray(),
        (New-Object System.Text.UTF8Encoding -ArgumentList $false)
    )

    $compilerOutput = @(& $compiler ('@' + $responseFile) 2>&1)
    $compilerExitCode = $LASTEXITCODE
    foreach ($line in $compilerOutput) {
        Write-Host ([string]$line)
    }

    $diagnosticLines = New-Object System.Collections.Generic.List[string]
    $diagnosticLines.Add('YouTube TV 0.1.6 build diagnostics')
    $diagnosticLines.Add('Compiler: ' + $compiler)
    $diagnosticLines.Add('Exit code: ' + $compilerExitCode)
    $diagnosticLines.Add('Game references: ' + $managed)
    $diagnosticLines.Add('Reference count: ' + $references.Count)
    $diagnosticLines.Add('Framework references: compiler defaults')
    $diagnosticLines.Add('')
    $diagnosticLines.Add('Compiler response file:')
    foreach ($line in $responseLines) { $diagnosticLines.Add($line) }
    $diagnosticLines.Add('')
    $diagnosticLines.Add('Compiler output:')
    foreach ($line in $compilerOutput) { $diagnosticLines.Add([string]$line) }
    [System.IO.File]::WriteAllLines($diagnosticFile, $diagnosticLines.ToArray(), (New-Object System.Text.UTF8Encoding -ArgumentList $false))

    if ($compilerExitCode -ne 0) {
        throw "The C# compiler failed with exit code $compilerExitCode. Diagnostics were saved to: $diagnosticFile"
    }
    if (-not [System.IO.File]::Exists($buildOutput)) {
        throw "The build completed without creating $buildOutput"
    }

    Copy-Item -LiteralPath $buildOutput -Destination $packageDll -Force

    if (-not $NoInstall) {
        $installedModFolder = [System.IO.Path]::Combine($resolvedKspRoot, 'GameData', 'YouTubeTV')
        Copy-DirectoryContents -Source ([System.IO.Path]::Combine($packageRoot, 'GameData', 'YouTubeTV')) -Destination $installedModFolder
    }

    if ($InstallYtDlp) {
        if ($NoInstall) {
            throw '-InstallYtDlp cannot be combined with -NoInstall.'
        }
        & ([System.IO.Path]::Combine($packageRoot, 'Install-yt-dlp-Windows.ps1')) -KspRoot $resolvedKspRoot -NoFolderPrompt
    }

    $buildSucceeded = $true
    Write-Host ''
    Write-Host 'Build complete.' -ForegroundColor Green
    Write-Host "Package DLL: $packageDll"
    Write-Host "Diagnostics: $diagnosticFile"
    if (-not $NoInstall) {
        Write-Host "Installed to: $([System.IO.Path]::Combine($resolvedKspRoot, 'GameData', 'YouTubeTV'))"
        Write-Host 'Start KSP, place a WBI plasma TV, right-click it, and select Open YouTube TV.'
        if (-not $InstallYtDlp) {
            Write-Host 'For ordinary YouTube page URLs, also run Install-yt-dlp-Windows.cmd.' -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host ''
    Write-Host 'Build or installation failed:' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if (-not [string]::IsNullOrWhiteSpace($diagnosticFile) -and [System.IO.File]::Exists($diagnosticFile)) {
        Write-Host "Build diagnostics: $diagnosticFile" -ForegroundColor Yellow
    }
    exit 1
}
finally {
    # Remove the temporary response file only after a successful build. Keeping
    # it after a failure makes troubleshooting deterministic.
    if ($buildSucceeded -and -not [string]::IsNullOrWhiteSpace($responseFile) -and [System.IO.File]::Exists($responseFile)) {
        Remove-Item -LiteralPath $responseFile -Force -ErrorAction SilentlyContinue
    }
}
