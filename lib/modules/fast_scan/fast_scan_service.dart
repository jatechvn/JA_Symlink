// lib/modules/fast_scan/fast_scan_service.dart
// Service for ultra-fast drive scanning with native MFT/USN engine and fallback

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'fast_scan_model.dart';

final _logger = Logger('FastScanService');

// FFI Typedefs
typedef _FastScanDriveNative =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> driveLetter);
typedef _FastScanDriveDart =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> driveLetter);

typedef _FastScanSubfoldersNative =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> folderPath);
typedef _FastScanSubfoldersDart =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> folderPath);

typedef _FastScanFreeNative = ffi.Void Function(ffi.Pointer<Utf8> ptr);
typedef _FastScanFreeDart = void Function(ffi.Pointer<Utf8> ptr);

/// Background isolate worker for fallback Dart scanning if native DLL is unavailable
Map<String, dynamic> _fallbackScanWorker(String driveLetter) {
  final stopwatch = Stopwatch()..start();
  final cleanDrive = driveLetter.replaceAll('\\', '').replaceAll('/', '');
  final rootPath = '$cleanDrive\\';
  final dir = Directory(rootPath);

  if (!dir.existsSync()) {
    return {
      'success': false,
      'error': 'Drive $rootPath does not exist',
      'duration_ms': 0,
      'total_files': 0,
      'total_directories': 0,
      'total_bytes': 0,
      'top_folders': <Map<String, dynamic>>[],
      'is_mft': false,
    };
  }

  int totalFiles = 0;
  int totalDirs = 0;
  int totalBytes = 0;
  final Map<String, (int, int, int)> folderMetrics = {};

  try {
    // Scan level 1 and 2 directories for top candidates
    final entries = dir.listSync(followLinks: false);
    for (final entry in entries) {
      if (entry is Directory) {
        totalDirs++;
        int dirBytes = 0;
        int dirFiles = 0;
        int subDirs = 0;

        try {
          final subEntities = entry.listSync(
            recursive: true,
            followLinks: false,
          );
          for (final sub in subEntities) {
            if (sub is File) {
              try {
                final len = sub.lengthSync();
                dirBytes += len;
                dirFiles++;
              } catch (_) {}
            } else if (sub is Directory) {
              subDirs++;
            }
          }
        } catch (_) {}

        folderMetrics[entry.path] = (dirBytes, dirFiles, subDirs);
        totalBytes += dirBytes;
        totalFiles += dirFiles;
      } else if (entry is File) {
        try {
          final len = entry.lengthSync();
          totalBytes += len;
          totalFiles++;
        } catch (_) {}
      }
    }
  } catch (e) {
    _logger.fine('Fallback scan partial read error: $e');
  }

  stopwatch.stop();

  // Sort folders by size descending
  final sortedFolders = folderMetrics.entries.toList()
    ..sort((a, b) => b.value.$1.compareTo(a.value.$1));

  final topFolders = sortedFolders.take(30).map((e) {
    return {
      'path': e.key,
      'size_bytes': e.value.$1,
      'file_count': e.value.$2,
      'folder_count': e.value.$3,
    };
  }).toList();

  return {
    'success': true,
    'duration_ms': stopwatch.elapsedMilliseconds,
    'total_files': totalFiles,
    'total_directories': totalDirs,
    'total_bytes': totalBytes,
    'top_folders': topFolders,
    'is_mft': false,
  };
}

/// Service orchestrating high-speed disk scanning using the native Rust MFT engine
class FastScanService extends ChangeNotifier {
  DriveScanResult? _currentResult;
  bool _isScanning = false;
  String? _activeDrive;
  bool _nativeLoaded = false;
  ffi.DynamicLibrary? _dylib;

  _FastScanDriveDart? _fastScanDrive;
  _FastScanSubfoldersDart? _fastScanSubfolders;
  _FastScanFreeDart? _fastScanFree;
  final Map<String, List<FolderTreeNode>> _subfolderCache = {};

  FastScanService() {
    _initNative();
  }

  DriveScanResult? get currentResult => _currentResult;
  bool get isScanning => _isScanning;
  String? get activeDrive => _activeDrive;
  bool get isNativeAvailable => _nativeLoaded;

