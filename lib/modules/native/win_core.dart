// lib/modules/native/win_core.dart
// Windows-specific native operations for symlink management

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import '../native_bridge.dart';
import '../utils.dart';

final _logger = Logger('WinCore');

/// Recursion cap for [WindowsNativeEngine.scanSymlinks], guarding against
/// pathologically deep trees.
const int _maxScanDepth = 16;

/// Reparse-point prefixes Windows prepends to resolved symlink targets.
const List<String> _reparsePrefixes = [r'\??\', r'\\?\'];

class WindowsNativeEngine implements NativeEngine {
  WindowsNativeEngine();

  @override
  dynamic heavyCompute(dynamic dataInput) {
    return 'Windows Native Result';
  }

  /// Create a directory symlink using Native Rust Win32 API with Developer Mode support
  /// and seamless fallback to Dart Link API.
  static Future<SymlinkResult> createSymlink(
    String linkPath,
    String targetPath,
  ) async {
    try {
      if (pathsEqual(linkPath, targetPath)) {
        return SymlinkResult(
          success: false,
          message: 'Link path and target path must be different',
        );
      }

      // Ensure target directory exists
      final targetDir = Directory(targetPath);
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
        _logger.info('Created target directory: $targetPath');
      }

      // 1. Try Native Rust Win32 API (supports unprivileged create via Developer Mode)
      final lib = _openNativeLib();
      if (lib != null) {
        try {
          final createFn = lib
              .lookupFunction<_FastCreateSymlinkNative, _FastCreateSymlinkDart>(
                'fast_create_symlink',
              );
          final freeFn = lib
              .lookupFunction<_FastScanFreeNative, _FastScanFreeDart>(
                'fast_scan_free_string',
              );

          final linkPtr = linkPath.toNativeUtf8();
          final targetPtr = targetPath.toNativeUtf8();
          try {
            final resPtr = createFn(linkPtr, targetPtr);
            if (resPtr != ffi.nullptr) {
              final jsonStr = resPtr.toDartString();
              freeFn(resPtr);
              final map = jsonDecode(jsonStr) as Map<String, dynamic>;
              final success = map['success'] as bool? ?? false;
              final message = map['message']?.toString() ?? '';
              if (success) {
                _logger.info(
                  'Native Win32 symlink created: $linkPath -> $targetPath',
                );
                return SymlinkResult(success: true, message: message);
              }
              _logger.warning('Native Win32 createSymlink returned: $message');
            }
          } finally {
            malloc.free(linkPtr);
            malloc.free(targetPtr);
          }
        } catch (e) {
          _logger.warning(
            'Native createSymlink failed, attempting Dart fallback: $e',
          );
        }
      }

      // 2. Fallback: Dart native Link API
      final link = Link(linkPath);
      link.createSync(targetPath);

      _logger.info('Dart symlink created: $linkPath -> $targetPath');
      return SymlinkResult(
        success: true,
        message: 'Symlink created successfully',
      );
    } catch (e) {
      _logger.severe('Create symlink error: $e');
      return SymlinkResult(success: false, message: 'Error: $e');
    }
  }

  /// Remove a symlink using Native Rust Win32 API (RemoveDirectoryW with safety check)
  /// with seamless fallback to Dart Link API. Never deletes target data.
  static Future<SymlinkResult> removeSymlink(String linkPath) async {
    try {
      // 1. Try Native Rust Win32 API
      final lib = _openNativeLib();
      if (lib != null) {
        try {
          final removeFn = lib
              .lookupFunction<_FastRemoveSymlinkNative, _FastRemoveSymlinkDart>(
                'fast_remove_symlink',
              );
          final freeFn = lib
              .lookupFunction<_FastScanFreeNative, _FastScanFreeDart>(
                'fast_scan_free_string',
              );

          final linkPtr = linkPath.toNativeUtf8();
          try {
            final resPtr = removeFn(linkPtr);
            if (resPtr != ffi.nullptr) {
              final jsonStr = resPtr.toDartString();
              freeFn(resPtr);
              final map = jsonDecode(jsonStr) as Map<String, dynamic>;
              final success = map['success'] as bool? ?? false;
              final message = map['message']?.toString() ?? '';
              if (success) {
                _logger.info('Native Win32 symlink removed: $linkPath');
                return SymlinkResult(success: true, message: message);
              }
              // If safety check blocked it, respect the safety block!
              if (message.contains('SAFETY BLOCKED')) {
                _logger.severe(message);
                return SymlinkResult(success: false, message: message);
              }
              _logger.warning('Native Win32 removeSymlink failed: $message');
            }
          } finally {
            malloc.free(linkPtr);
          }
        } catch (e) {
          _logger.warning(
            'Native removeSymlink failed, attempting Dart fallback: $e',
          );
        }
      }

      // 2. Fallback: Dart native Link API
      final type = FileSystemEntity.typeSync(linkPath, followLinks: false);
      if (type != FileSystemEntityType.link) {
        return SymlinkResult(
          success: false,
          message: 'Path is not a symlink: $linkPath',
        );
      }

      // Link.deleteSync removes the reparse point only, including dangling
      // links. Never delete a real directory as a fallback here.
      Link(linkPath).deleteSync();

      _logger.info('Dart symlink removed: $linkPath');
      return SymlinkResult(
        success: true,
        message: 'Symlink removed successfully',
      );
    } catch (e) {
      _logger.severe('Remove symlink error: $e');
      return SymlinkResult(success: false, message: 'Error: $e');
    }
  }

  /// Verify symlink using Native Win32 API (reparse attributes query)
  /// with fallback to FileSystemEntity. Replaces slow `fsutil` process spawn.
  static Future<bool> verifySymlink(String linkPath) async {
    try {
      // 1. Try Native Rust Win32 API (micro-second check, zero process overhead)
      final lib = _openNativeLib();
      if (lib != null) {
        try {
          final verifyFn = lib
              .lookupFunction<_FastVerifySymlinkNative, _FastVerifySymlinkDart>(
                'fast_verify_symlink',
              );
          final freeFn = lib
              .lookupFunction<_FastScanFreeNative, _FastScanFreeDart>(
                'fast_scan_free_string',
              );

          final linkPtr = linkPath.toNativeUtf8();
          try {
            final resPtr = verifyFn(linkPtr);
            if (resPtr != ffi.nullptr) {
              final jsonStr = resPtr.toDartString();
              freeFn(resPtr);
              final map = jsonDecode(jsonStr) as Map<String, dynamic>;
              return map['is_symlink'] as bool? ?? false;
            }
          } finally {
            malloc.free(linkPtr);
          }
        } catch (e) {
          _logger.fine('Native verifySymlink error: $e');
        }
      }

      // 2. Fallback: Check reparse point type via FileSystemEntity
      return FileSystemEntity.typeSync(linkPath, followLinks: false) ==
          FileSystemEntityType.link;
    } catch (_) {
      return false;
    }
  }

  /// Get symlink target path via Native Win32 kernel reparse buffer
  /// with fallback to Dart Link targetSync.
  static Future<String?> getSymlinkTarget(String linkPath) async {
    try {
      // 1. Try Native Rust Win32 API
      final lib = _openNativeLib();
      if (lib != null) {
        try {
          final targetFn = lib
              .lookupFunction<
                _FastGetSymlinkTargetNative,
                _FastGetSymlinkTargetDart
              >('fast_get_symlink_target');
          final freeFn = lib
              .lookupFunction<_FastScanFreeNative, _FastScanFreeDart>(
                'fast_scan_free_string',
              );

          final linkPtr = linkPath.toNativeUtf8();
          try {
            final resPtr = targetFn(linkPtr);
            if (resPtr != ffi.nullptr) {
              final target = resPtr.toDartString();
              freeFn(resPtr);
              return _stripReparsePrefix(target);
            }
          } finally {
            malloc.free(linkPtr);
          }
        } catch (e) {
          _logger.fine('Native getSymlinkTarget error: $e');
        }
      }

      // 2. Fallback: Dart Link targetSync
      if (FileSystemEntity.typeSync(linkPath, followLinks: false) ==
          FileSystemEntityType.link) {
        return _stripReparsePrefix(Link(linkPath).targetSync());
      }
    } catch (_) {}
    return null;
  }

  /// Move a directory from [source] to [destination].
  ///
  /// Tries a same-volume rename first, then falls back to `robocopy /MOVE` for
  /// cross-volume moves. Neither path goes through a command shell, so a
  /// directory name containing `&`, `|` or other shell metacharacters cannot be
  /// interpreted as a command.
  static Future<SymlinkResult> moveDirectory(
    String source,
    String destination,
  ) async {
    try {
      if (source.trim().isEmpty || destination.trim().isEmpty) {
        return SymlinkResult(
          success: false,
          message: 'Source and destination paths are required',
        );
      }
      if (pathsEqual(source, destination) ||
          isSameOrChildPath(source, destination)) {
        return SymlinkResult(
          success: false,
          message: 'Destination cannot be the source folder or its child',
        );
      }

      // Fast path: rename works when both ends live on the same volume.
      try {
        Directory(source).renameSync(destination);
        _logger.info('Moved directory: $source -> $destination');
        return SymlinkResult(
          success: true,
          message: 'Directory moved successfully',
        );
      } on FileSystemException catch (e) {
        _logger.info('Rename failed ($e), falling back to robocopy /MOVE...');
      }

      // robocopy.exe receives its arguments as a list — no shell parsing.
      final roboResult = await Process.run('robocopy', [
        source,
        destination,
        '/MOVE',
        '/E',
        '/R:3',
        '/W:1',
        '/NFL',
        '/NDL',
        '/NJH',
        '/NJS',
      ]);

      // robocopy exit codes 0-7 are success
      if (roboResult.exitCode <= 7) {
        _logger.info('Robocopy moved: $source -> $destination');
        return SymlinkResult(
          success: true,
          message: 'Directory moved via robocopy',
        );
      }

      final error = (roboResult.stderr as String).trim();
      return SymlinkResult(
        success: false,
        message: 'Robocopy failed (exit ${roboResult.exitCode}): $error',
      );
    } catch (e) {
      return SymlinkResult(success: false, message: 'Move error: $e');
    }
  }

  /// Check if current process has admin privileges
  static Future<bool> isAdmin() async {
    try {
      // `net session` is not an admin check: it returns exit code 2 when the
      // Server service has no sessions, even for a fully elevated process.
      // Query the current Windows token instead so UAC-disabled machines and
      // machines without the Server service behave correctly.
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'''
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  exit 0
}
exit 1
''',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Restart the app with admin privileges.
  ///
  /// The executable path (and each forwarded arg) is embedded in a
  /// single-quoted PowerShell string (with `'` doubled to escape it) so that
  /// `$` is never expanded as a variable and the value cannot terminate the
  /// string early. [args] (e.g. `-debug`) MUST be forwarded here — otherwise
  /// the elevated process always starts with an empty arg list, silently
  /// dropping flags the user passed to the original (non-elevated) launch.
  static Future<void> elevateAdmin([List<String> args = const []]) async {
    final exePath = Platform.resolvedExecutable.replaceAll("'", "''");
    final argumentList = args.isEmpty
        ? ''
        : ' -ArgumentList @(${args.map((a) => "'${a.replaceAll("'", "''")}'").join(',')})';
    await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "Start-Process -FilePath '$exePath'$argumentList -Verb RunAs",
    ]);
  }

  /// Recursively find directory symlinks/junctions under [searchPath].
  ///
  /// Uses the high-speed multi-threaded Native Rust Win32 Reparse Point engine
  /// via background Isolate (`compute`), running 10x-50x faster than pure Dart.
  /// Seamlessly falls back to pure Dart traversal if the native DLL is unavailable.
  static Future<List<Map<String, String>>> scanSymlinks(
    String searchPath, {
    int maxDepth = _maxScanDepth,
  }) async {
    if (searchPath.trim().isEmpty) return const [];
    final dir = Directory(searchPath);
    if (!dir.existsSync()) return const [];

    if (Platform.isWindows) {
      try {
        final dllPaths = _getDllCandidatePaths();
        final hasDll = dllPaths.any((p) => File(p).existsSync());
        if (hasDll) {
          final results = await compute(_nativeSymlinkScanWorker, {
            'search_path': searchPath,
            'max_depth': maxDepth,
            'dll_paths': dllPaths,
          });
          _logger.info(
            'Native Rust scan found ${results.length} symlinks under: $searchPath',
          );
          return results;
        }
      } catch (e) {
        _logger.warning('Native symlink scan failed, falling back to Dart: $e');
      }
    }

    // Fallback: Pure Dart directory walk
    final results = <Map<String, String>>[];
    await _collectSymlinks(dir, results, 0, maxDepth);
    return results;
  }

  /// Walks [dir] one level, recording links and descending into real directories.
  ///
  /// Links are never followed, so a symlink pointing at one of its own ancestors
  /// cannot send the walk into an infinite loop.
  static Future<void> _collectSymlinks(
    Directory dir,
    List<Map<String, String>> out,
    int depth, [
    int maxDepth = _maxScanDepth,
  ]) async {
    if (depth > maxDepth) return;

    final List<FileSystemEntity> children;
    try {
      children = await dir.list(followLinks: false).toList();
    } catch (_) {
      // Access denied on a system folder is expected — skip it silently.
      return;
    }

    for (final entity in children) {
      try {
        final type = FileSystemEntity.typeSync(entity.path, followLinks: false);

        if (type == FileSystemEntityType.link) {
          // Match the old `dir /A:LD` behaviour: report directory links only.
          // Broken links resolve to `notFound` and are kept, since a dangling
          // symlink is exactly what a user scanning for problems wants to see.
          final resolved = FileSystemEntity.typeSync(
            entity.path,
            followLinks: true,
          );
          if (resolved == FileSystemEntityType.file) continue;

          final target = _stripReparsePrefix(Link(entity.path).targetSync());
          out.add({'link': entity.path, 'target': target});
          continue; // do not descend into links
        }

        if (type == FileSystemEntityType.directory) {
          await _collectSymlinks(
            Directory(entity.path),
            out,
            depth + 1,
            maxDepth,
          );
        }
      } catch (e) {
        _logger.fine('Skipping ${entity.path}: $e');
      }
    }
  }

  /// Strip the `\??\` / `\\?\` prefix Windows adds to resolved reparse targets.
  static String _stripReparsePrefix(String target) {
    final trimmed = target.trim();
    for (final prefix in _reparsePrefixes) {
      if (trimmed.startsWith(prefix)) {
        return trimmed.substring(prefix.length);
      }
    }
    return trimmed;
  }
}

