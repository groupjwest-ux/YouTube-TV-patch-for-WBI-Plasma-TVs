Set-StrictMode -Version 2.0

$script:YouTubeTVWindowsToolsRoot = $PSScriptRoot
$script:YouTubeTVPackageRoot = Split-Path -Parent $script:YouTubeTVWindowsToolsRoot

function ConvertTo-NormalizedPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    try {
        $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))
        return [System.IO.Path]::GetFullPath($expanded)
    }
    catch {
        return $null
    }
}

function Test-KspRoot {
    param([string]$Path)

    $fullPath = ConvertTo-NormalizedPath -Path $Path
    if ([string]::IsNullOrWhiteSpace($fullPath)) {
        return $false
    }

    return [System.IO.File]::Exists([System.IO.Path]::Combine($fullPath, 'KSP_x64.exe')) -and
           [System.IO.File]::Exists([System.IO.Path]::Combine($fullPath, 'KSP_x64_Data', 'Managed', 'Assembly-CSharp.dll')) -and
           [System.IO.Directory]::Exists([System.IO.Path]::Combine($fullPath, 'GameData'))
}

function Add-UniquePath {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[string]]$List,
        [string]$Path
    )

    $normalized = ConvertTo-NormalizedPath -Path $Path
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return
    }

    foreach ($existing in $List) {
        if ([string]::Equals($existing, $normalized, [System.StringComparison]::OrdinalIgnoreCase)) {
            return
        }
    }

    $List.Add($normalized)
}

function Get-ExistingFileSystemRoots {
    $roots = New-Object System.Collections.Generic.List[string]

    try {
        foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
            try {
                if ($drive.IsReady) {
                    Add-UniquePath -List $roots -Path $drive.RootDirectory.FullName
                }
            }
            catch {
            }
        }
    }
    catch {
    }

    try {
        foreach ($drive in Get-PSDrive -PSProvider FileSystem -ErrorAction Stop) {
            if (-not [string]::IsNullOrWhiteSpace($drive.Root) -and [System.IO.Directory]::Exists($drive.Root)) {
                Add-UniquePath -List $roots -Path $drive.Root
            }
        }
    }
    catch {
    }

    return $roots.ToArray()
}

function Get-SteamLibraryRoots {
    $roots = New-Object System.Collections.Generic.List[string]

    $registryPaths = @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\Software\WOW6432Node\Valve\Steam',
        'HKLM:\Software\Valve\Steam'
    )

    foreach ($registryPath in $registryPaths) {
        try {
            $steamData = Get-ItemProperty -Path $registryPath -ErrorAction Stop
            foreach ($propertyName in @('SteamPath', 'InstallPath')) {
                $property = $steamData.PSObject.Properties[$propertyName]
                if ($null -ne $property) {
                    Add-UniquePath -List $roots -Path ([string]$property.Value)
                }
            }
        }
        catch {
        }
    }

    $programFilesX86 = ${env:ProgramFiles(x86)}
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        Add-UniquePath -List $roots -Path ([System.IO.Path]::Combine($programFilesX86, 'Steam'))
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        Add-UniquePath -List $roots -Path ([System.IO.Path]::Combine($env:ProgramFiles, 'Steam'))
    }

    $initialRoots = $roots.ToArray()
    foreach ($steamRoot in $initialRoots) {
        $libraryFile = [System.IO.Path]::Combine($steamRoot, 'steamapps', 'libraryfolders.vdf')
        if (-not [System.IO.File]::Exists($libraryFile)) {
            continue
        }

        try {
            foreach ($line in [System.IO.File]::ReadLines($libraryFile)) {
                $libraryPath = $null
                if ($line -match '"path"\s+"([^"]+)"') {
                    $libraryPath = $Matches[1]
                }
                elseif ($line -match '^\s*"\d+"\s+"([^"]+)"') {
                    $libraryPath = $Matches[1]
                }

                if (-not [string]::IsNullOrWhiteSpace($libraryPath)) {
                    Add-UniquePath -List $roots -Path $libraryPath.Replace('\\', '\')
                }
            }
        }
        catch {
        }
    }

    return $roots.ToArray()
}

function Select-KspRootInteractively {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Select the Kerbal Space Program folder containing KSP_x64.exe.'
        $dialog.ShowNewFolderButton = $false
        $result = $dialog.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dialog.SelectedPath
        }
    }
    catch {
    }

    return $null
}

