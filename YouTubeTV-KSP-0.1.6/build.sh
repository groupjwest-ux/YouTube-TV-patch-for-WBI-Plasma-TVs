#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: ./build.sh /path/to/Kerbal\\ Space\\ Program [Debug|Release]" >&2
  exit 2
fi

KSP_ROOT="$1"
CONFIGURATION="${2:-Release}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$SCRIPT_DIR/Source/YouTubeTV/YouTubeTV.csproj"

if command -v msbuild >/dev/null 2>&1; then
  BUILDER=msbuild
elif command -v xbuild >/dev/null 2>&1; then
  BUILDER=xbuild
else
  echo "Install Mono MSBuild/xbuild before building." >&2
  exit 1
fi

"$BUILDER" "$PROJECT" /p:Configuration="$CONFIGURATION" /p:KSP_ROOT="$KSP_ROOT"
cp "$SCRIPT_DIR/Source/YouTubeTV/bin/$CONFIGURATION/YouTubeTV.dll" \
   "$SCRIPT_DIR/GameData/YouTubeTV/Plugins/YouTubeTV.dll"
echo "Built: $SCRIPT_DIR/GameData/YouTubeTV/Plugins/YouTubeTV.dll"
