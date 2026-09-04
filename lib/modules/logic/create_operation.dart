// lib/modules/logic/create_operation.dart
// CREATE SYMLINK workflow:
// Validate -> Check target -> Kill processes -> Move source -> Create symlink -> Verify -> Log

import 'dart:io';
import 'package:logging/logging.dart';
import '../app_config.dart';
import '../constants.dart';
import '../native/win_core.dart';
import '../process_utils.dart';
import '../symlink_service.dart';
import '../utils.dart';
import 'pending_operation.dart';
import 'results.dart';

final _logger = Logger('Logic');

Future<OperationResult> performCreateSymlink({
  required SymlinkService service,
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
  bool targetExisted = false;
  bool symlinkVerified = false;
  final pendingFile = File(AppConfig.getPendingOpPath());

  try {
    // 1. Validate paths
    sourcePath = normalizePath(sourcePath);
    targetPath = normalizePath(targetPath);

    if (sourcePath.isEmpty || targetPath.isEmpty) {
      return OperationResult(
        success: false,
        message: 'Source and target paths are required',
      );
    }
    if (pathsEqual(sourcePath, targetPath) ||
        isSameOrChildPath(sourcePath, targetPath)) {
      return OperationResult(
        success: false,
        message: 'Target path cannot be the source folder or a child folder',
      );
    }

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
    targetExisted = targetDir.existsSync();

    // 3. Ensure target directory exists
    if (!targetExisted) {
      targetDir.createSync(recursive: true);
      _logger.info('Created target directory: $targetPath');
    }

    // 4. If source directory exists (real directory), handle it
    if (sourceDir.existsSync() && !await isSymlink(sourcePath)) {
      // Kill processes if requested
      if (killProcesses) {
        final lockingProcesses = await ProcessKiller.getProcessesLocking(
          sourcePath,
        );
        for (final process in lockingProcesses) {
          final separator = process.indexOf('|');
          final processId = int.tryParse(
            separator < 0 ? process : process.substring(0, separator),
          );
          if (processId == null || processId == pid) continue;
          await ProcessKiller.killProcessById(processId);
        }

        if (await ProcessKiller.isDirectoryLocked(sourcePath)) {
          _logger.warning(
            'Directory remains locked after terminating locking processes',
          );
        }
      }

      backupPath = '${sourcePath}_backup_${formatTimestampFileName()}';

      if (moveData) {
        // A. WRITE PENDING OP: copying
        await writePendingOp(pendingFile, {
          'type': 'create',
          'source': sourcePath,
          'target': targetPath,
          'backup': backupPath,
          'moveData': moveData,
          'targetExisted': targetExisted,
          'step': 'copying',
        });

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
          if (!targetExisted) tryDeleteDir(targetDir);
          tryDeletePendingFile(pendingFile);
          return OperationResult(
            success: false,
            message: 'Failed to copy source files',
            details: copyErr.toString(),
          );
        }

        // C. UPDATE PENDING OP: linking
        await writePendingOp(pendingFile, {
          'type': 'create',
          'source': sourcePath,
          'target': targetPath,
          'backup': backupPath,
          'moveData': moveData,
          'targetExisted': targetExisted,
          'step': 'linking',
        });
      } else {
        // If NOT moving data, we still need to backup the original directory,
        // so write pending op directly to linking.
        await writePendingOp(pendingFile, {
          'type': 'create',
          'source': sourcePath,
          'target': targetPath,
          'backup': backupPath,
          'moveData': moveData,
          'targetExisted': targetExisted,
          'step': 'linking',
        });
      }

      // D. RENAME source to backup
      _logger.info('Renaming source to backup: $backupPath');
      try {
        sourceDir.renameSync(backupPath);
        hasRenamedSource = true;
      } catch (renameErr) {
        _logger.severe('Rename source to backup failed: $renameErr');
        // Rollback copy if we moved data
        if (moveData && hasCopiedData && !targetExisted) {
          tryDeleteDir(targetDir);
        }
        tryDeletePendingFile(pendingFile);
        return OperationResult(
          success: false,
          message: 'Failed to backup source folder (rename failed)',
          details: renameErr.toString(),
        );
      }
    }

    // 5. Create symlink
    final result = await WindowsNativeEngine.createSymlink(
      sourcePath,
      targetPath,
    );
    if (!result.success) {
      // Rollback
      _logger.warning(
        'Symlink creation failed: ${result.message}. Rolling back...',
      );
      if (hasRenamedSource && backupPath != csvEmptyPlaceholder) {
        tryRenameDir(backupPath, sourcePath);
      }
      if (moveData && hasCopiedData && !targetExisted) {
        tryDeleteDir(targetDir);
      }
      tryDeletePendingFile(pendingFile);
      return OperationResult(success: false, message: result.message);
    }

    // 6. Verify symlink
    final verified = await WindowsNativeEngine.verifySymlink(sourcePath);
    if (!verified) {
      _logger.warning('Symlink verification failed, rolling back...');
      await WindowsNativeEngine.removeSymlink(sourcePath);
      if (hasRenamedSource && backupPath != csvEmptyPlaceholder) {
        tryRenameDir(backupPath, sourcePath);
      }
      if (moveData && hasCopiedData && !targetExisted) {
        tryDeleteDir(targetDir);
      }
      tryDeletePendingFile(pendingFile);
      return OperationResult(
        success: false,
        message: 'Symlink verification failed',
      );
    }
    symlinkVerified = true;

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
    tryDeletePendingFile(pendingFile);

    // 8. Log to CSV and log file
    final entry = SymlinkEntry(
      timestamp: formatTimestamp(),
      linkPath: sourcePath,
      targetPath: targetPath,
      backupPath: moveData ? csvEmptyPlaceholder : backupPath,
      status: statusActive,
    );
    await service.addEntry(entry);
    await service.writeLog(
      'CREATE',
      sourcePath,
      targetPath,
      details: 'Backup: $backupPath',
    );

    _logger.info('Symlink created successfully!');
    return OperationResult(
      success: true,
      message: 'Symlink created successfully',
      details: 'Link: $sourcePath -> Target: $targetPath',
    );
  } catch (e) {
    _logger.severe('Create symlink failed: $e');
    // Once the link has been verified, removing it during error handling could
    // destroy a valid operation merely because logging/history persistence
    // failed. Keep the working link and report the persistence warning.
    if (symlinkVerified) {
      return OperationResult(
        success: true,
        message: 'Symlink created, but history logging failed',
        details: '$sourcePath -> $targetPath: $e',
      );
    }
    // Rollback on unexpected exception
    if (hasRenamedSource && backupPath != csvEmptyPlaceholder) {
      tryRenameDir(backupPath, sourcePath);
    }
    if (moveData &&
        hasCopiedData &&
        !targetExisted &&
        Directory(targetPath).existsSync()) {
      tryDeleteDir(Directory(targetPath));
    }
    tryDeletePendingFile(pendingFile);
    return OperationResult(success: false, message: 'Unexpected error: $e');
  }
}
