// lib/modules/logic/symlink_logic.dart
// Main business logic coordinator for symlink operations.
// Each operation's implementation lives in its own file under lib/modules/logic/;
// this class just wires SymlinkService into them.

import '../fast_scan/fast_scan_service.dart';
import '../health/health_watcher.dart';
import '../native/win_core.dart';
import '../process/process_lock_model.dart';
import '../process/process_lock_service.dart';
import '../relocator/relocator_service.dart';
import '../shell/shell_context_menu.dart';
import '../snapshot/snapshot_service.dart';
import '../storage/storage_intelligence_service.dart';
import '../storage/storage_model.dart';
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
  late final RelocatorService relocatorService = RelocatorService();
  late final HealthWatcher healthWatcher = HealthWatcher(_service);
  late final ProcessLockService processLockService = ProcessLockService();
  late final StorageIntelligenceService storageService =
      StorageIntelligenceService();
  late final FastScanService fastScanService = FastScanService();

  SymlinkLogic(this._service);

  /// Initialize the service and start live health monitoring
  Future<void> initialize() async {
    await _service.initialize();
    healthWatcher.startMonitoring();
  }

  void dispose() {
    healthWatcher.dispose();
    storageService.dispose();
    fastScanService.dispose();
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

  /// Generate standalone Windows Command Prompt (.bat) script for fresh install restore
  Future<String> generateRestoreBatchScript() async {
    final entries = await getAllEntries();
    return SnapshotService.generateBatchScript(entries);
  }

  /// Generate standalone PowerShell (.ps1) script for fresh install restore
  Future<String> generateRestorePowerShellScript() async {
    final entries = await getAllEntries();
    return SnapshotService.generatePowerShellScript(entries);
  }

  /// Export complete JSON snapshot
  Future<void> exportSnapshot(String filePath) async {
    final entries = await getAllEntries();
    await SnapshotService.exportSnapshotFile(
      entries: entries,
      filePath: filePath,
    );
  }

  /// Restore from JSON snapshot
  Future<SnapshotRestoreResult> restoreSnapshot(String filePath) {
    return SnapshotService.restoreFromSnapshot(filePath: filePath, logic: this);
  }

  /// Find processes locking a directory
  Future<List<ProcessLockInfo>> findLockingProcesses(String path) {
    return processLockService.findLockingProcesses(path);
  }

  /// Terminate processes by PIDs
  Future<bool> terminateProcesses(List<int> pids) {
    return processLockService.terminateProcesses(pids);
  }

  /// Check if Windows Explorer Context Menu is registered
  Future<bool> isContextMenuRegistered() {
    return ShellContextMenuService.isRegistered();
  }

  /// Register Windows Explorer Context Menu
  Future<bool> registerContextMenu({String? label, String? bgLabel}) {
    return ShellContextMenuService.register(label: label, bgLabel: bgLabel);
  }

  /// Unregister Windows Explorer Context Menu
  Future<bool> unregisterContextMenu() {
    return ShellContextMenuService.unregister();
  }

  /// Get list of logical drives with storage telemetry
  Future<List<DriveSpaceInfo>> getDriveSpaces({bool forceRefresh = false}) {
    return storageService.getLogicalDrives(forceRefresh: forceRefresh);
  }

  /// Open drive in Windows Explorer
  Future<void> openDriveInExplorer(String driveLetter) {
    return storageService.openDriveInExplorer(driveLetter);
  }

  /// Calculate storage savings for active symlinks
  Future<StorageSavingsSummary> calculateStorageSavings(
    List<SymlinkEntry> entries, {
    bool forceRefresh = false,
  }) {
    return storageService.calculateSavings(entries, forceRefresh: forceRefresh);
  }
}
