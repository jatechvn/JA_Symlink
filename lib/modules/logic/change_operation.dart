// lib/modules/logic/change_operation.dart
// CHANGE SYMLINK TARGET workflow:
// Read old target -> Copy to new target -> Remove old link -> Create new link -> Log

import 'dart:io';
import 'package:logging/logging.dart';
import '../app_config.dart';
import '../constants.dart';
import '../native/win_core.dart';
import '../symlink_service.dart';
import '../utils.dart';
import 'pending_operation.dart';
import 'results.dart';

final _logger = Logger('Logic');

Future<OperationResult> performChangeSymlink({
  required SymlinkService service,
  required String linkPath,
  required String newTargetPath,
  bool moveData = false,
  void Function(double percent, String fileName, String sizeInfo)? onProgress,
}) async {
  _logger.info('=== CHANGE SYMLINK ===');
  _logger.info('Link: $linkPath');
  _logger.info('New target: $newTargetPath');

  bool hasCopiedData = false;
  bool targetExisted = false;
  bool symlinkVerified = false;
  final pendingFile = File(AppConfig.getPendingOpPath());
  String? oldTarget;

  try {
    linkPath = normalizePath(linkPath);
    newTargetPath = normalizePath(newTargetPath);

    if (linkPath.isEmpty || newTargetPath.isEmpty) {
      return OperationResult(
        success: false,
        message: 'Link and target paths are required',
      );
    }

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

    if (oldTarget.isEmpty || pathsEqual(oldTarget, newTargetPath)) {
      return OperationResult(
        success: false,
        message: 'New target must be different from the current target',
      );
    }
    if (isSameOrChildPath(oldTarget, newTargetPath)) {
      return OperationResult(
        success: false,
        message: 'New target cannot be inside the current target folder',
      );
    }

    final newTargetDir = Directory(newTargetPath);
    targetExisted = newTargetDir.existsSync();

    if (moveData) {
      // A. WRITE PENDING OP: copying
      await writePendingOp(pendingFile, {
        'type': 'change',
        'source': linkPath,
        'target': newTargetPath,
        'oldTarget': oldTarget,
        'moveData': moveData,
        'targetExisted': targetExisted,
        'step': 'copying',
      });

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
        if (!targetExisted) tryDeleteDir(newTargetDir);
        tryDeletePendingFile(pendingFile);
        return OperationResult(
          success: false,
          message: 'Failed to copy files to new target',
          details: copyErr.toString(),
        );
      }

      // C. UPDATE PENDING OP: linking
      await writePendingOp(pendingFile, {
        'type': 'change',
        'source': linkPath,
        'target': newTargetPath,
        'oldTarget': oldTarget,
        'moveData': moveData,
        'targetExisted': targetExisted,
        'step': 'linking',
      });
    } else {
      // Ensure new target exists
      if (!targetExisted) {
        newTargetDir.createSync(recursive: true);
      }
      // Recovery also needs to cover the gap after removing the old link and
      // before creating the new one when no data is copied.
      await writePendingOp(pendingFile, {
        'type': 'change',
        'source': linkPath,
        'target': newTargetPath,
        'oldTarget': oldTarget,
        'moveData': moveData,
        'targetExisted': targetExisted,
        'step': 'linking',
      });
    }

    // 2. Remove old symlink
    final removeResult = await WindowsNativeEngine.removeSymlink(linkPath);
    if (!removeResult.success) {
      // Rollback copy if we copied data
      if (moveData && hasCopiedData && !targetExisted) {
        tryDeleteDir(newTargetDir);
      }
      tryDeletePendingFile(pendingFile);
      return OperationResult(
        success: false,
        message: 'Failed to remove old symlink: ${removeResult.message}',
      );
    }

    // 3. Create new symlink
    final createResult = await WindowsNativeEngine.createSymlink(
      linkPath,
      newTargetPath,
    );
    if (!createResult.success) {
      // Rollback: recreate old symlink and delete new target
      _logger.warning('Failed to create new symlink. Rolling back...');
      await WindowsNativeEngine.createSymlink(linkPath, oldTarget);
      if (moveData && hasCopiedData && !targetExisted) {
        tryDeleteDir(newTargetDir);
      }
      tryDeletePendingFile(pendingFile);
      return OperationResult(
        success: false,
        message: 'Failed to create new symlink, rolled back',
      );
    }

    // 4. Verify symlink
    final verified = await WindowsNativeEngine.verifySymlink(linkPath);
    if (!verified) {
      _logger.warning('Symlink verification failed, rolling back...');
      await WindowsNativeEngine.removeSymlink(linkPath);
      await WindowsNativeEngine.createSymlink(linkPath, oldTarget);
      if (moveData && hasCopiedData && !targetExisted) {
        tryDeleteDir(newTargetDir);
      }
      tryDeletePendingFile(pendingFile);
      return OperationResult(
        success: false,
        message: 'Symlink verification failed',
      );
    }
    symlinkVerified = true;

    // 5. Success! Clean up old target if we copied data
    if (moveData && hasCopiedData && !pathsEqual(oldTarget, newTargetPath)) {
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
    tryDeletePendingFile(pendingFile);

    // 6. Update CSV
    await service.updateEntryStatus(linkPath, statusActive, statusChanged);
    final newEntry = SymlinkEntry(
      timestamp: formatTimestamp(),
      linkPath: linkPath,
      targetPath: newTargetPath,
      backupPath: csvEmptyPlaceholder,
      status: statusActive,
    );
    await service.addEntry(newEntry);
    await service.writeLog(
      'CHANGE',
      linkPath,
      newTargetPath,
      details: 'Old target: $oldTarget, Move data: $moveData',
    );

    _logger.info('Symlink target changed successfully!');
    return OperationResult(
      success: true,
      message: 'Symlink target changed successfully',
      details: 'Link: $linkPath\nOld: $oldTarget\nNew: $newTargetPath',
    );
  } catch (e) {
    _logger.severe('Change symlink failed: $e');
    if (symlinkVerified) {
      return OperationResult(
        success: true,
        message: 'Symlink changed, but history logging failed',
        details: '$linkPath -> $newTargetPath: $e',
      );
    }
    // Rollback on unexpected exception
    if (oldTarget != null) {
      try {
        if (!await isSymlink(linkPath)) {
          await WindowsNativeEngine.createSymlink(linkPath, oldTarget);
        }
      } catch (_) {}
    }
    if (moveData &&
        hasCopiedData &&
        !targetExisted &&
        Directory(newTargetPath).existsSync()) {
      tryDeleteDir(Directory(newTargetPath));
    }
    tryDeletePendingFile(pendingFile);
    return OperationResult(success: false, message: 'Unexpected error: $e');
  }
}
