# Chiikawa Agent Pet for macOS

[English](README.md) | [한국어](README.ko.md)

An unofficial floating pixel-art pet for macOS 14 or later. The app uses Swift,
AppKit, and SwiftUI and runs from the menu bar without a Dock icon.

## Installation

Choose the `macos-arm64.dmg` package for Apple Silicon or `macos-x86_64.dmg`
for Intel. Open the DMG, drag `ChiikawaPet.app` onto Applications, and launch it.
Quit a running pet before replacing the app during an update.

The current app is ad-hoc signed and has no Apple Developer ID notarization.
If macOS blocks it, review the source and release checksum, then use System
Settings → Privacy & Security → Open Anyway if you want to run that download.

## Controls

- Click the pet to toggle its usage panel; drag it to move it.
- Right-click the pet or click its menu-bar item to open the control menu.
- Use the panel to select a character, change size (40–120%, default 65%),
  toggle wandering or visibility, refresh usage, or quit.
- Menu-bar controls remain available when the desktop pet is hidden.

The menu bar shows the character, provider logos, and current quota values.
Claude shows its first two available limits; Codex shows its lowest reported
limit. Failed or disconnected providers show `—`.

## Accounts

Sign in to Claude Code with `/login` or Codex with `codex login`, then click
**새로고침** (Refresh). The app reads the default CLI credential files or matching
macOS keychain entries. Automatic refresh does not prompt for keychain access;
use manual Refresh to authorize access when necessary.

Custom `CLAUDE_CONFIG_DIR` and `CODEX_HOME` paths are supported. Finder does not
inherit shell environment variables, so run the installed executable directly
from the configured terminal:

```sh
/Applications/ChiikawaPet.app/Contents/MacOS/ChiikawaPet
```

The pet does not renew tokens or modify CLI credential files or keychain items.
Use the original CLI to reauthenticate. API-key billing has no subscription quota percentage.

## Building from source

Install Swift 6+ through Xcode or Command Line Tools, then run from the repository root:

```sh
./Launch.command
./scripts/test.sh
./scripts/package-macos.sh arm64
```

Use `x86_64` to build an Intel DMG. Packages go to `build/release/1.0.0/`.
Quit the running app before trying a preview, which performs no account requests:

```sh
open -n build/ChiikawaPet.app --args --preview 10 --show-usage
```

Hidden Bar placement and collapse behavior are not fully verified.
Source code is MIT licensed; the package includes `LICENSE` and a separate
`ARTWORK-NOTICE.md` for character images and provider logos.
