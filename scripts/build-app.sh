#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="$PWD/build/ChiikawaPet.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ChiikawaPet "$APP/Contents/MacOS/ChiikawaPet"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
printf '\n앱 생성: %s\n' "$APP"