function Find-KspRoot {
    param(
        [string]$PreferredPath,
        [bool]$AllowPrompt = $true
    )

    $candidates = New-Object System.Collections.Generic.List[string]

    Add-UniquePath -List $candidates -Path $PreferredPath
    Add-UniquePath -List $candidates -Path $env:KSP_ROOT

    foreach ($steamRoot in Get-SteamLibraryRoots) {
        Add-UniquePath -List $candidates -Path ([System.IO.Path]::Combine($steamRoot, 'steamapps', 'common', 'Kerbal Space Program'))
    }

    $relativeCandidates = @(
        'SteamLibrary\steamapps\common\Kerbal Space Program',
        'Games\Steam\steamapps\common\Kerbal Space Program',
        'Games\Kerbal Space Program',
        'GOG Games\Kerbal Space Program'
    )

    foreach ($root in Get-ExistingFileSystemRoots) {
        foreach ($relativePath in $relativeCandidates) {
            Add-UniquePath -List $candidates -Path ([System.IO.Path]::Combine($root, $relativePath))
        }
    }

    $probe = $script:YouTubeTVPackageRoot
    for ($index = 0; $index -lt 6 -and -not [string]::IsNullOrWhiteSpace($probe); $index++) {
        Add-UniquePath -List $candidates -Path $probe
        $parent = [System.IO.Directory]::GetParent($probe)
        $probe = if ($null -eq $parent) { $null } else { $parent.FullName }
    }

    foreach ($candidate in $candidates) {
        if (Test-KspRoot -Path $candidate) {
            return (ConvertTo-NormalizedPath -Path $candidate)
        }
    }

    if ($AllowPrompt) {
        $selectedPath = Select-KspRootInteractively
        if (Test-KspRoot -Path $selectedPath) {
            return (ConvertTo-NormalizedPath -Path $selectedPath)
        }
    }

    $preferredMessage = if ([string]::IsNullOrWhiteSpace($PreferredPath)) {
        ''
    }
    else {
        "`nThe supplied KSP folder was not valid: $PreferredPath"
    }

    throw @"
Kerbal Space Program was not found automatically.$preferredMessage

Run the command again with the folder that directly contains KSP_x64.exe, for example:
  Build-And-Install-Windows.cmd -KspRoot "C:\Program Files (x86)\Steam\steamapps\common\Kerbal Space Program"

The selected folder must contain:
  KSP_x64.exe
  KSP_x64_Data\Managed\Assembly-CSharp.dll
  GameData
"@
}

function Get-VsWherePaths {
    $paths = New-Object System.Collections.Generic.List[string]

    $programFilesX86 = ${env:ProgramFiles(x86)}
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        Add-UniquePath -List $paths -Path ([System.IO.Path]::Combine($programFilesX86, 'Microsoft Visual Studio', 'Installer', 'vswhere.exe'))
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        Add-UniquePath -List $paths -Path ([System.IO.Path]::Combine($env:ProgramFiles, 'Microsoft Visual Studio', 'Installer', 'vswhere.exe'))
    }

    return @($paths.ToArray() | Where-Object { [System.IO.File]::Exists($_) })
}

function Find-CSharpCompiler {
    # Prefer the classic .NET Framework compiler. It supplies the matching
    # mscorlib/System/System.Core references through its normal configuration.
    $frameworkCandidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:WINDIR)) {
        $frameworkCandidates += [System.IO.Path]::Combine($env:WINDIR, 'Microsoft.NET', 'Framework64', 'v4.0.30319', 'csc.exe')
        $frameworkCandidates += [System.IO.Path]::Combine($env:WINDIR, 'Microsoft.NET', 'Framework', 'v4.0.30319', 'csc.exe')
    }

    foreach ($candidate in $frameworkCandidates) {
        if ([System.IO.File]::Exists($candidate)) {
            return $candidate
        }
    }

    $command = Get-Command 'csc.exe' -ErrorAction SilentlyContinue
    if ($null -ne $command -and [System.IO.File]::Exists($command.Source)) {
        return $command.Source
    }

    foreach ($vswhere in Get-VsWherePaths) {
        try {
            $matches = & $vswhere -latest -products '*' -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\Roslyn\csc.exe'
            foreach ($match in $matches) {
                if ([System.IO.File]::Exists($match)) {
                    return $match
                }
            }
        }
        catch {
        }
    }

    throw @'
The Windows C# compiler was not found.

Enable or repair Microsoft .NET Framework 4.x, or install Visual Studio Build Tools with the .NET desktop build tools workload, then run this installer again.
'@
}

function Find-MSBuild {
    $command = Get-Command 'MSBuild.exe' -ErrorAction SilentlyContinue
    if ($null -ne $command -and [System.IO.File]::Exists($command.Source)) {
        return $command.Source
    }

    foreach ($vswhere in Get-VsWherePaths) {
        try {
            $matches = & $vswhere -latest -products '*' -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe'
            foreach ($match in $matches) {
                if ([System.IO.File]::Exists($match)) {
                    return $match
                }
            }
        }
        catch {
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:WINDIR)) {
        foreach ($candidate in @(
            [System.IO.Path]::Combine($env:WINDIR, 'Microsoft.NET', 'Framework64', 'v4.0.30319', 'MSBuild.exe'),
            [System.IO.Path]::Combine($env:WINDIR, 'Microsoft.NET', 'Framework', 'v4.0.30319', 'MSBuild.exe')
        )) {
            if ([System.IO.File]::Exists($candidate)) {
                return $candidate
            }
        }
    }

    throw @'
MSBuild was not found. Install Visual Studio Build Tools with the .NET desktop build tools workload.
'@
}

function Copy-DirectoryContents {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not [System.IO.Directory]::Exists($Source)) {
        throw "Source directory was not found: $Source"
    }

    [System.IO.Directory]::CreateDirectory($Destination) | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}
