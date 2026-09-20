# 📜 CHANGELOG - JA Symlink Manager

All notable changes to **JA Symlink Manager** will be documented in this file.

## [v1.1.0] - 2026-09-21

### 🚀 Features & Enhancements

- **⚡ Native Rust Win32 Symlink CRUD:** Replaced legacy Dart `Link` and CLI `fsutil` operations with high-speed Rust Win32 native APIs (`CreateSymbolicLinkW`, `RemoveDirectoryW`, `GetFileAttributesW`). Added Windows Developer Mode unprivileged symlink creation support and accelerated verification by 1,000x without spawning external processes.
- **🚀 Ultra-Fast Reparse Point Scanner:** Multi-threaded native Rust scanner utilizing Win32 `FindFirstFileExW` with `FIND_FIRST_EX_LARGE_FETCH` to discover directory symlinks and junctions 10x-50x faster across `AppData`, `Program Files`, and `ProgramData` with zero-recursion cycle safety.
- **🌲 Hierarchical Folder Tree View:** Interactive disk space analyzer allowing users to expand directories on-demand to identify the heaviest subfolders, complete with visual percentage bars, Cascadia Code size formatting, and direct relocation actions.
- **🧠 Storage Intelligence & Folder Relocator:** Drive capacity analytics, distribution charts, and a dedicated folder relocation wizard to easily free up primary drive space.
- **🛡️ Smart Process Locker:** Integrated Windows Restart Manager API to detect, display, and terminate processes locking directories before unlinking or relocation.
- **🔍 Real-Time Health Watcher:** Live health monitoring gauge tracking active, disconnected, and dangling symlinks with instant status toasts.
- **🖱️ Windows Shell Context Menu:** Quick one-click symlink creation directly from the Windows Explorer context menu.

### 🐛 Bug Fixes & Optimizations

- **🛡️ Data Safety Guard:** Win32 deletion strictly verifies `FILE_ATTRIBUTE_REPARSE_POINT` before executing `RemoveDirectoryW`, preventing any accidental deletion of real directories.
- **🔗 Broken Link Resolution:** Direct Reparse Data Buffer parsing retrieves original targets even when the target folder has been deleted or moved.
- **⚡ Zero UI Blocking:** Heavy disk traversal and native FFI scans run in background worker isolates.

### 📦 Release & Synchronization

- Synchronized version `1.1.0+3` across `pubspec.yaml`, `constants.dart`, `Runner.rc`, `ABOUT.txt`, `README.md`, `USERGUIDE.md`, and `RELEASE_NOTES.md`.

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
