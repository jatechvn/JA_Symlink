// lib/modules/native/win_core.dart
// Windows-specific native operations for symlink management

import 'dart:io';
import 'package:logging/logging.dart';
import '../native_bridge.dart';

final _logger = Logger('WinCore');

class WindowsNativeEngine implements NativeEngine {
  WindowsNativeEngine();

  @override
  dynamic heavyCompute(dynamic dataInput) {
    return 'Windows Native Result';
  }

  /// Create a directory symlink using Dart native Link API
  static Future<SymlinkResult> createSymlink(String linkPath, String targetPath) async {
    try {
      // Ensure target directory exists
      final targetDir = Directory(targetPath);
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
        _logger.info('Created target directory: $targetPath');
      }

      // Create symlink using Dart Link API
      final link = Link(linkPath);
      link.createSync(targetPath);

      _logger.info('Symlink created: $linkPath -> $targetPath');
      return SymlinkResult(success: true, message: 'Symlink created successfully');
    } catch (e) {
      _logger.severe('Create symlink error: $e');
      return SymlinkResult(success: false, message: 'Error: $e');
    }
  }
  /// Remove a symlink using Dart native Link API (does NOT delete target data)
  static Future<SymlinkResult> removeSymlink(String linkPath) async {
    try {
      final link = Link(linkPath);
      if (!link.existsSync()) {
        // Fallback: try as Directory (for junctions)
        final dir = Directory(linkPath);
        if (dir.existsSync()) {
          dir.deleteSync();
        } else {
          return SymlinkResult(success: false, message: 'Path does not exist: $linkPath');
        }
      } else {
        link.deleteSync();
      }

      _logger.info('Symlink removed: $linkPath');
      return SymlinkResult(success: true, message: 'Symlink removed successfully');
    } catch (e) {
      _logger.severe('Remove symlink error: $e');
      return SymlinkResult(success: false, message: 'Error: $e');
    }
  }


  /// Verify symlink using fsutil reparsepoint query
  static Future<bool> verifySymlink(String linkPath) async {
    try {
      final result = await Process.run('fsutil', [
        'reparsepoint',
        'query',
        linkPath,
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Move directory using robocopy /MOVE (more reliable than move command)
  static Future<SymlinkResult> moveDirectory(String source, String destination) async {
    try {
      // First try simple move
      final moveResult = await Process.run('cmd', [
        '/c',
        'move "$source" "$destination"',
      ]);

      if (moveResult.exitCode == 0) {
        _logger.info('Moved directory: $source -> $destination');
        return SymlinkResult(success: true, message: 'Directory moved successfully');
      }

      // Fallback to robocopy /MOVE
      _logger.info('Move failed, trying robocopy /MOVE...');
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
        return SymlinkResult(success: true, message: 'Directory moved via robocopy');
      } else {
        final error = (roboResult.stderr as String).trim();
        return SymlinkResult(success: false, message: 'Robocopy failed (exit ${roboResult.exitCode}): $error');
      }
    } catch (e) {
      return SymlinkResult(success: false, message: 'Move error: $e');
    }
  }

  /// Check if current process has admin privileges
  static Future<bool> isAdmin() async {
    try {
      final result = await Process.run('net', ['session'], runInShell: true);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Restart the app with admin privileges
  static Future<void> elevateAdmin() async {
    final exePath = Platform.resolvedExecutable;
    await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Start-Process',
      '"$exePath"',
      '-Verb',
      'RunAs',
    ]);
  }

  /// Scan for symlinks using dir /AL
  static Future<List<Map<String, String>>> scanSymlinks(String searchPath) async {
    final results = <Map<String, String>>[];
    try {
      final result = await Process.run('cmd', [
        '/c',
        'dir',
        '/A:LD',
        '/S',
        searchPath,
      ]);

      final output = result.stdout as String;
      if (output.isNotEmpty) {
        // Parse dir /A:LD /S output
        String currentDir = '';
        for (final line in output.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.contains('<SYMLINKD>') || trimmed.contains('<JUNCTION>')) {
            // Parse: DATE TIME <SYMLINKD> name [target]
            final symlinkMatch = RegExp(r'<(?:SYMLINKD|JUNCTION)>\s+(.+?)\s+\[(.+?)\]').firstMatch(trimmed);
            if (symlinkMatch != null) {
              final name = symlinkMatch.group(1)!.trim();
              String target = symlinkMatch.group(2)!.trim();
              if (target.startsWith(r'\\?\')) {
                target = target.substring(4);
              } else if (target.startsWith(r'\??\')) {
                target = target.substring(4);
              }
              results.add({
                'link': '$currentDir\\$name',
                'target': target,
              });
            }
          } else {
            final dirMatch = RegExp(r'(?:[Dd]irectory of|[Tt]hư mục của|[Rr]épertoire de)?\s*([a-zA-Z]:\\[^:\n\r]*?)(?:\s+的目录)?$').firstMatch(trimmed);
            if (dirMatch != null) {
              currentDir = dirMatch.group(1)!.trim();
            }
          }
        }
      }
    } catch (e) {
      _logger.warning('Scan symlinks error: $e');
    }
    return results;
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
