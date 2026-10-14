#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD_ARCH="${1:-$(uname -m)}"
./scripts/build-app.sh "$BUILD_ARCH"
APP_VERSION="$(tr -d '\r\n' < VERSION)"
DESTINATION="$PWD/build/release/$APP_VERSION"
mkdir -p "$DESTINATION"
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto build/ChiikawaPet.app "$STAGING_DIR/ChiikawaPet.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp macos/README.md "$STAGING_DIR/README.md"
cp macos/README.ko.md "$STAGING_DIR/README.ko.md"
cp LICENSE VERSION "$STAGING_DIR/"
cp assets/NOTICE.md "$STAGING_DIR/ARTWORK-NOTICE.md"
hdiutil create -volname "Chiikawa Pet $APP_VERSION" -srcfolder "$STAGING_DIR" \
    -format UDZO -ov "$DESTINATION/ChiikawaPet-$APP_VERSION-macos-$BUILD_ARCH.dmg"