  /// Attempt to locate and link the native Rust DLL
  void _initNative() {
    if (!Platform.isWindows) return;

    final candidatePaths = [
      // 1. Next to current executable (Production distribution)
      p.join(p.dirname(Platform.resolvedExecutable), 'ja_fast_scan.dll'),
      // 2. Current working directory
      p.join(Directory.current.path, 'ja_fast_scan.dll'),
      // 3. Rust release target directory (Local development)
      p.join(
        Directory.current.path,
        'rust_core',
        'target',
        'release',
        'ja_fast_scan.dll',
      ),
      // 4. Rust debug target directory
      p.join(
        Directory.current.path,
        'rust_core',
        'target',
        'debug',
        'ja_fast_scan.dll',
      ),
    ];

    for (final path in candidatePaths) {
      if (File(path).existsSync()) {
        try {
          _dylib = ffi.DynamicLibrary.open(path);
          _fastScanDrive = _dylib!
              .lookupFunction<_FastScanDriveNative, _FastScanDriveDart>(
                'fast_scan_drive',
              );
          _fastScanSubfolders = _dylib!
              .lookupFunction<
                _FastScanSubfoldersNative,
                _FastScanSubfoldersDart
              >('fast_scan_subfolders');
          _fastScanFree = _dylib!
              .lookupFunction<_FastScanFreeNative, _FastScanFreeDart>(
                'fast_scan_free_string',
              );
          _nativeLoaded = true;
          _logger.info('Successfully loaded native fast scanner from: $path');
          break;
        } catch (e) {
          _logger.warning('Failed loading native library at $path: $e');
        }
      }
    }

    if (!_nativeLoaded) {
      _logger.info(
        'Native fast scanner DLL not found; fallback engine will be used.',
      );
    }
  }

  /// Perform a high-speed disk scan on the specified drive (e.g. "C:" or "D:")
  Future<DriveScanResult> scanDrive(String driveLetter) async {
    if (_isScanning) {
      return _currentResult ?? DriveScanResult.empty(driveLetter);
    }

    final cleanDrive = driveLetter
        .replaceAll('\\', '')
        .replaceAll('/', '')
        .toUpperCase();
    _isScanning = true;
    _activeDrive = cleanDrive;
    notifyListeners();

    try {
      if (_nativeLoaded && _fastScanDrive != null && _fastScanFree != null) {
        // Native MFT / USN engine path
        final result = await compute(_runNativeScanWorker, {
          'dll_path': p.join(
            p.dirname(Platform.resolvedExecutable),
            'ja_fast_scan.dll',
          ),
          'fallback_dll_paths': [
            p.join(Directory.current.path, 'ja_fast_scan.dll'),
            p.join(
              Directory.current.path,
              'rust_core',
              'target',
              'release',
              'ja_fast_scan.dll',
            ),
            p.join(
              Directory.current.path,
              'rust_core',
              'target',
              'debug',
              'ja_fast_scan.dll',
            ),
          ],
          'drive': cleanDrive,
        });

        _currentResult = DriveScanResult.fromJson(result, cleanDrive);
      } else {
        // Fallback isolate scanner
        final result = await compute(_fallbackScanWorker, cleanDrive);
        _currentResult = DriveScanResult.fromJson(result, cleanDrive);
      }
    } catch (e, st) {
      _logger.severe('Scan error for drive $cleanDrive: $e\n$st');
      _currentResult = DriveScanResult.failure(cleanDrive, e.toString());
    } finally {
      _isScanning = false;
      _activeDrive = null;
      notifyListeners();
    }

    return _currentResult!;
  }

  /// Loads direct subfolders for an expanded tree node, using caching and background isolate
  Future<List<FolderTreeNode>> loadSubfolders(
    String folderPath, {
    required String driveLetter,
    int depth = 1,
  }) async {
    final cleanPath = folderPath.trim();
    if (_subfolderCache.containsKey(cleanPath)) {
      return _subfolderCache[cleanPath]!;
    }

    final cleanDrive = driveLetter
        .replaceAll('\\', '')
        .replaceAll('/', '')
        .toUpperCase();

    try {
      Map<String, dynamic> result;
      if (_nativeLoaded &&
          _fastScanSubfolders != null &&
          _fastScanFree != null) {
        result = await compute(_runNativeSubfolderWorker, {
          'dll_path': p.join(
            p.dirname(Platform.resolvedExecutable),
            'ja_fast_scan.dll',
          ),
          'fallback_dll_paths': [
            p.join(Directory.current.path, 'ja_fast_scan.dll'),
            p.join(
              Directory.current.path,
              'rust_core',
              'target',
              'release',
              'ja_fast_scan.dll',
            ),
            p.join(
              Directory.current.path,
              'rust_core',
              'target',
              'debug',
              'ja_fast_scan.dll',
            ),
          ],
          'path': cleanPath,
        });
      } else {
        result = await compute(_fallbackSubfolderWorker, cleanPath);
      }

      final subRaw = result['subfolders'] as List<dynamic>? ?? const [];
      final list = subRaw.map((item) {
        return FolderTreeNode.fromJson(
          item as Map<String, dynamic>,
          drive: cleanDrive,
          depth: depth,
        );
      }).toList();

      _subfolderCache[cleanPath] = list;
      return list;
    } catch (e, st) {
      _logger.warning('Failed to load subfolders for $cleanPath: $e\n$st');
      return const [];
    }
  }

  /// Clear the current scan results and cache
  void clearResults() {
    _currentResult = null;
    _subfolderCache.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _dylib?.close();
    super.dispose();
  }
}

