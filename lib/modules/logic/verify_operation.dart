// lib/modules/logic/verify_operation.dart
// VERIFY all ACTIVE symlinks: check actual state and fix the JSON history if needed.

import 'dart:io';
import 'package:logging/logging.dart';
import '../symlink_service.dart';
import '../utils.dart';

final _logger = Logger('Logic');

/// Returns list of verification results, one map per active entry.
Future<List<Map<String, String>>> performVerifyAndFix(
  SymlinkService service,
) async {
  _logger.info('=== VERIFY SYMLINKS ===');
  final entries = await service.getActiveEntries();
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
      await service.fixEntryTarget(linkPath, actualTarget);

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
