# Architecture

## Integration with Wild Blue Industries

WBI's existing `WBIPlasmaTV` PartModule targets a model transform named `Screen` and replaces the material's `_MainTex` and `_Emissive` textures with a selected still image. YouTube TV follows the same material convention, but supplies a Unity `RenderTexture` fed by `VideoPlayer`.

The ModuleManager patch adds `WBIYouTubeTV` alongside the original module instead of deleting or subclassing it. This keeps WBI's screenshot picker intact and avoids a hard compile-time reference to `WildBlueTools.dll`; compatibility is discovered through part configuration.

## Playback pipeline

1. Normalize the user input as a local file URI, direct HTTP/HTTPS media URI, YouTube URL, or 11-character YouTube video ID.
2. Direct media proceeds immediately to Unity `VideoPlayer`.
3. A YouTube page URL is resolved on a background thread by invoking a user-supplied `yt-dlp` process.
4. The resolver requests one muxed stream so Unity receives a single URL containing both audio and video.
5. Unity decodes the stream to a `RenderTexture` and sends audio to a spatial `AudioSource` attached to the WBI part.
6. The render texture is assigned to `_MainTex` and `_Emissive` on each matching `Screen` renderer.

## Threading

Unity objects are only touched on the main thread. The external resolver runs on a background thread and places a small completion object in a locked queue. `Update()` consumes the queue and starts Unity video preparation.

A generation counter invalidates stale resolver results when playback is stopped or a newer URL is requested.

## Extension points

A future release could replace `YtDlpResolver` with an official embedded-browser backend. Such a backend would need an off-screen Chromium/WebView implementation capable of rendering an HTML5 IFrame player into a Unity texture on every supported KSP platform.

Other possible extensions:

- Vessel-wide synchronized playback using Universal Time.
- Playlist and channel controls.
- RasterPropMonitor/MAS IVA prop support.
- Optional disk cache for authorized local media.
- Configurable screen crop, fit, and stretch modes.
- A native FFmpeg helper for DASH audio/video merging.