/// Standalone background isolate worker for executing native C-ABI scan
Map<String, dynamic> _runNativeScanWorker(Map<String, dynamic> params) {
  final drive = params['drive'] as String;
  final dllPath = params['dll_path'] as String;
  final fallbackPaths = (params['fallback_dll_paths'] as List<dynamic>)
      .cast<String>();

  ffi.DynamicLibrary? lib;
  final allPaths = [dllPath, ...fallbackPaths];
  for (final path in allPaths) {
    if (File(path).existsSync()) {
      try {
        lib = ffi.DynamicLibrary.open(path);
        break;
      } catch (_) {}
    }
  }

  if (lib == null) {
    // Fallback if DLL load failed inside worker
    return _fallbackScanWorker(drive);
  }

  final scanFn = lib.lookupFunction<_FastScanDriveNative, _FastScanDriveDart>(
    'fast_scan_drive',
  );
  final freeFn = lib.lookupFunction<_FastScanFreeNative, _FastScanFreeDart>(
    'fast_scan_free_string',
  );

  final drivePtr = drive.toNativeUtf8();
  try {
    final resultPtr = scanFn(drivePtr);
    if (resultPtr == ffi.nullptr) {
      return _fallbackScanWorker(drive);
    }

    final jsonStr = resultPtr.toDartString();
    freeFn(resultPtr);

    return jsonDecode(jsonStr) as Map<String, dynamic>;
  } catch (_) {
    return _fallbackScanWorker(drive);
  } finally {
    malloc.free(drivePtr);
    lib.close();
  }
}

/// Standalone background isolate worker for executing native subfolder scan
Map<String, dynamic> _runNativeSubfolderWorker(Map<String, dynamic> params) {
  final path = params['path'] as String;
  final dllPath = params['dll_path'] as String;
  final fallbackPaths = (params['fallback_dll_paths'] as List<dynamic>)
      .cast<String>();

  ffi.DynamicLibrary? lib;
  final allPaths = [dllPath, ...fallbackPaths];
  for (final candidate in allPaths) {
    if (File(candidate).existsSync()) {
      try {
        lib = ffi.DynamicLibrary.open(candidate);
        break;
      } catch (_) {}
    }
  }

  if (lib == null) {
    return _fallbackSubfolderWorker(path);
  }

  final subFn = lib
      .lookupFunction<_FastScanSubfoldersNative, _FastScanSubfoldersDart>(
        'fast_scan_subfolders',
      );
  final freeFn = lib.lookupFunction<_FastScanFreeNative, _FastScanFreeDart>(
    'fast_scan_free_string',
  );

  final pathPtr = path.toNativeUtf8();
  try {
    final resultPtr = subFn(pathPtr);
    if (resultPtr == ffi.nullptr) {
      return _fallbackSubfolderWorker(path);
    }

    final jsonStr = resultPtr.toDartString();
    freeFn(resultPtr);

    return jsonDecode(jsonStr) as Map<String, dynamic>;
  } catch (_) {
    return _fallbackSubfolderWorker(path);
  } finally {
    malloc.free(pathPtr);
    lib.close();
  }
}

/// Standalone background isolate worker for fallback subfolder traversal
Map<String, dynamic> _fallbackSubfolderWorker(String folderPath) {
  final dir = Directory(folderPath);
  if (!dir.existsSync()) {
    return {
      'success': false,
      'parent_path': folderPath,
      'duration_ms': 0,
      'subfolders': <Map<String, dynamic>>[],
      'error': 'Directory does not exist',
    };
  }

  final stopwatch = Stopwatch()..start();
  final List<Map<String, dynamic>> subfolders = [];
  int directFilesBytes = 0;
  int directFilesCount = 0;

  try {
    final entries = dir.listSync(followLinks: false);
    for (final entry in entries) {
      if (entry is Directory) {
        int dirBytes = 0;
        int dirFiles = 0;
        int subDirs = 0;
        try {
          final subEntities = entry.listSync(
            recursive: true,
            followLinks: false,
          );
          for (final sub in subEntities) {
            if (sub is File) {
              try {
                dirBytes += sub.lengthSync();
                dirFiles++;
              } catch (_) {}
            } else if (sub is Directory) {
              subDirs++;
            }
          }
        } catch (_) {}

        subfolders.add({
          'name': p.basename(entry.path),
          'path': entry.path,
          'size_bytes': dirBytes,
          'file_count': dirFiles,
          'folder_count': subDirs,
          'has_children': subDirs > 0,
        });
      } else if (entry is File) {
        try {
          directFilesBytes += entry.lengthSync();
          directFilesCount++;
        } catch (_) {}
      }
    }
  } catch (e) {
    _logger.fine('Fallback subfolders read error: $e');
  }

  subfolders.sort(
    (a, b) => (b['size_bytes'] as int).compareTo(a['size_bytes'] as int),
  );

  if (directFilesCount > 0) {
    subfolders.add({
      'name': '[Files]',
      'path': folderPath,
      'size_bytes': directFilesBytes,
      'file_count': directFilesCount,
      'folder_count': 0,
      'has_children': false,
    });
    subfolders.sort(
      (a, b) => (b['size_bytes'] as int).compareTo(a['size_bytes'] as int),
    );
  }

  stopwatch.stop();
  return {
    'success': true,
    'parent_path': folderPath,
    'duration_ms': stopwatch.elapsedMilliseconds,
    'subfolders': subfolders,
  };
}
