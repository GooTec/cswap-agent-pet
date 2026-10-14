#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="$PWD/build/ChiikawaPet.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ChiikawaPet "$APP/Contents/MacOS/ChiikawaPet"
cp macos/Resources/Info.plist "$APP/Contents/Info.plist"
# Keep SwiftPM's macOS bundle intact; PNGs live in its Contents/Resources.
cp -R .build/release/ChiikawaPet_ChiikawaPet.bundle "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
printf '\n앱 생성: %s\n' "$APP"
