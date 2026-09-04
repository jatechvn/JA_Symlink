// lib/modules/logic/import_export.dart
// Export active symlinks to JSON, and import/restore symlinks from a JSON file.

import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import '../constants.dart';
import '../native/win_core.dart';
import '../symlink_service.dart';
import '../utils.dart';
import 'results.dart';

final _logger = Logger('Logic');

/// Export active symlinks to a JSON file
Future<OperationResult> performExport(
  SymlinkService service,
  String filePath,
) async {
  try {
    final entries = await service.readAllEntries();
    // Only export active entries
    final activeEntries = entries.where((e) => e.isActive).toList();

    final list = activeEntries
        .map(
          (e) => {
            'timestamp': e.timestamp,
            'linkPath': e.linkPath,
            'targetPath': e.targetPath,
            'backupPath': e.backupPath,
            'status': e.status,
          },
        )
        .toList();

    final jsonFile = File(filePath);
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(list),
    );

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
Future<ImportResult> performImport(
  SymlinkService service,
  String filePath,
) async {
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

    final dbEntries = await service.readAllEntries();

    for (final item in list) {
      final outcome = await _importOne(service, item, dbEntries);
      switch (outcome.kind) {
        case _ImportOutcomeKind.success:
          success++;
          break;
        case _ImportOutcomeKind.skipped:
          skipped++;
          break;
        case _ImportOutcomeKind.failed:
          failed++;
          break;
      }
      details.add(outcome.detail);
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

enum _ImportOutcomeKind { success, skipped, failed }

class _ImportOutcome {
  final _ImportOutcomeKind kind;
  final String detail;
  const _ImportOutcome(this.kind, this.detail);
}

/// Attempts to restore a single symlink record from an import file.
/// [dbEntries] is the full existing history, used to detect already-restored links.
Future<_ImportOutcome> _importOne(
  SymlinkService service,
  dynamic item,
  List<SymlinkEntry> dbEntries,
) async {
  try {
    final map = item as Map<String, dynamic>;
    final linkPath = normalizePath(map['linkPath'] as String? ?? '');
    final targetPath = normalizePath(map['targetPath'] as String? ?? '');

    if (linkPath.isEmpty || targetPath.isEmpty) {
      return _ImportOutcome(
        _ImportOutcomeKind.failed,
        'Failed (invalid record data): $item',
      );
    }

    // Check if already exists in DB as active
    final existsInDb = dbEntries.any(
      (e) =>
          pathsEqual(e.linkPath, linkPath) &&
          pathsEqual(e.targetPath, targetPath) &&
          e.isActive,
    );

    // Check if active symlink exists in OS pointing to the correct target
    final linkExists = await isSymlink(linkPath);
    final currentTarget = await getSymlinkTarget(linkPath);
    final isOsLinkCorrect =
        linkExists &&
        currentTarget != null &&
        normalizePath(currentTarget).toLowerCase() == targetPath.toLowerCase();

    final importedBackup = normalizePath(
      map['backupPath'] as String? ?? csvEmptyPlaceholder,
    );

    if (existsInDb && isOsLinkCorrect) {
      return _ImportOutcome(
        _ImportOutcomeKind.skipped,
        'Skipped (already exists and active): $linkPath -> $targetPath',
      );
    }

    // If the operating-system link is already correct but history is missing,
    // track it without deleting/recreating the user's working link.
    if (isOsLinkCorrect) {
      final entry = SymlinkEntry(
        timestamp: formatTimestamp(),
        linkPath: linkPath,
        targetPath: targetPath,
        backupPath: importedBackup,
        status: statusActive,
      );
      await service.addEntry(entry);
      dbEntries.add(entry);
      await service.writeLog('IMPORT_TRACK', linkPath, targetPath);
      return _ImportOutcome(
        _ImportOutcomeKind.success,
        'Tracked existing link: $linkPath -> $targetPath',
      );
    }

    // If any non-link filesystem entry occupies the link path, do not overwrite
    // it automatically to prevent data loss.
    final existingType = FileSystemEntity.typeSync(
      linkPath,
      followLinks: false,
    );
    if (existingType != FileSystemEntityType.notFound && !linkExists) {
      return _ImportOutcome(
        _ImportOutcomeKind.skipped,
        'Skipped (link path is not a symlink): $linkPath',
      );
    }

    // Ensure target directory exists
    final targetDir = Directory(targetPath);
    if (!targetDir.existsSync()) {
      try {
        targetDir.createSync(recursive: true);
      } catch (e) {
        return _ImportOutcome(
          _ImportOutcomeKind.failed,
          'Failed (cannot create target folder): $linkPath -> $targetPath. Error: $e',
        );
      }
    }

    // Remove link if it exists but is broken or points to different target
    if (linkExists) {
      final delResult = await WindowsNativeEngine.removeSymlink(linkPath);
      if (!delResult.success) {
        return _ImportOutcome(
          _ImportOutcomeKind.failed,
          'Failed (cannot remove old/broken link): $linkPath -> $targetPath. Error: ${delResult.message}',
        );
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
    if (!res.success) {
      return _ImportOutcome(
        _ImportOutcomeKind.failed,
        'Failed (symlink creation failed): $linkPath -> $targetPath. Error: ${res.message}',
      );
    }

    // Save to database
    final entry = SymlinkEntry(
      timestamp: formatTimestamp(),
      linkPath: linkPath,
      targetPath: targetPath,
      backupPath: importedBackup,
      status: statusActive,
    );
    await service.addEntry(entry);
    dbEntries.add(entry);
    await service.writeLog('IMPORT_RESTORE', linkPath, targetPath);
    return _ImportOutcome(
      _ImportOutcomeKind.success,
      'Restored: $linkPath -> $targetPath',
    );
  } catch (itemErr) {
    return _ImportOutcome(
      _ImportOutcomeKind.failed,
      'Failed (exception processing item): $itemErr',
    );
  }
}