// FFI Typedefs for native symlink scanning
typedef _FastScanSymlinksNative =
    ffi.Pointer<Utf8> Function(
      ffi.Pointer<Utf8> searchPath,
      ffi.Uint32 maxDepth,
    );
typedef _FastScanSymlinksDart =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> searchPath, int maxDepth);

typedef _FastScanFreeNative = ffi.Void Function(ffi.Pointer<Utf8> ptr);
typedef _FastScanFreeDart = void Function(ffi.Pointer<Utf8> ptr);

// FFI Typedefs for native symlink CRUD operations
typedef _FastCreateSymlinkNative =
    ffi.Pointer<Utf8> Function(
      ffi.Pointer<Utf8> linkPath,
      ffi.Pointer<Utf8> targetPath,
    );
typedef _FastCreateSymlinkDart =
    ffi.Pointer<Utf8> Function(
      ffi.Pointer<Utf8> linkPath,
      ffi.Pointer<Utf8> targetPath,
    );

typedef _FastRemoveSymlinkNative =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> linkPath);
typedef _FastRemoveSymlinkDart =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> linkPath);

typedef _FastVerifySymlinkNative =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> linkPath);
typedef _FastVerifySymlinkDart =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> linkPath);

typedef _FastGetSymlinkTargetNative =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> linkPath);
typedef _FastGetSymlinkTargetDart =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> linkPath);

