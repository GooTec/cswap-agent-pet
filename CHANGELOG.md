# Changelog

Release versions follow `MAJOR.MINOR.PATCH`. The current version is stored in
[VERSION](VERSION).

## 1.0.0 — 2026-10-14

- Add floating Chiikawa, Hachiware, and Usagi pets for macOS and Windows.
- Display remaining Claude and Codex subscription quotas, reset times, and connection errors.
- Change expressions using the lowest currently available quota.
- Support character selection, dragging, size adjustment, visibility, wandering, and saved preferences.
- Keep macOS menu-bar controls and Windows notification-area controls available when the pet is hidden.
- Separate platform source code and share sprite and logo assets.
- Add English and Korean documentation, an MIT source-code license, and a separate artwork notice.
- Package macOS DMGs, a Windows installer, and a Windows portable ZIP with versioned filenames.

Windows GUI, installer execution, and mixed-DPI behavior still need validation on Windows.
Current packages are not signed with an Apple Developer ID or a Windows code-signing certificate.
