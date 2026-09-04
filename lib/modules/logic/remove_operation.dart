// lib/modules/logic/remove_operation.dart
// REMOVE SYMLINK workflow:
// Validate -> rmdir (link only) -> Restore backup? -> Update CSV

import 'package:logging/logging.dart';
import '../constants.dart';
import '../native/win_core.dart';
import '../symlink_service.dart';
import '../utils.dart';
import 'results.dart';

final _logger = Logger('Logic');

Future<OperationResult> performRemoveSymlink({
  required SymlinkService service,
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
      final entries = await service.readAllEntries();
      final entry = entries
          .where((e) => pathsEqual(e.linkPath, linkPath) && e.isActive)
          .firstOrNull;
      if (entry != null && entry.hasBackup) {
        _logger.info('Restoring backup from: ${entry.backupPath}');
        final restoreResult = await WindowsNativeEngine.moveDirectory(
          entry.backupPath,
          linkPath,
        );
        if (!restoreResult.success) {
          await service.updateEntryStatus(
            linkPath,
            statusActive,
            statusRemoved,
          );
          return OperationResult(
            success: false,
            message: 'Symlink removed, but backup restore failed',
            details: restoreResult.message,
          );
        }
      }
    }

    // 4. Update CSV status
    await service.updateEntryStatus(linkPath, statusActive, statusRemoved);
    await service.writeLog(
      'REMOVE',
      linkPath,
      targetPath,
      details: restoreBackup ? 'Backup restored' : 'No restore',
    );

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
