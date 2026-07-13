YouTube TV for Windows KSP 0.1.6

IMPORTANT:
The error report showed a path containing YouTubeTV-KSP-0.1.3-Windows-buildable, so an older extracted script was still being run.

Extract this archive into a brand-new folder. Do not merge it into the 0.1.3 or 0.1.4 folder.

Run Build-With-Bundled-Assemblies-Windows.cmd. The first line must say:

  YouTube TV for Windows KSP - build 0.1.6

This version does not bundle or explicitly reference mscorlib.dll, System.dll, or System.Core.dll.
