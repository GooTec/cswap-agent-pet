# Releases

[English](RELEASING.md) | [한국어](RELEASING.ko.md)

## Versioning

Update the root `VERSION` file using `MAJOR.MINOR.PATCH` and add release notes in
`docs/releases/v<version>.md`. Update `CHANGELOG.md` and the package names shown
in both README languages. The macOS build stamps this version into the app's
Info.plist; the Windows project reads it for assembly and file versions.
Use a Git tag named `v<version>` for the exact commit being released.

## Local packages

Run from the repository root. macOS requires Swift 6+ and Apple's build tools.
The Windows installer requires .NET 10 and NSIS.

```sh
./scripts/test.sh
./scripts/package-macos.sh arm64
./scripts/package-macos.sh x86_64
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\package-windows.ps1
```

Outputs go to `build/release/<version>/`. The Windows script also builds a
portable ZIP. Every package includes documentation, the source-code license,
and a separate artwork notice. Native Windows installer and GUI checks run with:

```powershell
.\scripts\test-installed-windows.ps1 -Installer .\build\release\1.0.0\ChiikawaPet-1.0.0-win-x64-setup.exe
```

Generate checksums and check all packages after collecting the builds:

```sh
python3 scripts/check-release.py build/release/1.0.0
```

This validates package names, ZIP integrity, the Windows payload version and
required files and runtime licenses, and the installer executable header. It writes `SHA256SUMS`.
It does not substitute for manual Windows UI tests.

## GitHub release workflow

The [release workflow](../.github/workflows/release.yml) can be run manually to
build reviewable artifacts. Pushing a `v*` tag builds Apple Silicon and Intel
DMGs and Windows x64 packages, runs platform checks, and creates a **draft**
release with the artifacts, checksums, and matching release notes.
The tag must exactly match `VERSION`; a mismatch fails the build.

Before pushing, confirm that the local commit, version, release notes, and
artwork distribution permissions are the intended ones. This guide does not
publish a release or change repository visibility by itself.

```sh
git tag -a v1.0.0 -m 'Chiikawa Agent Pet v1.0.0'
git push origin main
git push origin v1.0.0
```

Review the workflow results and attached assets, then publish the draft from
GitHub Releases. Publishing exposes the release to anyone who can access the
repository; a private repository's release remains private.

## Current limits

- macOS apps are ad-hoc signed; Apple Developer ID signing and notarization are not configured.
- Windows installers are not certificate-signed.
- Windows CI checks installation, process startup in preview mode, and uninstall. Manually verify transparency, dragging, tray interactions, real account refresh, and mixed-DPI monitors before claiming full Windows support.
- Source-code licensing excludes character images and provider logos. Include `ARTWORK-NOTICE.md` when distributing the packaged app.
