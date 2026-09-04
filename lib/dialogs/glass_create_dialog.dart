import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_widgets.dart';
import 'preview_box.dart';

class GlassCreateDialog extends StatefulWidget {
  const GlassCreateDialog({super.key});

  @override
  State<GlassCreateDialog> createState() => _GlassCreateDialogState();
}

class _GlassCreateDialogState extends State<GlassCreateDialog> {
  final _sourceController = TextEditingController();
  final _targetController = TextEditingController();
  bool _moveData = true;
  bool _killProcesses = true;

  @override
  void dispose() {
    _sourceController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  String get _resolvedTargetPath {
    final source = _sourceController.text.trim();
    final target = _targetController.text.trim();
    if (source.isEmpty || target.isEmpty) return target;
    final appName = p.basename(source);
    if (p.basename(target) == appName) return target;
    return p.join(target, appName);
  }

  Future<void> _pickFolder(TextEditingController controller) async {
    final s = context.strings;
    String? result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: s.pickerSelectFolder,
    );
    if (result != null) {
      controller.text = result;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = theme.colors;
    final s = context.strings;

    return GlassDialog(
      title: s.dlgCreateTitle,
      icon: Icons.add_link_rounded,
      isDark: theme.isDark,
      blurSigma: theme.dialogBlur,
      bgOpacity: theme.dialogOpacity,
      width: 580,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.btnCancel, style: TextStyle(color: c.textSecondary)),
        ),
        const SizedBox(width: 8),
        GlowingActionButton(
          height: 38,
          colors: c,
          icon: Icons.link_rounded,
          label: s.btnCreateSymlink,
          onPressed: () {
            if (_sourceController.text.trim().isEmpty ||
                _targetController.text.trim().isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(s.errFillPaths)));
              return;
            }
            Navigator.pop(context, {
              'source': _sourceController.text.trim(),
              'target': _resolvedTargetPath,
              'moveData': _moveData,
              'killProcesses': _killProcesses,
            });
          },
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.dlgCreateDesc,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Source path input
            Text(
              s.labelSourcePath,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.subCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.subCardBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _sourceController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: c.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: s.hintSourcePath,
                        hintStyle: TextStyle(color: c.textMuted, fontSize: 12),
                        icon: Icon(
                          Icons.folder_outlined,
                          size: 18,
                          color: c.accentCyan,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _pickFolder(_sourceController),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: c.accentCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.folder_open_rounded,
                      color: c.accentCyan,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Target path input
            Text(
              s.labelTargetFolder,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.subCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.subCardBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _targetController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: c.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: s.hintTargetFolder,
                        hintStyle: TextStyle(color: c.textMuted, fontSize: 12),
                        icon: Icon(
                          Icons.drive_file_move_outlined,
                          size: 18,
                          color: c.accentEmerald,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _pickFolder(_targetController),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.accentEmerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: c.accentEmerald.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.folder_open_rounded,
                      color: c.accentEmerald,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),

            if (_resolvedTargetPath.isNotEmpty &&
                _sourceController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              PreviewBox(label: s.labelFinal, path: _resolvedTargetPath),
            ],

            const SizedBox(height: 16),

            // Options box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.subCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.subCardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 16, color: c.accentPurple),
                      const SizedBox(width: 8),
                      Text(
                        s.labelOptions,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => setState(() => _moveData = !_moveData),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _moveData,
                            activeColor: c.accentColor,
                            onChanged: (v) =>
                                setState(() => _moveData = v ?? true),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.optMoveData,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
                                  ),
                                ),
                                Text(
                                  s.optMoveDataSub,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: c.subCardBorder, height: 12),
                  InkWell(
                    onTap: () =>
                        setState(() => _killProcesses = !_killProcesses),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _killProcesses,
                            activeColor: c.accentColor,
                            onChanged: (v) =>
                                setState(() => _killProcesses = v ?? true),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.optKillProc,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
                                  ),
                                ),
                                Text(
                                  s.optKillProcSub,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
