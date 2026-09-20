// lib/modules/process/process_lock_service.dart
// Service to detect and terminate processes locking specific directories.

import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'process_lock_model.dart';
import 'restart_manager_script.dart';

final _logger = Logger('ProcessLockService');

class ProcessLockService {
  static const String _envVar = 'JA_SYMLINK_LOCK_PATH';

  /// Find file-handle owners through Restart Manager plus loaded modules.
  Future<List<ProcessLockInfo>> findLockingProcesses(String dirPath) async {
    if (!Platform.isWindows || dirPath.trim().isEmpty) return const [];

    final dir = Directory(dirPath);
    if (!dir.existsSync()) return const [];

    try {
      final result = await Process.run(
        'powershell',
        const [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          restartManagerScript,
        ],
        environment: {_envVar: dirPath},
      );

      if (result.exitCode != 0) {
        _logger.warning(
          'Find locking processes exited with ${result.exitCode}',
        );
        throw ProcessException(
          'powershell',
          const [],
          '${result.stderr}',
          result.exitCode,
        );
      }

      final output = (result.stdout as String).trim();
      if (output.isEmpty || output == '[]') return const [];

      final decoded = jsonDecode(output);
      final list = decoded is List ? decoded : [decoded];

      final results = <ProcessLockInfo>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final info = ProcessLockInfo.fromJson(item);
          if (info.pid != pid && info.pid > 4) {
            results.add(info);
          }
        }
      }

      return results;
    } catch (e) {
      _logger.warning('Error querying locking processes: $e');
      rethrow;
    }
  }

  /// Terminate a list of process IDs safely using taskkill
  Future<bool> terminateProcesses(List<int> pids) async {
    if (pids.isEmpty) return true;

    bool allSuccess = true;
    for (final pId in pids) {
      if (pId == pid || pId <= 4) continue; // Don't kill self or System idle

      try {
        final res = await Process.run('taskkill', ['/F', '/PID', '$pId']);
        if (res.exitCode != 0) {
          allSuccess = false;
          _logger.warning('Failed to terminate PID $pId: ${res.stderr}');
        } else {
          _logger.info('Terminated process PID $pId');
        }
      } catch (e) {
        allSuccess = false;
        _logger.severe('Exception terminating PID $pId: $e');
      }
    }

    return allSuccess;
  }
}
