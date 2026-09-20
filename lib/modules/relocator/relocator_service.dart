// lib/modules/relocator/relocator_service.dart
// Service to scan, evaluate and manage 1-Click Relocator presets.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import '../utils.dart';
import 'relocator_model.dart';

final _logger = Logger('RelocatorService');

class RelocatorService {
  final String userProfile;
  final String localAppData;
  final String appData;

  RelocatorService({String? userProfile, String? localAppData, String? appData})
    : userProfile =
          userProfile ??
          Platform.environment['USERPROFILE'] ??
          'C:\\Users\\Default',
      localAppData =
          localAppData ??
          Platform.environment['LOCALAPPDATA'] ??
          'C:\\Users\\Default\\AppData\\Local',
      appData =
          appData ??
          Platform.environment['APPDATA'] ??
          'C:\\Users\\Default\\AppData\\Roaming';

  List<RelocatorPreset> get presets => getBuiltInPresets();

  String getDefaultDestination(
    String targetDriveLetter,
    RelocatorPreset preset,
  ) => suggestTargetPath(preset, targetDriveLetter);

  List<RelocatorPreset> getBuiltInPresets() {
    return [
      // 1. AI & Machine Learning
      RelocatorPreset(
        id: 'huggingface',
        name: 'HuggingFace Models',
        description: 'Cache mô hình LLM, Transformers, weights đã tải về máy',
        category: RelocatorCategory.ai,
        icon: Icons.psychology_rounded,
        accentColor: const Color(0xFFFFD21E),
        pathResolver: () => p.join(userProfile, '.cache', 'huggingface'),
      ),
      RelocatorPreset(
        id: 'ollama',
        name: 'Ollama Models',
        description:
            'Mô hình AI cục bộ chạy trên Ollama (Llama, DeepSeek, Qwen...)',
        category: RelocatorCategory.ai,
        icon: Icons.smart_toy_rounded,
        accentColor: const Color(0xFF6366F1),
        pathResolver: () => p.join(userProfile, '.ollama'),
      ),
      RelocatorPreset(
        id: 'torch',
        name: 'PyTorch Hub & Models',
        description:
            'Checkpoints và weights PyTorch tải tự động khi huấn luyện',
        category: RelocatorCategory.ai,
        icon: Icons.local_fire_department_rounded,
        accentColor: const Color(0xFFEE4C2C),
        pathResolver: () => p.join(userProfile, '.cache', 'torch'),
      ),

      // 2. Lập trình & SDK (Dev)
      RelocatorPreset(
        id: 'docker_wsl',
        name: 'Docker Desktop WSL2 Virtual Disk',
        description: 'Ổ đĩa ảo Docker (data-root, container, images khổng lồ)',
        category: RelocatorCategory.dev,
        icon: Icons.inventory_2_rounded,
        accentColor: const Color(0xFF0091E2),
        pathResolver: () => p.join(localAppData, 'Docker', 'wsl', 'data'),
      ),
      RelocatorPreset(
        id: 'android_sdk',
        name: 'Android SDK & Emulators',
        description:
            'Bộ công cụ Android SDK, Build Tools và System Images máy ảo',
        category: RelocatorCategory.dev,
        icon: Icons.android_rounded,
        accentColor: const Color(0xFF3DDC84),
        pathResolver: () => p.join(localAppData, 'Android', 'Sdk'),
      ),
      RelocatorPreset(
        id: 'gradle_cache',
        name: 'Gradle Caches',
        description:
            'Thư mục cache dependencies, wrapper và transforms của Gradle',
        category: RelocatorCategory.dev,
        icon: Icons.build_circle_rounded,
        accentColor: const Color(0xFF02303A),
        pathResolver: () => p.join(userProfile, '.gradle', 'caches'),
      ),
      RelocatorPreset(
        id: 'pub_cache',
        name: 'Flutter / Dart Pub Cache',
        description: 'Kho lưu trữ các thư viện Dart/Flutter packages tải về',
        category: RelocatorCategory.dev,
        icon: Icons.flutter_dash_rounded,
        accentColor: const Color(0xFF02569B),
        pathResolver: () => p.join(localAppData, 'Pub', 'Cache'),
      ),
      RelocatorPreset(
        id: 'npm_cache',
        name: 'NPM Global Cache',
        description: 'Cache các gói Node.js / NPM được lưu trữ cục bộ',
        category: RelocatorCategory.dev,
        icon: Icons.javascript_rounded,
        accentColor: const Color(0xFFCB3837),
        pathResolver: () => p.join(appData, 'npm-cache'),
      ),
      RelocatorPreset(
        id: 'pip_cache',
        name: 'Python Pip Cache',
        description: 'Tệp nén bánh xe (.whl) và thư viện Python pip đã tải',
        category: RelocatorCategory.dev,
        icon: Icons.code_rounded,
        accentColor: const Color(0xFF3776AB),
        pathResolver: () => p.join(localAppData, 'pip', 'cache'),
      ),

      // 3. Đồ họa & Media
      RelocatorPreset(
        id: 'adobe_cache',
        name: 'Adobe Media Cache Files',
        description: 'Peak files (.cfa, .pek) Premiere Pro & After Effects',
        category: RelocatorCategory.media,
        icon: Icons.video_library_rounded,
        accentColor: const Color(0xFFFF5252),
        pathResolver: () =>
            p.join(appData, 'Adobe', 'Common', 'Media Cache Files'),
      ),

      // 4. Game & Mods
      RelocatorPreset(
        id: 'minecraft',
        name: 'Minecraft (.minecraft)',
        description:
            'Thư mục cài đặt mods, shaders, resource packs và world saves',
        category: RelocatorCategory.game,
        icon: Icons.grid_view_rounded,
        accentColor: const Color(0xFF5DB835),
        pathResolver: () => p.join(appData, '.minecraft'),
      ),
    ];
  }

