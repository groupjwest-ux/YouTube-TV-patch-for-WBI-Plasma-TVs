YouTube TV 0.1.6 bundled KSP/Unity compile references

The Managed folder contains the recursive non-framework dependency closure of
Assembly-CSharp.dll and UnityEngine.VideoModule.dll from the user-supplied KSP
Managed assembly set. The exact compiler list is REFERENCE-LIST.txt.

Framework assemblies are deliberately absent:
  mscorlib.dll
  System.dll
  System.Core.dll
  System.Xml.dll

The Windows .NET Framework compiler supplies those assemblies, preventing CS1703.
Do not copy these reference DLLs into GameData; they are build-time files only.
