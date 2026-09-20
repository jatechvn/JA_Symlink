// lib/modules/relocator/relocator_operation.dart
// Pre-flight space verification and safe execution of 1-Click Relocation.

import 'package:logging/logging.dart';
import '../logic.dart';
import 'relocator_model.dart';

final _logger = Logger('RelocatorOperation');

class RelocatorOperationResult {
  final bool success;
  final String message;

  const RelocatorOperationResult({
    required this.success,
    required this.message,
  });
}

/// Executes relocation with pre-flight storage safety checks
Future<RelocatorOperationResult> performRelocation({
  required SymlinkLogic logic,
  required RelocatorPreset preset,
  required String targetPath,
  void Function(double percent, String fileName, String sizeInfo)? onProgress,
}) async {
  final source = preset.actualPath;
  if (source == null || source.isEmpty) {
    return const RelocatorOperationResult(
      success: false,
      message: 'Đường dẫn thư mục nguồn không hợp lệ',
    );
  }

  // 1. Pre-flight Storage Check: Ensure target drive has enough free space + 500MB safety buffer
  const safetyBufferBytes = 500 * 1024 * 1024; // 500 MB
  final requiredBytes = preset.sizeBytes + safetyBufferBytes;

  int? targetDriveFreeBytes;
  try {
    targetDriveFreeBytes = await logic.relocatorService.getTargetFreeBytes(
      targetPath,
    );
  } catch (_) {
    targetDriveFreeBytes = null;
  }
  if (targetDriveFreeBytes == null || targetDriveFreeBytes < 0) {
    const message =
        'Không xác định được dung lượng ổ đích. Vui lòng kiểm tra lại ổ đĩa.';
    preset.status = RelocatorStatus.error;
    preset.statusMessage = message;
    return const RelocatorOperationResult(success: false, message: message);
  }

  if (targetDriveFreeBytes < requiredBytes) {
    final freeGb = (targetDriveFreeBytes / (1024 * 1024 * 1024))
        .toStringAsFixed(1);
    final needGb = (requiredBytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
    final msg =
        'Dung lượng ổ đích không đủ an toàn! Cần khoảng $needGb GB nhưng ổ đĩa chỉ còn $freeGb GB trống.';
    _logger.warning(msg);
    preset.status = RelocatorStatus.error;
    preset.statusMessage = msg;
    return RelocatorOperationResult(success: false, message: msg);
  }

  preset.status = RelocatorStatus.relocating;

  try {
    // 2. Perform create symlink with moveData = true
    final opResult = await logic.createSymlink(
      sourcePath: source,
      targetPath: targetPath,
      moveData: true,
      killProcesses: false,
      onProgress: onProgress,
    );

    if (opResult.success) {
      preset.status = RelocatorStatus.completed;
      preset.statusMessage = 'Đã di dời thành công và tạo Symlink an toàn!';
      preset.existingTargetPath = targetPath;
      return RelocatorOperationResult(success: true, message: opResult.message);
    } else {
      preset.status = RelocatorStatus.error;
      preset.statusMessage = opResult.message;
      return RelocatorOperationResult(
        success: false,
        message: opResult.message,
      );
    }
  } catch (e) {
    final msg = 'Lỗi trong quá trình di dời: $e';
    _logger.severe(msg);
    preset.status = RelocatorStatus.error;
    preset.statusMessage = msg;
    return RelocatorOperationResult(success: false, message: msg);
  }
}
