// lib/modules/logic/recovery.dart
// Crash recovery: reconciles a leftover pending-operation transaction file
// left behind when the app was killed mid create/change operation.

import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import '../app_config.dart';
import '../native/win_core.dart';
import '../utils.dart';
import 'pending_operation.dart';

final _logger = Logger('Logic');

/// Recover from a crashed/interrupted symlink operation on app startup
Future<void> performRecovery() async {
  final pendingFile = File(AppConfig.getPendingOpPath());
  if (!pendingFile.existsSync()) return;

  _logger.info('=== RECOVERING INTERRUPTED OPERATION ===');
  try {
    final jsonStr = pendingFile.readAsStringSync();
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final type = data['type'] as String?;
    final source = data['source'] as String?;
    final target = data['target'] as String?;
    final step = data['step'] as String?;
    if (source == null || target == null || step == null) {
      throw const FormatException(
        'Pending operation is missing required fields',
      );
    }

    if (type == 'create') {
      await _recoverCreate(data, source, target, step);
    } else if (type == 'change') {
      await _recoverChange(data, source, target, step);
    }
    _logger.info('=== RECOVERY COMPLETE ===');
  } catch (e) {
    _logger.severe('Recovery failed: $e');
  } finally {
    tryDeletePendingFile(pendingFile);
  }
}

Future<void> _recoverCreate(
  Map<String, dynamic> data,
  String source,
  String target,
  String step,
) async {
  final backup = data['backup'] as String?;
  final moveData = data['moveData'] as bool? ?? true;
  final targetExisted = data['targetExisted'] as bool? ?? false;
  if (step == 'copying') {
    // Crash occurred during copying. Source is intact. Clean up target.
    _logger.info(
      'Recovery: Crash occurred during copying. Source is intact. Cleaning up target...',
    );
    final targetDir = Directory(target);
    if (!targetExisted && targetDir.existsSync()) {
      targetDir.deleteSync(recursive: true);
    }
    return;
  }

  if (step != 'linking') return;

  // Crash occurred during linking. Source was renamed to backup.
  _logger.info('Recovery: Crash occurred during linking. Verifying symlink...');
  final isLinkCorrect = await _linkPointsAt(source, target);

  if (isLinkCorrect) {
    _logger.info(
      'Recovery: Symlink is correct. Cleaning up backup directory...',
    );
    if (moveData && backup != null && Directory(backup).existsSync()) {
      Directory(backup).deleteSync(recursive: true);
    }
  } else {
    _logger.info('Recovery: Symlink is incorrect or missing. Rolling back...');
    if (await isSymlink(source)) {
      await WindowsNativeEngine.removeSymlink(source);
    }
    if (backup != null && Directory(backup).existsSync()) {
      await Directory(backup).rename(source);
    }
    final targetDir = Directory(target);
    if (!targetExisted && targetDir.existsSync()) {
      targetDir.deleteSync(recursive: true);
    }
  }
}

Future<void> _recoverChange(
  Map<String, dynamic> data,
  String source,
  String target,
  String step,
) async {
  final oldTarget = data['oldTarget'] as String?;
  if (oldTarget == null || oldTarget.trim().isEmpty) {
    throw const FormatException('Pending change is missing oldTarget');
  }
  final moveData = data['moveData'] as bool? ?? true;
  final targetExisted = data['targetExisted'] as bool? ?? false;
  if (step == 'copying') {
    // Crash occurred during changing target (copy phase). Clean up new target.
    _logger.info(
      'Recovery: Crash occurred during changing target (copy phase). Cleaning up new target...',
    );
    final targetDir = Directory(target);
    if (!targetExisted && targetDir.existsSync()) {
      targetDir.deleteSync(recursive: true);
    }
    return;
  }

  if (step != 'linking') return;

  // Crash occurred during changing target (linking phase).
  _logger.info(
    'Recovery: Crash occurred during changing target (linking phase). Verifying symlink...',
  );
  final isLinkCorrect = await _linkPointsAt(source, target);

  if (isLinkCorrect) {
    _logger.info(
      'Recovery: Symlink points to new target. Cleaning up old target...',
    );
    final oldTargetDir = Directory(oldTarget);
    if (moveData && oldTargetDir.existsSync()) {
      oldTargetDir.deleteSync(recursive: true);
    }
  } else {
    _logger.info(
      'Recovery: Symlink is incorrect/missing. Re-linking to old target...',
    );
    if (await isSymlink(source)) {
      await WindowsNativeEngine.removeSymlink(source);
    }
    await WindowsNativeEngine.createSymlink(source, oldTarget);
    final targetDir = Directory(target);
    if (!targetExisted && targetDir.existsSync()) {
      targetDir.deleteSync(recursive: true);
    }
  }
}

/// Whether the symlink at [source] exists and resolves to [target]
/// (case-insensitively, after path normalization).
Future<bool> _linkPointsAt(String source, String target) async {
  final linkExists = await isSymlink(source);
  final actualTarget = await getSymlinkTarget(source);
  return linkExists &&
      actualTarget != null &&
      normalizePath(actualTarget).toLowerCase() ==
          normalizePath(target).toLowerCase();
}
