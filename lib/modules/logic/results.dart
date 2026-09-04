// lib/modules/logic/results.dart
// Result value types returned by SymlinkLogic operations

/// Result of any symlink operation with detailed info
class OperationResult {
  final bool success;
  final String message;
  final String? details;

  OperationResult({required this.success, required this.message, this.details});
}

/// Result of importing symlinks with detailed info
class ImportResult {
  final int total;
  final int success;
  final int skipped;
  final int failed;
  final List<String> details;

  ImportResult({
    required this.total,
    required this.success,
    required this.skipped,
    required this.failed,
    required this.details,
  });
}
