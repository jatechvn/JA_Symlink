// lib/modules/logic/symlink_logic.dart
// Main business logic coordinator for symlink operations.
// Each operation's implementation lives in its own file under lib/modules/logic/;
// this class just wires SymlinkService into them.

import '../native/win_core.dart';
import '../symlink_service.dart';
import 'change_operation.dart';
import 'create_operation.dart';
import 'import_export.dart';
import 'recovery.dart';
import 'remove_operation.dart';
import 'results.dart';
import 'verify_operation.dart';

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
  }) {
    return performCreateSymlink(
      service: _service,
      sourcePath: sourcePath,
      targetPath: targetPath,
      killProcesses: killProcesses,
      moveData: moveData,
      onProgress: onProgress,
    );
  }

  /// REMOVE SYMLINK
  /// Workflow: Validate -> rmdir (link only) -> Restore backup? -> Update CSV
  Future<OperationResult> removeSymlink({
    required String linkPath,
    bool restoreBackup = false,
  }) {
    return performRemoveSymlink(
      service: _service,
      linkPath: linkPath,
      restoreBackup: restoreBackup,
    );
  }

  Future<OperationResult> changeSymlink({
    required String linkPath,
    required String newTargetPath,
    bool moveData = false,
    void Function(double percent, String fileName, String sizeInfo)? onProgress,
  }) {
    return performChangeSymlink(
      service: _service,
      linkPath: linkPath,
      newTargetPath: newTargetPath,
      moveData: moveData,
      onProgress: onProgress,
    );
  }

  /// Recover from a crashed/interrupted symlink operation on app startup
  Future<void> recoverInterruptedOperation() => performRecovery();

  /// Check if running as admin
  Future<bool> isAdmin() async {
    return WindowsNativeEngine.isAdmin();
  }

  /// Elevate to admin, forwarding [args] (e.g. `-debug`) to the relaunched process
  Future<void> elevateAdmin([List<String> args = const []]) async {
    return WindowsNativeEngine.elevateAdmin(args);
  }

  /// Scan system for existing symlinks
  Future<List<Map<String, String>>> scanSystemSymlinks() async {
    return _service.scanSystemSymlinks();
  }

  /// VERIFY all ACTIVE symlinks: check actual state and fix CSV if needed
  /// Returns list of verification results
  Future<List<Map<String, String>>> verifyAndFixEntries() =>
      performVerifyAndFix(_service);

  /// Export active symlinks to a JSON file
  Future<OperationResult> exportSymlinks(String filePath) =>
      performExport(_service, filePath);

  /// Import symlinks from a JSON file and try to restore them
  Future<ImportResult> importSymlinks(String filePath) =>
      performImport(_service, filePath);
}
