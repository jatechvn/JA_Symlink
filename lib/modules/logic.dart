// lib/modules/logic.dart
// Core business logic coordinator for symlink operations

import 'dart:io';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'constants.dart';
import 'utils.dart';
import 'symlink_service.dart';
import 'process_utils.dart';
import 'app_config.dart';
import 'native/win_core.dart';

final _logger = Logger('Logic');

/// Result of any symlink operation with detailed info
class OperationResult {
  final bool success;
  final String message;
  final String? details;

  OperationResult({required this.success, required this.message, this.details});
}

/// Result of importing symlinks with detailed info
class ImportResult {
  final int total;
  final int success;
  final int skipped;
  final int failed;
  final List<String> details;

  ImportResult({
    required this.total,
    required this.success,
    required this.skipped,
    required this.failed,
    required this.details,
  });
}

/// Main business logic for symlink management
class SymlinkLogic {
  final SymlinkService _service;

  SymlinkLogic(this._service);

  /// Initialize the service
  Future<void> initialize() async {
    await _service.initialize();
  }

  /// Get all active symlinks
  Future<List<SymlinkEntry>> getActiveSymlinks() async {
    return _service.getActiveEntries();
  }

  /// Get all symlink entries (all statuses)
  Future<List<SymlinkEntry>> getAllEntries() async {
    return _service.readAllEntries();
  }