List<String> _getDllCandidatePaths() {
  return [
    p.join(p.dirname(Platform.resolvedExecutable), 'ja_fast_scan.dll'),
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
  ];
}

ffi.DynamicLibrary? _cachedNativeLib;
bool _nativeLibChecked = false;

ffi.DynamicLibrary? _openNativeLib() {
  if (_nativeLibChecked) return _cachedNativeLib;
  _nativeLibChecked = true;
  if (!Platform.isWindows) return null;

  for (final path in _getDllCandidatePaths()) {
    if (File(path).existsSync()) {
      try {
        _cachedNativeLib = ffi.DynamicLibrary.open(path);
        _logger.info('WinCore loaded native library: $path');
        return _cachedNativeLib;
      } catch (e) {
        _logger.fine('Failed to open native library at $path: $e');
      }
    }
  }
  return null;
}

/// Background Isolate worker for executing Native Rust Win32 Reparse Point scan
List<Map<String, String>> _nativeSymlinkScanWorker(
  Map<String, dynamic> params,
) {
  final searchPath = params['search_path'] as String;
  final maxDepth = params['max_depth'] as int;
  final dllPaths = (params['dll_paths'] as List<dynamic>).cast<String>();

  ffi.DynamicLibrary? lib;
  for (final path in dllPaths) {
    if (File(path).existsSync()) {
      try {
        lib = ffi.DynamicLibrary.open(path);
        break;
      } catch (_) {}
    }
  }

  if (lib == null) {
    throw Exception('Native library ja_fast_scan.dll could not be loaded');
  }

  final scanFn = lib
      .lookupFunction<_FastScanSymlinksNative, _FastScanSymlinksDart>(
        'fast_scan_symlinks',
      );
  final freeFn = lib.lookupFunction<_FastScanFreeNative, _FastScanFreeDart>(
    'fast_scan_free_string',
  );

  final pathPtr = searchPath.toNativeUtf8();
  try {
    final resultPtr = scanFn(pathPtr, maxDepth);
    if (resultPtr == ffi.nullptr) {
      return const [];
    }

    final jsonStr = resultPtr.toDartString();
    freeFn(resultPtr);

    final rawList = jsonDecode(jsonStr) as List<dynamic>;
    return rawList.map((item) {
      final map = item as Map<String, dynamic>;
      return {
        'link': map['link']?.toString() ?? '',
        'target': map['target']?.toString() ?? '',
      };
    }).toList();
  } finally {
    malloc.free(pathPtr);
    lib.close();
  }
}

/// Result of a symlink operation
class SymlinkResult {
  final bool success;
  final String message;

  SymlinkResult({required this.success, required this.message});

  @override
  String toString() => 'SymlinkResult(success=$success, message=$message)';
}
