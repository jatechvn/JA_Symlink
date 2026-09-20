// lib/modules/storage/storage_intelligence_service.dart
// Service for querying Windows drives and calculating storage savings

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import '../symlink_service.dart';
import 'storage_model.dart';

final _logger = Logger('StorageIntelligenceService');

/// Background worker function to calculate directory size without blocking UI thread
(int, int) computeDirectorySizeWorker(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return (0, 0);

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
    _logger.fine('Partial read while sizing directory $path: $e');
  }

  return (totalBytes, fileCount);
}

/// Service providing live drive space tracking and storage savings calculations
class StorageIntelligenceService extends ChangeNotifier {
  List<DriveSpaceInfo> _drives = [];
  StorageSavingsSummary _savings = StorageSavingsSummary.empty;
  final Map<String, SymlinkStorageStat> _statsCache = {};
  bool _isScanning = false;
  DateTime? _lastDrivesRefresh;
  int _scanRevision = 0;
  bool _disposed = false;

  Future<(int, int)> measureTarget(String path) =>
      compute(computeDirectorySizeWorker, path);

  @override
  void dispose() {
    _disposed = true;
    _scanRevision++;
    super.dispose();
  }

  List<DriveSpaceInfo> get drives => List.unmodifiable(_drives);
  StorageSavingsSummary get savings => _savings;
  bool get isScanning => _isScanning;
  DateTime? get lastDrivesRefresh => _lastDrivesRefresh;

  /// Look up cached stats for a specific symlink target
  SymlinkStorageStat? getStatForTarget(String targetPath) {
    return _statsCache[_normalizeKey(targetPath)];
  }

  /// Query all logical drives from Windows
  Future<List<DriveSpaceInfo>> getLogicalDrives({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _drives.isNotEmpty) {
      // Return cached if refreshed within 10 seconds
      if (_lastDrivesRefresh != null &&
          DateTime.now().difference(_lastDrivesRefresh!).inSeconds < 10) {
        return _drives;
      }
    }

    if (!Platform.isWindows) {
      _drives = const [
        DriveSpaceInfo(
          letter: 'C:',
          label: 'System',
          driveKind: DriveKind.localFixed,
          totalBytes: 500 * 1024 * 1024 * 1024,
          freeBytes: 120 * 1024 * 1024 * 1024,
        ),
        DriveSpaceInfo(
          letter: 'D:',
          label: 'Data',
          driveKind: DriveKind.localFixed,
          totalBytes: 1000 * 1024 * 1024 * 1024,
          freeBytes: 650 * 1024 * 1024 * 1024,
        ),
      ];
      _lastDrivesRefresh = DateTime.now();
      if (!_disposed) notifyListeners();
      return _drives;
    }

    final resultDrives = <DriveSpaceInfo>[];

    try {
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID, VolumeName, DriveType, FreeSpace, Size | ConvertTo-Json -Compress',
      ]);

