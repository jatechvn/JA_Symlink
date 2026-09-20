// lib/modules/logic/verify_operation.dart
// Verify ACTIVE and DANGLING links; only repair mismatched history targets.

import 'dart:io';
import 'package:logging/logging.dart';
import '../symlink_service.dart';
import '../utils.dart';

final _logger = Logger('Logic');

/// Returns one result per tracked ACTIVE or DANGLING entry.
Future<List<Map<String, String>>> performVerifyAndFix(
  SymlinkService service,
) async {
  _logger.info('=== VERIFY SYMLINKS ===');
  final entries = (await service.readAllEntries()).where(
    (e) => e.isActive || e.status == 'DANGLING',
  );
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

    // Keep potentially disconnected/network-drive I/O off the UI thread.
    // ignore: avoid_slow_async_io
    if (!await Directory(actualTarget).exists()) {
      results.add({
        'link': linkPath,
        'csvTarget': csvTarget,
        'actualTarget': actualTarget,
        'status': 'DANGLING',
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
