# Changelog

## 0.1.6 - 2026-07-12

- Added `UnityEngine.UI.dll`, resolving CS0012 for `IPointerClickHandler` and `IEventSystemHandler`.
- Added the complete recursive non-framework dependency closure for `Assembly-CSharp.dll` and `UnityEngine.VideoModule.dll`.
- Added `ReferenceAssemblies/REFERENCE-LIST.txt` as the single source of truth for PowerShell and diagnostic builds.
- Updated the Visual Studio project to reference the same complete dependency set.
- Continued to exclude `mscorlib.dll`, `System.dll`, `System.Core.dll`, and `System.Xml.dll` to avoid CS1703.

## 0.1.5 - 2026-07-12

- Removed bundled and explicit references to `mscorlib.dll`, `System.dll`, and `System.Core.dll`.
- Returned framework-library resolution to the Windows .NET Framework compiler defaults, eliminating the CS1703 collision at its source.
- Removed `/noconfig` and `/nostdlib` from the build path.
- Added a response-file safety check that rejects accidental framework references.
- Added persistent `Build-Diagnostics.txt` output and retains the response file after failed builds.
- Changed compiler discovery to prefer the classic .NET Framework 4.x compiler.
- Added a unique package root and a visible 0.1.5 build banner to prevent accidentally running an older extracted copy.

## 0.1.4 - 2026-07-12

- Fixed `CS1703` duplicate imports of `System.dll` and `System.Core.dll`.
- Moved `/noconfig` from the compiler response file to the direct `csc.exe` command line.
- Retained `/nostdlib+` and explicit bundled KSP framework references so compilation targets the supplied runtime assemblies exactly once.
- Updated Windows troubleshooting and package version metadata.

## 0.1.3 - 2026-07-12

- Added the supplied KSP and Unity managed assemblies as a self-contained Windows reference set.
- Added `Build-With-Bundled-Assemblies-Windows.cmd`.
- Fixed the duplicated conditional in `PausePlayback()`.

## 0.1.2 - 2026-07-12

- Fixed the PowerShell crash when an assumed drive such as `D:` did not exist.
- Replaced hard-coded drive probing with mounted-filesystem enumeration.
- Added a folder picker when KSP cannot be detected automatically.
- Added compiler response-file builds for paths containing spaces.
- Added a build-only Windows launcher.
- Removed the misleading default `C:\Games\Kerbal Space Program` path from the MSBuild project.
- Added explicit MSBuild validation for `KSP_ROOT`.

## 0.1.1 - 2026-07-12

- Added a Windows-focused build-and-install launcher.
- Added Steam-library detection and a Visual-Studio-free Windows compiler path.
- Added an optional official `yt-dlp.exe` installer with release-metadata hash verification.
- Added a Windows uninstaller and dedicated Windows guide.

## 0.1.0 - 2026-07-12

- Initial source release.
- Added `WBIYouTubeTV` PartModule.
- Added direct URL and local-file playback through Unity `VideoPlayer`.
- Added optional YouTube URL resolution through a user-supplied `yt-dlp` executable.
- Added spatial audio, loop, mute, volume, autoplay, and screen restoration.
- Added automatic ModuleManager patch for WBI parts containing `WBIPlasmaTV`.
