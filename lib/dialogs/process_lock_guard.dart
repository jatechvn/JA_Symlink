import 'package:flutter/material.dart';
import '../modules/logic.dart';
import 'glass_process_lock_dialog.dart';

/// An explicit approval covers only the displayed PIDs. Errors abort the action.
Future<bool> confirmProcessLocks(
  BuildContext context,
  SymlinkLogic logic,
  String path,
) async {
  try {
    final locks = await logic.findLockingProcesses(path);
    if (!context.mounted) return false;
    if (locks.isEmpty) return true;
    final decision = await showDialog<bool>(
      context: context,
      builder: (_) =>
          GlassProcessLockDialog(processes: locks, folderPath: path),
    );
    if (decision == null || !context.mounted) return false;
    if (!decision) return true;
    final stopped = await logic.terminateProcesses(
      locks.map((p) => p.pid).toList(),
    );
    if (!context.mounted) return false;
    if (!stopped || (await logic.findLockingProcesses(path)).isNotEmpty) {
      throw StateError(
        'Không đóng được ứng dụng hoặc thư mục vẫn đang được sử dụng. Hãy đóng ứng dụng rồi thử lại.',
      );
    }
    return context.mounted;
  } catch (error) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Không thể tiếp tục'),
          content: Text('$error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    return false;
  }
}
