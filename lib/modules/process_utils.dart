// lib/modules/process_utils.dart
// Utilities for inspecting and killing processes that lock folders

import 'dart:io';
import 'package:logging/logging.dart';

final _logger = Logger('ProcessUtils');

/// Environment variable used to hand a user-supplied path to PowerShell without
/// ever letting it reach the PowerShell parser.
const String _lockPathEnvVar = 'JA_SYMLINK_LOCK_PATH';

/// Maximum number of top-level files probed by [ProcessKiller.isDirectoryLocked].
/// Bounded so the check stays fast on directories holding thousands of files.
const int _lockProbeFileLimit = 200;

/// PowerShell script that lists processes whose loaded modules live under the
/// directory named by [_lockPathEnvVar].
///
/// The path is read from the environment (`$env:...`) instead of being
/// interpolated into the script text, so a directory name containing quotes or
/// semicolons cannot break out of the string and inject arbitrary commands.
/// Wildcard metacharacters are escaped because `-like` treats them specially.
const String _lockingProcessesScript = r'''
$ErrorActionPreference = 'SilentlyContinue'
$path = $env:JA_SYMLINK_LOCK_PATH
if ([string]::IsNullOrWhiteSpace($path)) { return }
$pattern = [System.Management.Automation.WildcardPattern]::Escape($path) + '*'
Get-Process | Where-Object {
  $_.Modules | Where-Object { $_.FileName -like $pattern }
} | Select-Object -Property Id, ProcessName -Unique | ForEach-Object {
  Write-Output "$($_.Id)|$($_.ProcessName)"
}
''';

/// Find and kill processes locking a specific directory.
class ProcessKiller {
  /// Get list of processes with modules loaded from [dirPath].
  ///
  /// Each entry is formatted as `pid|processName`. Returns an empty list when
  /// nothing matches or the query fails.
  static Future<List<String>> getProcessesLocking(String dirPath) async {
    try {
      final result = await Process.run(
        'powershell',
        const [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          _lockingProcessesScript,
        ],
        // Passing the path through the environment keeps it out of the script
        // text entirely — the value is never parsed as PowerShell source.
        environment: {_lockPathEnvVar: dirPath},
      );

      if (result.exitCode != 0) {
        _logger.warning('Locking-process query exited with ${result.exitCode}');
        return const [];
      }

      final output = (result.stdout as String).trim();
      if (output.isEmpty) return const [];
      return output
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } catch (e) {
      _logger.warning('Failed to get locking processes: $e');
      return const [];
    }
  }

  /// Kill a process by name using taskkill.
  static Future<bool> killProcess(String processName) async {
    try {
      final result = await Process.run('taskkill', [
        '/F',
        '/IM',
        '$processName.exe',
      ]);
      _logger.info('Kill process $processName: exit=${result.exitCode}');
      return result.exitCode == 0;
    } catch (e) {
      _logger.severe('Failed to kill process $processName: $e');
      return false;
    }
  }

  /// Kill process by PID.
  static Future<bool> killProcessById(int pid) async {
    try {
      final result = await Process.run('taskkill', ['/F', '/PID', '$pid']);
      _logger.info('Kill PID $pid: exit=${result.exitCode}');
      return result.exitCode == 0;
    } catch (e) {
      _logger.severe('Failed to kill PID $pid: $e');
      return false;
    }
  }

  /// Heuristic check for whether [dirPath] holds files locked by another process.
  ///
  /// Probes up to [_lockProbeFileLimit] top-level files by opening each for
  /// append — a no-op that still requires the exclusive access a locking process
  /// would deny. This cannot see locks held on files in nested subdirectories,
  /// so a `false` result means "no lock detected", not "definitely unlocked".
  static Future<bool> isDirectoryLocked(String dirPath) async {
    final dir = Directory(dirPath);
    try {
      if (!dir.existsSync()) return false;
    } catch (e) {
      _logger.warning('Cannot stat $dirPath: $e');
      return false;
    }

    int probed = 0;
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! File) continue;
        if (probed >= _lockProbeFileLimit) break;
        probed++;

        RandomAccessFile? handle;
        try {
          handle = entity.openSync(mode: FileMode.append);
        } on FileSystemException catch (e) {
          _logger.info('Locked file detected in $dirPath: ${entity.path} ($e)');
          return true;
        } finally {
          try {
            handle?.closeSync();
          } catch (_) {}
        }
      }
    } catch (e) {
      // Listing itself failed — treat as locked so callers stay cautious.
      _logger.warning('Cannot enumerate $dirPath, assuming locked: $e');
      return true;
    }

    return false;
  }
}
