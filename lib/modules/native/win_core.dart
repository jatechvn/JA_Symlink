// lib/modules/native/win_core.dart
// Windows-specific native operations for symlink management

import 'dart:io';
import 'package:logging/logging.dart';
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

  /// Create a directory symlink using Dart native Link API
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

      // Create symlink using Dart Link API
      final link = Link(linkPath);
      link.createSync(targetPath);

      _logger.info('Symlink created: $linkPath -> $targetPath');
      return SymlinkResult(
        success: true,
        message: 'Symlink created successfully',
      );
    } catch (e) {
      _logger.severe('Create symlink error: $e');
      return SymlinkResult(success: false, message: 'Error: $e');
    }
  }

  /// Remove a symlink using Dart native Link API (does NOT delete target data)
  static Future<SymlinkResult> removeSymlink(String linkPath) async {
    try {
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

      _logger.info('Symlink removed: $linkPath');
      return SymlinkResult(
        success: true,
        message: 'Symlink removed successfully',
      );
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
  /// Implemented with the Dart file APIs rather than `cmd /c dir /A:LD /S`:
  /// shelling out both exposed the path to command injection and forced parsing
  /// of `dir` output, whose headings are localized (and therefore unparseable on
  /// a non-English Windows install).
  static Future<List<Map<String, String>>> scanSymlinks(
    String searchPath,
  ) async {
    if (searchPath.trim().isEmpty) return const [];
    final results = <Map<String, String>>[];
    await _collectSymlinks(Directory(searchPath), results, 0);
    return results;
  }

  /// Walks [dir] one level, recording links and descending into real directories.
  ///
  /// Links are never followed, so a symlink pointing at one of its own ancestors
  /// cannot send the walk into an infinite loop.
  static Future<void> _collectSymlinks(
    Directory dir,
    List<Map<String, String>> out,
    int depth,
  ) async {
    if (depth > _maxScanDepth) return;

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
          await _collectSymlinks(Directory(entity.path), out, depth + 1);
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

/// Result of a symlink operation
class SymlinkResult {
  final bool success;
  final String message;

  SymlinkResult({required this.success, required this.message});

  @override
  String toString() => 'SymlinkResult(success=$success, message=$message)';
}
