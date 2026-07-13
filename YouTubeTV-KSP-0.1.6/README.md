# YouTube TV plugin for KSP 1

An unofficial Wild Blue Industries add-on that turns WBI plasma-screen parts into spatial video displays. It keeps the original `WBIPlasmaTV` screenshot picker and adds a second PartModule, `WBIYouTubeTV`, for video.

## Features

- Plays local video files and direct HTTP/HTTPS media URLs through Unity's `VideoPlayer`.
- Resolves ordinary YouTube watch/share URLs through a user-supplied `yt-dlp` executable.
- Renders video onto the existing WBI model transform named `Screen`.
- Spatial audio emitted by the plasma-TV part.
- Play, pause, stop, clear-screen, volume, mute, loop, and autoplay controls.
- Persistent source URL and playback preferences per part.
- ModuleManager patch automatically supports every part that already contains `WBIPlasmaTV`, including the WBI plasma televisions and kPad.

## Requirements

- Kerbal Space Program 1.12.x.
- Wild Blue Tools and a WBI package containing the plasma-screen parts, such as Pathfinder's WBI Widgets.
- ModuleManager.
- Microsoft .NET Framework 4.x `csc.exe`, Visual Studio, or compatible MSBuild tooling. The Windows package includes the required reference assemblies.
- `yt-dlp` only for normal YouTube page URLs. Direct video URLs and local files work without it.

## Windows one-click build and install

For Windows KSP, double-click `Build-And-Install-Windows.cmd`. Version 0.1.6 removes bundled .NET framework references that caused CS1703 and compiles only against the supplied KSP/Unity assemblies.

## Build

The Windows package includes the supplied KSP and Unity reference assemblies. You can also build against a separate KSP installation:

```powershell
msbuild Source/YouTubeTV/YouTubeTV.csproj `
  /p:Configuration=Release `
  /p:KSP_ROOT="C:\Games\Kerbal Space Program"
```

The project copies `YouTubeTV.dll` into the KSP installation's `GameData/YouTubeTV/Plugins` when that destination exists. The included `build.ps1` and `build.sh` also copy the finished DLL into this source package's GameData folder for packaging.

On Linux with Mono MSBuild, pass the path to the KSP directory in the same way. The project targets .NET Framework 4.5 to match the existing Wild Blue Tools project style.

## Install

1. Build with `build.ps1` or `build.sh`, supplying your KSP root.
2. Copy the included `GameData/YouTubeTV` directory into KSP's `GameData` directory and ensure `Plugins/YouTubeTV.dll` is present.
3. For YouTube URLs, place `yt-dlp.exe` (Windows) or `yt-dlp` (Linux/macOS) in `GameData/YouTubeTV/PluginData`, or install it on the system PATH.
4. Start KSP, place a WBI plasma TV, and choose **Open YouTube TV** from the part-action window.

## Configuration

The automatic patch is in `GameData/YouTubeTV/Patches/WBIPlasmaScreens.cfg`. Important fields:

```cfg
MODULE
{
    name = WBIYouTubeTV
    screenTransform = Screen
    screenWidth = 1280
    screenHeight = 720
    audioMinDistance = 1
    audioMaxDistance = 25
    resolverTimeoutSeconds = 45
    // ytDlpPath = C:/Tools/yt-dlp.exe
}
```

The default resolver format requests a single muxed H.264/AAC MP4 stream at 720p or below where available. YouTube often limits single-file streams to lower resolutions; separate DASH audio/video streams are intentionally avoided because Unity's `VideoPlayer` accepts one URL.

## Limitations

- This is a source-ready package. On Windows, run the included build script to create `GameData/YouTubeTV/Plugins/YouTubeTV.dll`.
- YouTube changes can break third-party resolvers. Keep the user-supplied resolver current.
- Age-restricted, members-only, paid, private, region-blocked, DRM-protected, or sign-in-required media is not bypassed.
- Temporary stream URLs expire. The plugin resolves the source URL again whenever **Load / Play** is pressed.
- Codec support depends on the operating system and the Unity version bundled with KSP. H.264/AAC MP4 is the most compatible target.
- The official YouTube IFrame Player is browser-based; KSP's in-world WBI mesh is not an HTML browser surface. This prototype therefore uses Unity video playback after URL resolution rather than embedding the official web player.

Only play media you are authorized to access, and comply with the media host's terms and applicable copyright law.

## Project layout

- `Source/YouTubeTV/` — C# plugin source and MSBuild project.
- `GameData/YouTubeTV/Patches/` — automatic WBI compatibility patch.
- `GameData/YouTubeTV/PluginData/` — optional resolver executable location.
- `docs/ARCHITECTURE.md` — design and extension notes.

## License and trademarks

Code in this project is released under GPL-3.0-or-later. Wild Blue Industries is a trademark of Michael Billard/Angel-125. YouTube is a trademark of Google LLC. This project is unofficial and is not endorsed by either party.