      if (res.exitCode == 0 && (res.stdout as String).trim().isNotEmpty) {
        final raw = jsonDecode(res.stdout as String);
        final list = raw is List ? raw : [raw];

        for (final item in list) {
          final id = (item['DeviceID'] as String? ?? '').toUpperCase();
          if (id.isEmpty) continue;

          final label = (item['VolumeName'] as String? ?? '').trim();
          final typeInt = (item['DriveType'] as num? ?? 3).toInt();
          final free = (item['FreeSpace'] as num? ?? 0).toInt();
          final size = (item['Size'] as num? ?? 0).toInt();

          DriveKind kind;
          switch (typeInt) {
            case 2:
              kind = DriveKind.removable;
              break;
            case 3:
              kind = DriveKind.localFixed;
              break;
            case 4:
              kind = DriveKind.network;
              break;
            default:
              kind = DriveKind.unknown;
          }

          resultDrives.add(
            DriveSpaceInfo(
              letter: id,
              label: label,
              driveKind: kind,
              totalBytes: size,
              freeBytes: free,
            ),
          );
        }
      }
    } catch (e) {
      _logger.warning('Failed to query drives via CIM: $e');
    }

    // Sort drives: C: first, then alphabetically
    resultDrives.sort((a, b) {
      if (a.isSystemDrive) return -1;
      if (b.isSystemDrive) return 1;
      return a.letter.compareTo(b.letter);
    });

    _drives = resultDrives;
    _lastDrivesRefresh = DateTime.now();
    if (!_disposed) notifyListeners();
    return _drives;
  }

  /// Open drive root in Windows File Explorer
  Future<void> openDriveInExplorer(String driveLetter) async {
    if (!Platform.isWindows) return;
    try {
      final cleaned = driveLetter.replaceAll('/', '\\');
      final target = cleaned.endsWith('\\') ? cleaned : '$cleaned\\';
      await Process.run('explorer.exe', [target]);
    } catch (e) {
      _logger.warning('Failed to open $driveLetter in Explorer: $e');
    }
  }

  /// Compute storage savings for all active symlinks
  Future<StorageSavingsSummary> calculateSavings(
    List<SymlinkEntry> entries, {
    bool forceRefresh = false,
  }) async {
    final revision = ++_scanRevision;
    final activeEntries = entries.where((e) => e.isActive).toList()
      ..sort(
        (a, b) => _normalizeKey(
          a.targetPath,
        ).length.compareTo(_normalizeKey(b.targetPath).length),
      );
    final counted = <String>[];
    final countedC = <String>[];
    bool covered(String key, List<String> roots) =>
        roots.any((root) => key == root || p.windows.isWithin(root, key));
    if (activeEntries.isEmpty) {
      _savings = StorageSavingsSummary.empty;
      _isScanning = false;
      if (!_disposed) notifyListeners();
      return _savings;
    }

    _isScanning = true;
    if (!_disposed) notifyListeners();

    int totalSaved = 0;
    int savedOnC = 0;
    int totalFiles = 0;
    final perDrive = <String, int>{};

    try {
      for (final entry in activeEntries) {
        final key = _normalizeKey(entry.targetPath);
        SymlinkStorageStat? stat = _statsCache[key];

        // Recalculate if cache expired (> 5 min) or forceRefresh
        final isCacheValid =
            stat != null &&
            !forceRefresh &&
            DateTime.now().difference(stat.lastScanned).inMinutes < 5;

        if (!isCacheValid) {
          final result = await measureTarget(entry.targetPath);
          if (_disposed || revision != _scanRevision) return _savings;
          final sizeBytes = result.$1;
          final fileCount = result.$2;

          final isOffloadedFromC =
              entry.linkPath.toUpperCase().startsWith('C:') &&
              !entry.targetPath.toUpperCase().startsWith('C:');

          stat = SymlinkStorageStat(
            linkPath: entry.linkPath,
            targetPath: entry.targetPath,
            sizeBytes: sizeBytes,
            fileCount: fileCount,
            isOffloadedFromC: isOffloadedFromC,
            lastScanned: DateTime.now(),
          );
          _statsCache[key] = stat;
        }

        final unique = !covered(key, counted);
        if (unique) {
          counted.add(key);
          totalSaved += stat.sizeBytes;
          totalFiles += stat.fileCount;
        }

        final fromC =
            p.windows.rootPrefix(entry.linkPath).toUpperCase() == 'C:\\' &&
            p.windows.rootPrefix(entry.targetPath).toUpperCase() != 'C:\\';
        if (fromC && !covered(key, countedC)) {
          countedC.add(key);
          savedOnC += stat.sizeBytes;
        }

        // Tally per destination drive
        if (unique &&
            entry.targetPath.length >= 2 &&
            entry.targetPath[1] == ':') {
          final driveLetter = entry.targetPath.substring(0, 2).toUpperCase();
          perDrive[driveLetter] = (perDrive[driveLetter] ?? 0) + stat.sizeBytes;
        }
      }

      _savings = StorageSavingsSummary(
        totalSavedBytes: totalSaved,
        totalSavedOnCBytes: savedOnC,
        activeLinkCount: activeEntries.length,
        totalFileCount: totalFiles,
        perDriveSavings: perDrive,
      );
    } catch (e) {
      _logger.warning('Error calculating storage savings: $e');
    } finally {
      if (!_disposed && revision == _scanRevision) {
        _isScanning = false;
        notifyListeners();
      }
    }

    return _savings;
  }

  /// Full refresh of both drives and storage savings
  Future<void> refreshAll(
    List<SymlinkEntry> entries, {
    bool forceScan = false,
  }) async {
    await getLogicalDrives(forceRefresh: true);
    await calculateSavings(entries, forceRefresh: forceScan);
  }

  String _normalizeKey(String path) {
    return p.windows.normalize(path.trim().toLowerCase().replaceAll('/', '\\'));
  }
}
