# YouTube TV — Windows KSP edition 0.1.6

This bundle is arranged for the 64-bit Windows release of Kerbal Space Program 1.12.x.

## 0.1.6 dependency fix

KSP's `Assembly-CSharp.dll` exposes types that inherit Unity UI event-system interfaces. Therefore the compiler must load `UnityEngine.UI.dll`, even though YouTube TV does not directly declare an `IPointerClickHandler`. Version 0.1.6 bundles and references the complete non-framework dependency closure of `Assembly-CSharp.dll` and `UnityEngine.VideoModule.dll`, including:

- `UnityEngine.UI.dll`
- `UnityEngine.UIModule.dll`
- `UnityEngine.TextRenderingModule.dll`
- `UnityEngine.PhysicsModule.dll` and `UnityEngine.Physics2DModule.dll`
- `UnityEngine.AnimationModule.dll`
- `UnityEngine.SharedInternalsModule.dll`
- KSP support assemblies required by `Assembly-CSharp.dll`

Windows' own `mscorlib`, `System`, `System.Core`, and `System.Xml` remain excluded to prevent duplicate-identity error CS1703. The exact compile references are listed in `ReferenceAssemblies\REFERENCE-LIST.txt`.

## Important: use the new folder

The reported compiler path contained `YouTubeTV-KSP-0.1.3-Windows-buildable`, proving that the old 0.1.3 script was still being executed. Extract this ZIP into a **new folder** and confirm the console banner says:

```text
YouTube TV for Windows KSP - build 0.1.6
```

## Fast installation

1. Install Wild Blue Tools, a WBI package containing the plasma-TV parts, and ModuleManager.
2. Extract this package to a new writable folder.
3. Double-click `Build-And-Install-Windows.cmd`.
4. Select the folder containing `KSP_x64.exe` if automatic detection does not find it.
5. Run `Install-yt-dlp-Windows.cmd` to enable ordinary YouTube watch/share URLs.
6. Start KSP and use **Open YouTube TV** on a WBI plasma TV.

## Why CS1703 happened

Older packages explicitly referenced the KSP/Mono copies of:

```text
mscorlib.dll
System.dll
System.Core.dll
```

Windows `csc.exe` also loads its own framework copies. When both sets are imported, the compiler sees duplicate assembly identities and emits `CS1703`.

## Definitive 0.1.6 fix

Version 0.1.6 no longer bundles or references those three framework assemblies. The compiler uses its normal Windows .NET Framework libraries, while the response file references only KSP and Unity assemblies:

```text
Assembly-CSharp.dll
UnityEngine.dll
UnityEngine.CoreModule.dll
UnityEngine.AudioModule.dll
UnityEngine.VideoModule.dll
UnityEngine.IMGUIModule.dll
UnityEngine.InputLegacyModule.dll
```

The response file contains neither `/noconfig` nor `/nostdlib`. A build-time guard aborts if any explicit `mscorlib`, `System`, or `System.Core` reference is accidentally reintroduced.

## Build without installing

Run:

```bat
Build-With-Bundled-Assemblies-Windows.cmd
```

The finished DLL is written to:

```text
Source\YouTubeTVin\Release\YouTubeTV.dll
GameData\YouTubeTV\Plugins\YouTubeTV.dll
```

## Build and install

```bat
Build-And-Install-Windows.cmd -KspRoot "C:\Program Files (x86)\Steam\steamapps\common\Kerbal Space Program"
```

Any existing drive is supported.

## Diagnostics

Every compiler run writes:

```text
Source\YouTubeTVin\Release\Build-Diagnostics.txt
```

If compilation fails, the temporary `YouTubeTV.csc.rsp` is also retained in that folder. These files show the exact compiler and references used.

## Local media

Paste a direct MP4/WebM URL or full Windows filename into the in-game controller, for example:

```text
E:\KSP Videos\Mun Landing.mp4
```

## YouTube URLs

Run `Install-yt-dlp-Windows.cmd` after installing the plugin. This places `yt-dlp.exe` where the plugin can use it to resolve an ordinary YouTube page URL into a temporary playable media URL.

## Removal

Run `Uninstall-Windows.cmd`, or delete `GameData\YouTubeTV`.
