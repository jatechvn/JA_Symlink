// lib/modules/logic/pending_operation.dart
// Shared helpers for the crash-recovery "pending operation" transaction file
// and the best-effort rollback cleanup used by create/change operations.

import 'dart:convert';
import 'dart:io';

/// Overwrites [pendingFile] with a JSON description of the transaction step
/// currently in progress, so [performRecovery] can resume correctly if the
/// process dies before the operation finishes.
Future<void> writePendingOp(File pendingFile, Map<String, dynamic> data) {
  return pendingFile.writeAsString(jsonEncode(data));
}

/// Deletes [pendingFile] if present, swallowing any error.
///
/// Cleanup must never throw: the operation it guards has already succeeded or
/// failed by the time this runs, and a stray IO error here should not mask
/// that outcome.
void tryDeletePendingFile(File pendingFile) {
  if (!pendingFile.existsSync()) return;
  try {
    pendingFile.deleteSync();
  } catch (_) {}
}

/// Recursively deletes [dir] if it exists, swallowing any error.
void tryDeleteDir(Directory dir) {
  if (!dir.existsSync()) return;
  try {
    dir.deleteSync(recursive: true);
  } catch (_) {}
}

/// Renames the directory at [from] to [to], swallowing any error.
///
/// Used to restore a renamed-to-backup source directory during rollback; if
/// the rename itself fails there is nothing more rollback can safely do.
void tryRenameDir(String from, String to) {
  try {
    Directory(from).renameSync(to);
  } catch (_) {}
}