  /// Scan a single preset to determine its actual status and directory size
  Future<void> scanPreset(RelocatorPreset preset) async {
    preset.status = RelocatorStatus.scanning;
    try {
      final path = preset.pathResolver();
      preset.actualPath = path;

      final dir = Directory(path);
      if (!dir.existsSync()) {
        // Also check if it is a broken symlink
        final link = Link(path);
        if (link.existsSync() || await isSymlink(path)) {
          preset.status = RelocatorStatus.alreadySymlinked;
          preset.existingTargetPath = await getSymlinkTarget(path) ?? '';
          return;
        }
        preset.status = RelocatorStatus.notFound;
        preset.sizeBytes = 0;
        preset.fileCount = 0;
        return;
      }

      // Check if it is already a symlink or junction
      if (await isSymlink(path)) {
        preset.status = RelocatorStatus.alreadySymlinked;
        preset.existingTargetPath = await getSymlinkTarget(path) ?? '';
        return;
      }

      // Calculate size
      final result = await compute(_calculateDirectorySize, path);
      preset.sizeBytes = result.$1;
      preset.fileCount = result.$2;

      if (preset.sizeBytes > 0) {
        preset.status = RelocatorStatus.detected;
      } else {
        preset.status = RelocatorStatus.notFound;
      }
    } catch (e) {
      _logger.warning('Error scanning preset ${preset.id}: $e');
      preset.status = RelocatorStatus.notFound;
    }
  }

  /// Calculates total size and file count of a directory safely
  static (int, int) _calculateDirectorySize(String path) {
    final dir = Directory(path);
    int totalBytes = 0;
    int fileCount = 0;

    try {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          try {
            totalBytes += entity.lengthSync();
            fileCount++;
          } catch (_) {}
        }
      }
    } catch (e) {
      _logger.fine('Partial read in ${dir.path}: $e');
    }

    return (totalBytes, fileCount);
  }

  /// Get list of available target drives on Windows (excluding C:)
  Future<List<DriveTargetInfo>> getAvailableTargetDrives() async {
    if (!Platform.isWindows) {
      return const [
        DriveTargetInfo(
          letter: 'D:',
          freeBytes: 150 * 1024 * 1024 * 1024,
          totalBytes: 500 * 1024 * 1024 * 1024,
        ),
      ];
    }

    final drives = <DriveTargetInfo>[];

    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Get-CimInstance Win32_LogicalDisk | Where-Object { \$_.DriveType -in 2,3 } | Select-Object DeviceID, FreeSpace, Size | ConvertTo-Json -Compress',
      ]);

      if (result.exitCode == 0 && (result.stdout as String).trim().isNotEmpty) {
        final raw = jsonDecode(result.stdout as String);
        final list = raw is List ? raw : [raw];
        for (final item in list) {
          final id = (item['DeviceID'] as String? ?? '').toUpperCase();
          final free = (item['FreeSpace'] as num? ?? 0).toInt();
          final size = (item['Size'] as num? ?? 0).toInt();

          // Exclude system drive (C:) from targets
          if (id.isNotEmpty && !id.startsWith('C:')) {
            drives.add(
              DriveTargetInfo(letter: id, freeBytes: free, totalBytes: size),
            );
          }
        }
      }
    } catch (e) {
      _logger.warning('Failed to query drives via PowerShell: $e');
    }

    return drives;
  }

  /// Always query again immediately before relocation; never use UI cache.
  Future<int?> getTargetFreeBytes(String targetPath) async {
    if (!Platform.isWindows) return null;
    final root = p.windows
        .rootPrefix(targetPath)
        .replaceAll('\\', '')
        .toUpperCase();
    for (final drive in await getAvailableTargetDrives()) {
      if (drive.letter.toUpperCase() == root) return drive.freeBytes;
    }
    return null;
  }

  /// Generate a clean, standardized target path on the destination drive
  String suggestTargetPath(RelocatorPreset preset, String targetDriveLetter) {
    final cleanLetter = targetDriveLetter
        .replaceAll('\\', '')
        .replaceAll('/', '');
    return p.join(
      '$cleanLetter\\',
      'JA_Relocated',
      preset.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_'),
    );
  }
}
