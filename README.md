# 🔗 JA Symlink Manager

<p align="center">
  <strong>Move directories safely. Keep applications working through Windows symbolic links.</strong><br>
  A Windows-first Flutter desktop utility for relocating folders, preserving original paths, and managing symlink history.
</p>

<p align="center">
  <a href="https://github.com/jatechvn/JA_Symlink/releases"><img src="https://img.shields.io/badge/Release-v1.0.1-0d6efd?style=flat-square" alt="Release v1.0.1"></a>
  <img src="https://img.shields.io/badge/Flutter-Windows-54c5f8?style=flat-square&logo=flutter&logoColor=white" alt="Flutter Windows">
  <img src="https://img.shields.io/badge/Dart-3.x-0175c2?style=flat-square&logo=dart&logoColor=white" alt="Dart 3.x">
  <img src="https://img.shields.io/badge/Platform-Windows%2010%2F11-0078d4?style=flat-square&logo=windows&logoColor=white" alt="Windows 10/11">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="MIT License"></a>
</p>

<p align="center"><a href="#quick-start">🚀 Quick Start</a> • <a href="#capabilities">💡 Capabilities</a> • <a href="#architecture">🧭 Architecture</a> • <a href="#configuration">⚙️ Configuration</a> • <a href="https://jatechvn.github.io/">🌐 Website</a></p>

<p align="center"><a href="i18n/README.vi.md">🇻🇳 Tiếng Việt</a> • <a href="i18n/README.zh-CN.md">🇨🇳 中文</a> • <a href="i18n/README.ja-JP.md">🇯🇵 日本語</a> • <a href="i18n/README.es.md">🇪🇸 Español</a> • <a href="i18n/README.fr.md">🇫🇷 Français</a> • <a href="i18n/README.de.md">🇩🇪 Deutsch</a> • <a href="i18n/README.ru.md">🇷🇺 Русский</a> • <a href="i18n/README.pt.md">🇵🇹 Português</a> • <a href="i18n/README.ko.md">🇰🇷 한국어</a></p>

---

## Overview

JA Symlink Manager helps reclaim space on a primary drive such as `C:` by moving a directory to another drive and creating a symbolic link at the original path. Windows applications continue to use the original path without knowing that the data was relocated.

Creating symbolic links is a system-level operation. The application requests Administrator privileges at startup and uses a Windows-native bridge for the filesystem operations.

## Capabilities

### Symlink lifecycle

- **Create:** copy a directory to a target drive, then replace the original directory with a symbolic link.
- **Change target:** redirect an existing symlink to another target while preserving operation history.
- **Remove:** remove the link without deleting the target data; restore the original folder from backup when available.

### Verification and recovery

- **Verify:** check active links and identify broken or externally changed targets.
- **System scan:** scan common Windows paths for symlinks created outside the application.
- **Crash recovery:** detect interrupted copy transactions and clean up or recover safely on the next launch.
- **Copy-before-delete:** protect the original data until the target copy has completed successfully.

### Import, export, and history

- **JSON import/export:** back up or transfer the symlink configuration between Windows installations.
- **CSV migration:** migrate legacy CSV history into the current JSON history format.
- **Status history:** track active, removed, and changed entries with source, target, and backup paths.

### Desktop experience

- **Bento glass UI:** native Windows Acrylic/Aero/Mica/Tabbed effects with adjustable blur and opacity.
- **Legibility floor:** translucent surfaces enforce a minimum blur level so text remains readable.
- **Multilingual UI:** switch the complete interface between English, 中文, and Tiếng Việt.
- **Performance tiers:** Auto, Ultra, Balanced, and Lite modes adapt visual effects to the hardware.
- **Command Palette:** press `Ctrl+K` to access actions and tabs quickly.

## Architecture

```text
JA_Symlink/
├── lib/
│   ├── main.dart                    # App bootstrap, elevation, providers, and window setup
│   ├── layout/                      # Dashboard shell, navigation, settings, and about/guide tabs
│   ├── views/                       # Overview, symlink list, system tools, and user guide screens
│   ├── dialogs/                     # Create, change, remove, scan, verify, and import dialogs
│   ├── widgets/                     # Reusable glass surfaces, controls, palette, and indicators
│   ├── modules/                     # Constants, i18n, config, logging, services, and operations
│   │   ├── logic/                   # Create/change/remove/verify/import/recovery workflows
│   │   └── native/                  # Windows filesystem and symlink bridge
│   └── theme/                       # Color tokens, Windows styles, glass settings, and effects
├── windows/runner/                  # Windows runner and native window/elevation integration
├── test/                            # Unit, widget, smoke, i18n, and theme persistence tests
├── assets/                          # Static resources; assets/data is local runtime history
├── i18n/                            # Translated README copies
├── build.bat                       # Windows release build and clean ZIP packaging
├── run.bat                         # Development launch helper
├── debug.bat                       # Launch helper for the debug build
├── pubspec.yaml                    # Flutter package metadata and dependencies
├── ABOUT.txt                       # JA-HUB project information card
├── CHANGELOG.md                    # Permanent release history
├── LICENSE                         # MIT license
└── .gitignore                      # Excludes runtime state, build output, and local tooling
```

## Quick Start

### Option A: Portable Run

1. Download `JA_Symlink_v1.0.1_Windows_x64.zip` from the [GitHub Releases](https://github.com/jatechvn/JA_Symlink/releases) page.
2. Extract the archive to a trusted local folder.
3. Run `ja_symlink.exe`; Windows will request Administrator elevation for symlink operations.
4. Keep the extracted folder intact; the portable app stores its local history beside the executable.

### Option B: Build from Source

Prerequisites: Windows 10/11, Flutter stable with Dart 3.x, and Git.

```powershell
git clone https://github.com/jatechvn/JA_Symlink.git
cd JA_Symlink
flutter pub get
flutter run -d windows
```

Create a release package with:

```powershell
.\build.bat
```

The packaging workflow snapshots an existing portable `dist` folder before rebuilding and excludes `config.ini`, logs, pending transactions, and local symlink history from the public ZIP.

## Configuration

Settings are persisted in `config.ini` beside the executable in a release build. A typical file contains only local UI preferences:

```ini
[app]
language=en
theme=dark
enable_transparency=true
window_effect=acrylic
perf_mode=auto
card_blur=18.0
card_opacity=0.82
dialog_blur=22.0
dialog_opacity=0.88
dropdown_blur=18.0
dropdown_opacity=0.9
```

The symlink history is stored locally under `assets/data/` beside the portable executable. Do not share this folder publicly because it may contain personal filesystem paths.

## Changelog

- **v1.0.1:** fixed multilingual navigation and UI string consistency, strengthened glass opacity/blur behavior, improved release-data protection, and added smoke coverage.
- **v1.0.0:** initial Windows desktop release with symlink lifecycle management, verification, import/export, recovery, and glass UI.

See [CHANGELOG.md](CHANGELOG.md) for the complete history.

## License & Author

Released under the [MIT License](LICENSE).

Developed by **Johnny / jatechvn** as part of the JA-HUB ecosystem.

- Website: <https://jatechvn.github.io/>
- Repository: <https://github.com/jatechvn/JA_Symlink>
