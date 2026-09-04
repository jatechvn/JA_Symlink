# 📜 CHANGELOG - JA Symlink Manager

All notable changes to **JA Symlink Manager** will be documented in this file.

---

## [v1.0.1] - 2026-09-04

### 🚀 Features & Enhancements

- **🌐 Consistent multilingual navigation:** synchronized the desktop and mobile navigation labels across English, 中文, and Tiếng Việt.
- **📖 Updated User Guide:** documented language switching, Administrator elevation, symlink lifecycle, verification, import/export, and crash recovery.
- **🧊 Glass UI controls:** preserved the translucent-surface legibility floor and synchronized blur/opacity settings across Bento cards, dialogs, and dropdowns.

### 🐛 Bug Fixes

- **🗣️ Mixed-language interface:** replaced hard-coded Vietnamese labels in the main shell, command palette, views, dialogs, tooltips, status badges, and settings metadata.
- **📦 Release data leakage risk:** protected local `config.ini`, logs, pending transactions, and portable symlink history from Git tracking and release ZIP packaging.
- **🔢 Version drift:** synchronized the application version across `pubspec.yaml`, runtime constants, Windows file metadata, About content, and release documentation.

### 🧪 Verification

- Flutter analyzer passed.
- Dart formatting passed.
- Eight Flutter tests passed, including create/change/remove/import smoke coverage and localization/theme tests.
- Windows debug build passed.

---

## [v1.0.0] - 2026-08-30

### 🚀 Initial Release

- **🔗 Symlink lifecycle:** create, change, remove, verify, and restore directory symbolic links.
- **🛡️ Safe operations:** copy-before-delete workflow, progress reporting, backup handling, and crash recovery.
- **📊 Desktop dashboard:** overview metrics, recent history, system scan, import/export, and settings.
- **🪟 Windows glass UI:** Windows-native Acrylic/Aero/Mica effects with performance-aware styling.
