// lib/modules/process_utils.dart
// Utilities for killing processes that lock folders

import 'dart:io';
import 'package:logging/logging.dart';

final _logger = Logger('ProcessUtils');

/// Find and kill processes locking a specific directory
class ProcessKiller {
  /// Get list of processes using a directory path
  static Future<List<String>> getProcessesLocking(String dirPath) async {
    try {
      // Use PowerShell to find processes with handles in the directory
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '''
        \$path = '$dirPath'
        Get-Process | Where-Object {
          try {
            \$_.Modules | Where-Object { \$_.FileName -like "\$path*" }
          } catch {}
        } | Select-Object -Property Id, ProcessName -Unique | ForEach-Object {
          Write-Output "\$_.Id|\$_.ProcessName"
        }
        ''',
      ]);

      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        if (output.isEmpty) return [];
        return output.split('\n').where((l) => l.trim().isNotEmpty).toList();
      }
    } catch (e) {
      _logger.warning('Failed to get locking processes: $e');
    }
    return [];
  }

  /// Kill a process by name using taskkill
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

  /// Kill process by PID
  static Future<bool> killProcessById(int pid) async {
    try {
      final result = await Process.run('taskkill', [
        '/F',
        '/PID',
        '$pid',
      ]);
      _logger.info('Kill PID $pid: exit=${result.exitCode}');
      return result.exitCode == 0;
    } catch (e) {
      _logger.severe('Failed to kill PID $pid: $e');
      return false;
    }
  }

  /// Check if a directory is locked by any process
  static Future<bool> isDirectoryLocked(String dirPath) async {
    try {
      // Try to rename/access the directory
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return false;
      
      // Try listing - if it fails, it might be locked
      await dir.list().length;
      return false;
    } catch (_) {
      return true;
    }
  }
}