  /// CREATE SYMLINK
  /// Workflow: Validate -> Check target -> Kill processes -> Move source -> Create symlink -> Verify -> Log
  Future<OperationResult> createSymlink({
    required String sourcePath,
    required String targetPath,
    bool killProcesses = true,
    bool moveData = true,
    void Function(double percent, String fileName, String sizeInfo)? onProgress,
  }) async {
    _logger.info('=== CREATE SYMLINK ===');
    _logger.info('Source (link): $sourcePath');
    _logger.info('Target: $targetPath');

    String backupPath = csvEmptyPlaceholder;
    bool hasRenamedSource = false;
    bool hasCopiedData = false;
    final pendingFile = File(AppConfig.getPendingOpPath());

    try {
      // 1. Validate paths
      sourcePath = normalizePath(sourcePath);
      targetPath = normalizePath(targetPath);

      // 2. Check if source is already a symlink
      if (await isSymlink(sourcePath)) {
        final existingTarget = await getSymlinkTarget(sourcePath);
        return OperationResult(
          success: false,
          message: 'Path is already a symlink',
          details: 'Current target: $existingTarget',
        );
      }

      final sourceDir = Directory(sourcePath);
      final targetDir = Directory(targetPath);

      // 3. Ensure target directory exists
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
        _logger.info('Created target directory: $targetPath');
      }

      // 4. If source directory exists (real directory), handle it
      if (sourceDir.existsSync() && !await isSymlink(sourcePath)) {
        // Kill processes if requested
        if (killProcesses) {
          final locked = await ProcessKiller.isDirectoryLocked(sourcePath);
          if (locked) {
            _logger.info('Directory appears locked, attempting to free...');
          }
        }

        backupPath = '${sourcePath}_backup_${formatTimestampFileName()}';

        if (moveData) {
          // A. WRITE PENDING OP: copying
          await pendingFile.writeAsString(jsonEncode({
            'type': 'create',
            'source': sourcePath,
            'target': targetPath,
            'backup': backupPath,
            'step': 'copying',
          }));

          // B. COPY with progress
          _logger.info('Copying data from source to target...');
          try {
            await copyDirectoryWithProgress(
              sourcePath,
              targetPath,
              onProgress: (percent, fileName, sizeInfo) {
                if (onProgress != null) {
                  onProgress(percent, fileName, sizeInfo);
                }
              },
            );
            hasCopiedData = true;
          } catch (copyErr) {
            _logger.severe('Copy failed: $copyErr');
            // Clean up partially copied target
            if (targetDir.existsSync()) {
              try {
                targetDir.deleteSync(recursive: true);
              } catch (_) {}
            }
            if (pendingFile.existsSync()) {
              try {
                pendingFile.deleteSync();
              } catch (_) {}
            }
            return OperationResult(
              success: false,
              message: 'Failed to copy source files',
              details: copyErr.toString(),
            );
          }

          // C. UPDATE PENDING OP: linking
          await pendingFile.writeAsString(jsonEncode({
            'type': 'create',
            'source': sourcePath,
            'target': targetPath,
            'backup': backupPath,
            'step': 'linking',
          }));
        } else {
          // If NOT moving data, we still need to backup the original directory,
          // so write pending op directly to linking.
          await pendingFile.writeAsString(jsonEncode({
            'type': 'create',
            'source': sourcePath,
            'target': targetPath,
            'backup': backupPath,
            'step': 'linking',
          }));
        }

        // D. RENAME source to backup
        _logger.info('Renaming source to backup: $backupPath');
        try {
          sourceDir.renameSync(backupPath);
          hasRenamedSource = true;
        } catch (renameErr) {
          _logger.severe('Rename source to backup failed: $renameErr');
          // Rollback copy if we moved data
          if (moveData && hasCopiedData && targetDir.existsSync()) {
            try {
              targetDir.deleteSync(recursive: true);
            } catch (_) {}
          }
          if (pendingFile.existsSync()) {
            try {
              pendingFile.deleteSync();
            } catch (_) {}
          }
          return OperationResult(
            success: false,
            message: 'Failed to backup source folder (rename failed)',
            details: renameErr.toString(),
          );
        }
      }

      // 5. Create symlink
      final result = await WindowsNativeEngine.createSymlink(sourcePath, targetPath);
      if (!result.success) {
        // Rollback
        _logger.warning('Symlink creation failed: ${result.message}. Rolling back...');
        if (hasRenamedSource && backupPath != csvEmptyPlaceholder) {
          try {
            Directory(backupPath).renameSync(sourcePath);
          } catch (_) {}
        }
        if (moveData && hasCopiedData && targetDir.existsSync()) {
          try {
            targetDir.deleteSync(recursive: true);
          } catch (_) {}
        }
        if (pendingFile.existsSync()) {
          try {
            pendingFile.deleteSync();
          } catch (_) {}
        }
        return OperationResult(success: false, message: result.message);
      }

      // 6. Verify symlink
      final verified = await WindowsNativeEngine.verifySymlink(sourcePath);
      if (!verified) {
        _logger.warning('Symlink verification failed, but creation reported success');
      }

      // 7. Success! Clean up backup if we moved data
      if (moveData && hasRenamedSource && backupPath != csvEmptyPlaceholder) {
        _logger.info('Deleting temporary backup: $backupPath');
        try {
          Directory(backupPath).deleteSync(recursive: true);
        } catch (delErr) {
          _logger.warning('Failed to delete temporary backup: $delErr');
        }
      }

      // Delete pending transaction file
      if (pendingFile.existsSync()) {
        try {
          pendingFile.deleteSync();
        } catch (_) {}
      }

      // 8. Log to CSV and log file
      final entry = SymlinkEntry(
        timestamp: formatTimestamp(),
        linkPath: sourcePath,
        targetPath: targetPath,
        backupPath: moveData ? csvEmptyPlaceholder : backupPath,
        status: statusActive,
      );
      await _service.addEntry(entry);
      await _service.writeLog('CREATE', sourcePath, targetPath, details: 'Backup: $backupPath');

      _logger.info('Symlink created successfully!');
      return OperationResult(
        success: true,
        message: 'Symlink created successfully',
        details: 'Link: $sourcePath -> Target: $targetPath',
      );
    } catch (e) {
      _logger.severe('Create symlink failed: $e');
      // Rollback on unexpected exception
      if (hasRenamedSource && backupPath != csvEmptyPlaceholder) {
        try {
          Directory(backupPath).renameSync(sourcePath);
        } catch (_) {}
      }
      if (moveData && hasCopiedData && Directory(targetPath).existsSync()) {
        try {
          Directory(targetPath).deleteSync(recursive: true);
        } catch (_) {}
      }
      if (pendingFile.existsSync()) {
        try {
          pendingFile.deleteSync();
        } catch (_) {}
      }
      return OperationResult(success: false, message: 'Unexpected error: $e');
    }
  }

  /// REMOVE SYMLINK
  /// Workflow: Validate -> rmdir (link only) -> Restore backup? -> Update CSV
  Future<OperationResult> removeSymlink({
    required String linkPath,
    bool restoreBackup = false,
  }) async {
    _logger.info('=== REMOVE SYMLINK ===');
    _logger.info('Link: $linkPath');

    try {
      linkPath = normalizePath(linkPath);

      // 1. Check if it's actually a symlink
      if (!await isSymlink(linkPath)) {
        return OperationResult(
          success: false,
          message: 'Path is not a symlink',
          details: linkPath,
        );
      }

      final targetPath = await getSymlinkTarget(linkPath) ?? 'unknown';

      // 2. Remove symlink (rmdir only removes the link, NOT the data)
      final result = await WindowsNativeEngine.removeSymlink(linkPath);
      if (!result.success) {
        return OperationResult(success: false, message: result.message);
      }

      // 3. Restore backup if requested
      if (restoreBackup) {
        final entries = await _service.readAllEntries();
        final entry = entries.where((e) => e.linkPath == linkPath && e.isActive).firstOrNull;
        if (entry != null && entry.hasBackup) {
          _logger.info('Restoring backup from: ${entry.backupPath}');
          await WindowsNativeEngine.moveDirectory(entry.backupPath, linkPath);
        }
      }

      // 4. Update CSV status
      await _service.updateEntryStatus(linkPath, statusActive, statusRemoved);
      await _service.writeLog('REMOVE', linkPath, targetPath, details: restoreBackup ? 'Backup restored' : 'No restore');

      _logger.info('Symlink removed successfully!');
      return OperationResult(
        success: true,
        message: 'Symlink removed successfully',
        details: 'Removed: $linkPath',
      );
    } catch (e) {
      _logger.severe('Remove symlink failed: $e');
      return OperationResult(success: false, message: 'Unexpected error: $e');
    }
  }

  Future<OperationResult> changeSymlink({
    required String linkPath,
    required String newTargetPath,
    bool moveData = false,
    void Function(double percent, String fileName, String sizeInfo)? onProgress,
  }) async {
    _logger.info('=== CHANGE SYMLINK ===');
    _logger.info('Link: $linkPath');
    _logger.info('New target: $newTargetPath');

    bool hasCopiedData = false;
    final pendingFile = File(AppConfig.getPendingOpPath());
    String? oldTarget;

    try {
      linkPath = normalizePath(linkPath);
      newTargetPath = normalizePath(newTargetPath);

      // 1. Get current target
      oldTarget = await getSymlinkTarget(linkPath);
      if (oldTarget == null) {
        return OperationResult(
          success: false,
          message: 'Cannot read current symlink target',
          details: linkPath,
        );
      }
      oldTarget = normalizePath(oldTarget);

      final newTargetDir = Directory(newTargetPath);

      if (moveData) {
        // A. WRITE PENDING OP: copying
        await pendingFile.writeAsString(jsonEncode({
          'type': 'change',
          'source': linkPath,
          'target': newTargetPath,
          'oldTarget': oldTarget,
          'step': 'copying',
        }));

        // B. COPY with progress
        _logger.info('Copying data from old target to new target...');
        try {
          await copyDirectoryWithProgress(
            oldTarget,
            newTargetPath,
            onProgress: (percent, fileName, sizeInfo) {
              if (onProgress != null) {
                onProgress(percent, fileName, sizeInfo);
              }
            },
          );
          hasCopiedData = true;
        } catch (copyErr) {
          _logger.severe('Copy failed during change target: $copyErr');
          // Clean up new target
          if (newTargetDir.existsSync()) {
            try {
              newTargetDir.deleteSync(recursive: true);
            } catch (_) {}
          }
          if (pendingFile.existsSync()) {
            try {
              pendingFile.deleteSync();
            } catch (_) {}
          }
          return OperationResult(
            success: false,
            message: 'Failed to copy files to new target',
            details: copyErr.toString(),
          );
        }

        // C. UPDATE PENDING OP: linking
        await pendingFile.writeAsString(jsonEncode({
          'type': 'change',
          'source': linkPath,
          'target': newTargetPath,
          'oldTarget': oldTarget,
          'step': 'linking',
        }));
      } else {
        // Ensure new target exists
        if (!newTargetDir.existsSync()) {
          newTargetDir.createSync(recursive: true);
        }
      }

      // 2. Remove old symlink
      final removeResult = await WindowsNativeEngine.removeSymlink(linkPath);
      if (!removeResult.success) {
        // Rollback copy if we copied data
        if (moveData && hasCopiedData && newTargetDir.existsSync()) {
          try {
            newTargetDir.deleteSync(recursive: true);
          } catch (_) {}
        }
        if (pendingFile.existsSync()) {
          try {
            pendingFile.deleteSync();
          } catch (_) {}
        }
        return OperationResult(success: false, message: 'Failed to remove old symlink: ${removeResult.message}');
      }

      // 3. Create new symlink
      final createResult = await WindowsNativeEngine.createSymlink(linkPath, newTargetPath);
      if (!createResult.success) {
        // Rollback: recreate old symlink and delete new target
        _logger.warning('Failed to create new symlink. Rolling back...');
        await WindowsNativeEngine.createSymlink(linkPath, oldTarget);
        if (moveData && hasCopiedData && newTargetDir.existsSync()) {
          try {
            newTargetDir.deleteSync(recursive: true);
          } catch (_) {}
        }
        if (pendingFile.existsSync()) {
          try {
            pendingFile.deleteSync();
          } catch (_) {}
        }
        return OperationResult(success: false, message: 'Failed to create new symlink, rolled back');
      }

      // 4. Verify symlink
      final verified = await WindowsNativeEngine.verifySymlink(linkPath);
      if (!verified) {
        _logger.warning('Symlink verification failed, but creation reported success');
      }

      // 5. Success! Clean up old target if we copied data
      if (moveData) {
        final oldTargetDir = Directory(oldTarget);
        if (oldTargetDir.existsSync()) {
          _logger.info('Deleting old target directory: $oldTarget');
          try {
            oldTargetDir.deleteSync(recursive: true);
          } catch (delErr) {
            _logger.warning('Failed to delete old target directory: $delErr');
          }
        }
      }

      // Delete pending transaction file
      if (pendingFile.existsSync()) {
        try {
          pendingFile.deleteSync();
        } catch (_) {}
      }

      // 6. Update CSV
      await _service.updateEntryStatus(linkPath, statusActive, statusChanged);
      final newEntry = SymlinkEntry(
        timestamp: formatTimestamp(),
        linkPath: linkPath,
        targetPath: newTargetPath,
        backupPath: csvEmptyPlaceholder,
        status: statusActive,
      );
      await _service.addEntry(newEntry);
      await _service.writeLog('CHANGE', linkPath, newTargetPath, details: 'Old target: $oldTarget, Move data: $moveData');

      _logger.info('Symlink target changed successfully!');
      return OperationResult(
        success: true,
        message: 'Symlink target changed successfully',
        details: 'Link: $linkPath\nOld: $oldTarget\nNew: $newTargetPath',
      );
    } catch (e) {
      _logger.severe('Change symlink failed: $e');
      // Rollback on unexpected exception
      if (oldTarget != null) {
        try {
          final link = Link(linkPath);
          if (!link.existsSync()) {
            await WindowsNativeEngine.createSymlink(linkPath, oldTarget);
          }
        } catch (_) {}
      }
      if (moveData && hasCopiedData && Directory(newTargetPath).existsSync()) {
        try {
          Directory(newTargetPath).deleteSync(recursive: true);
        } catch (_) {}
      }
      if (pendingFile.existsSync()) {
        try {
          pendingFile.deleteSync();
        } catch (_) {}
      }
      return OperationResult(success: false, message: 'Unexpected error: $e');
    }
  }

  /// Recover from a crashed/interrupted symlink operation on app startup
  Future<void> recoverInterruptedOperation() async {
    final pendingFile = File(AppConfig.getPendingOpPath());
    if (!pendingFile.existsSync()) return;

    _logger.info('=== RECOVERING INTERRUPTED OPERATION ===');
    try {
      final jsonStr = pendingFile.readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final type = data['type'] as String?;
      final source = data['source'] as String;
      final target = data['target'] as String;
      final step = data['step'] as String;

      if (type == 'create') {
        final backup = data['backup'] as String?;
        if (step == 'copying') {
          // Crash occurred during copying. Source is intact. Clean up target.
          _logger.info('Recovery: Crash occurred during copying. Source is intact. Cleaning up target...');
          final targetDir = Directory(target);
          if (targetDir.existsSync()) {
            targetDir.deleteSync(recursive: true);
          }
        } else if (step == 'linking') {
          // Crash occurred during linking. Source was renamed to backup.
          _logger.info('Recovery: Crash occurred during linking. Verifying symlink...');
          final linkExists = await isSymlink(source);
          final actualTarget = await getSymlinkTarget(source);
          final isLinkCorrect = linkExists &&
              actualTarget != null &&
              normalizePath(actualTarget).toLowerCase() == normalizePath(target).toLowerCase();

          if (isLinkCorrect) {
            _logger.info('Recovery: Symlink is correct. Cleaning up backup directory...');
            if (backup != null && Directory(backup).existsSync()) {
              Directory(backup).deleteSync(recursive: true);
            }
          } else {
            _logger.info('Recovery: Symlink is incorrect or missing. Rolling back...');
            final link = Link(source);
            if (link.existsSync()) {
              link.deleteSync();
            } else {
              final dir = Directory(source);
              if (dir.existsSync()) dir.deleteSync();
            }
            if (backup != null && Directory(backup).existsSync()) {
              await Directory(backup).rename(source);
            }
            final targetDir = Directory(target);
            if (targetDir.existsSync()) {
              targetDir.deleteSync(recursive: true);
            }
          }
        }
      } else if (type == 'change') {
        final oldTarget = data['oldTarget'] as String;
        if (step == 'copying') {
          // Crash occurred during changing target (copy phase). Clean up new target.
          _logger.info('Recovery: Crash occurred during changing target (copy phase). Cleaning up new target...');
          final targetDir = Directory(target);
          if (targetDir.existsSync()) {
            targetDir.deleteSync(recursive: true);
          }
        } else if (step == 'linking') {
          // Crash occurred during changing target (linking phase).
          _logger.info('Recovery: Crash occurred during changing target (linking phase). Verifying symlink...');
          final linkExists = await isSymlink(source);
          final actualTarget = await getSymlinkTarget(source);
          final isLinkCorrect = linkExists &&
              actualTarget != null &&
              normalizePath(actualTarget).toLowerCase() == normalizePath(target).toLowerCase();

          if (isLinkCorrect) {
            _logger.info('Recovery: Symlink points to new target. Cleaning up old target...');
            final oldTargetDir = Directory(oldTarget);
            if (oldTargetDir.existsSync()) {
              oldTargetDir.deleteSync(recursive: true);
            }
          } else {
            _logger.info('Recovery: Symlink is incorrect/missing. Re-linking to old target...');
            final link = Link(source);
            if (link.existsSync()) {
              link.deleteSync();
            } else {
              final dir = Directory(source);
              if (dir.existsSync()) dir.deleteSync();
            }
            await WindowsNativeEngine.createSymlink(source, oldTarget);
            final targetDir = Directory(target);
            if (targetDir.existsSync()) {
              targetDir.deleteSync(recursive: true);
            }
          }
        }
      }
      _logger.info('=== RECOVERY COMPLETE ===');
    } catch (e) {
      _logger.severe('Recovery failed: $e');
    } finally {
      if (pendingFile.existsSync()) {
        try {
          pendingFile.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Check if running as admin
  Future<bool> isAdmin() async {
    return WindowsNativeEngine.isAdmin();
  }

  /// Elevate to admin
  Future<void> elevateAdmin() async {
    return WindowsNativeEngine.elevateAdmin();
  }

  /// Scan system for existing symlinks
  Future<List<Map<String, String>>> scanSystemSymlinks() async {
    return _service.scanSystemSymlinks();
  }

  /// VERIFY all ACTIVE symlinks: check actual state and fix CSV if needed
  /// Returns list of verification results
  Future<List<Map<String, String>>> verifyAndFixEntries() async {
    _logger.info('=== VERIFY SYMLINKS ===');
    final entries = await _service.getActiveEntries();
    final results = <Map<String, String>>[];

    for (final entry in entries) {
      final linkPath = entry.linkPath;
      final csvTarget = entry.targetPath;

      // Check if link exists
      final linkExists = await isSymlink(linkPath);
      if (!linkExists) {
        // Check if it's a normal directory
        final dir = Directory(linkPath);
        if (dir.existsSync()) {
          results.add({
            'link': linkPath,
            'csvTarget': csvTarget,
            'actualTarget': '(NORMAL DIR - not a symlink)',
            'status': 'BROKEN',
          });
        } else {
          results.add({
            'link': linkPath,
            'csvTarget': csvTarget,
            'actualTarget': '(NOT FOUND)',
            'status': 'MISSING',
          });
        }
        continue;
      }

      // Get actual target
      final actualTarget = await getSymlinkTarget(linkPath);
      if (actualTarget == null) {
        results.add({
          'link': linkPath,
          'csvTarget': csvTarget,
          'actualTarget': '(cannot read target)',
          'status': 'ERROR',
        });
        continue;
      }

      // Compare (normalize paths for comparison)
      final normalizedCsv = normalizePath(csvTarget);
      final normalizedActual = normalizePath(actualTarget);

      if (normalizedCsv.toLowerCase() == normalizedActual.toLowerCase()) {
        results.add({
          'link': linkPath,
          'csvTarget': csvTarget,
          'actualTarget': actualTarget,
          'status': 'OK',
        });
      } else {
        // Mismatch! Auto-fix CSV
        _logger.info('MISMATCH: $linkPath');
        _logger.info('  CSV target:    $csvTarget');
        _logger.info('  Actual target: $actualTarget');

        // Update the entry in CSV
        await _service.fixEntryTarget(linkPath, actualTarget);

        results.add({
          'link': linkPath,
          'csvTarget': csvTarget,
          'actualTarget': actualTarget,
          'status': 'FIXED',
        });
      }
    }

    _logger.info('Verify complete: ${results.length} entries checked');
    return results;
  }

  /// Export active symlinks to a JSON file
  Future<OperationResult> exportSymlinks(String filePath) async {
    try {
      final entries = await _service.readAllEntries();
      // Only export active entries
      final activeEntries = entries.where((e) => e.isActive).toList();
      
      final list = activeEntries.map((e) => {
        'timestamp': e.timestamp,
        'linkPath': e.linkPath,
        'targetPath': e.targetPath,
        'backupPath': e.backupPath,
        'status': e.status,
      }).toList();
      
      final jsonFile = File(filePath);
      await jsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(list));
      
      return OperationResult(
        success: true,
        message: 'Symlinks exported successfully',
        details: 'Exported ${activeEntries.length} symlinks to $filePath',
      );
    } catch (e) {
      _logger.severe('Export error: $e');
      return OperationResult(
        success: false,
        message: 'Failed to export symlinks',
        details: e.toString(),
      );
    }
  }

  /// Import symlinks from a JSON file and try to restore them
  Future<ImportResult> importSymlinks(String filePath) async {
    try {
      final jsonFile = File(filePath);
      if (!jsonFile.existsSync()) {
        throw FileSystemException('File does not exist', filePath);
      }
      final jsonStr = await jsonFile.readAsString();
      final List<dynamic> list = jsonDecode(jsonStr);
      
      int total = list.length;
      int success = 0;
      int skipped = 0;
      int failed = 0;
      final details = <String>[];
      
      final dbEntries = await _service.readAllEntries();
      
      for (final item in list) {
        try {
          final map = item as Map<String, dynamic>;
          final linkPath = normalizePath(map['linkPath'] as String? ?? '');
          final targetPath = normalizePath(map['targetPath'] as String? ?? '');
          
          if (linkPath.isEmpty || targetPath.isEmpty) {
            failed++;
            details.add('Failed (invalid record data): $item');
            continue;
          }

          // Check if already exists in DB as active
          final existsInDb = dbEntries.any((e) => e.linkPath == linkPath && e.targetPath == targetPath && e.isActive);
          
          // Check if active symlink exists in OS pointing to the correct target
          final linkExists = await isSymlink(linkPath);
          final currentTarget = await getSymlinkTarget(linkPath);
          final isOsLinkCorrect = linkExists && 
              currentTarget != null && 
              normalizePath(currentTarget).toLowerCase() == targetPath.toLowerCase();
              
          if (existsInDb && isOsLinkCorrect) {
            skipped++;
            details.add('Skipped (already exists and active): $linkPath -> $targetPath');
            continue;
          }
          
          // If it exists as a normal folder, do not overwrite it automatically to prevent data loss
          final dir = Directory(linkPath);
          if (dir.existsSync() && !await isSymlink(linkPath)) {
            skipped++;
            details.add('Skipped (link path is a normal directory): $linkPath');
            continue;
          }
          
          // Ensure target directory exists
          final targetDir = Directory(targetPath);
          if (!targetDir.existsSync()) {
            try {
              targetDir.createSync(recursive: true);
            } catch (e) {
              failed++;
              details.add('Failed (cannot create target folder): $linkPath -> $targetPath. Error: $e');
              continue;
            }
          }
          
          // Remove link if it exists but is broken or points to different target
          if (linkExists) {
            final delResult = await WindowsNativeEngine.removeSymlink(linkPath);
            if (!delResult.success) {
              failed++;
              details.add('Failed (cannot remove old/broken link): $linkPath -> $targetPath. Error: ${delResult.message}');
              continue;
            }
          } else {
            // Also try to delete as a link file just in case it's a file link
            final linkFile = Link(linkPath);
            if (linkFile.existsSync()) {
              try {
                linkFile.deleteSync();
              } catch (_) {}
            }
          }
          
          final res = await WindowsNativeEngine.createSymlink(linkPath, targetPath);
          if (res.success) {
            success++;
            details.add('Restored: $linkPath -> $targetPath');
            
            // Save to database
            final entry = SymlinkEntry(
              timestamp: formatTimestamp(),
              linkPath: linkPath,
              targetPath: targetPath,
              backupPath: csvEmptyPlaceholder,
              status: statusActive,
            );
            await _service.addEntry(entry);
            await _service.writeLog('IMPORT_RESTORE', linkPath, targetPath);
          } else {
            failed++;
            details.add('Failed (symlink creation failed): $linkPath -> $targetPath. Error: ${res.message}');
          }
        } catch (itemErr) {
          failed++;
          details.add('Failed (exception processing item): $itemErr');
        }
      }
      
      return ImportResult(
        total: total,
        success: success,
        skipped: skipped,
        failed: failed,
        details: details,
      );
    } catch (e) {
      _logger.severe('Import error: $e');
      rethrow;
    }
  }
}

