import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_widgets.dart';
import 'preview_box.dart';

class GlassChangeDialog extends StatefulWidget {
  final String currentLinkPath;
  final String currentTargetPath;

  const GlassChangeDialog({
    super.key,
    required this.currentLinkPath,
    required this.currentTargetPath,
  });

  @override
  State<GlassChangeDialog> createState() => _GlassChangeDialogState();
}

class _GlassChangeDialogState extends State<GlassChangeDialog> {
  final _newTargetController = TextEditingController();
  bool _moveData = false;

  @override
  void dispose() {
    _newTargetController.dispose();
    super.dispose();
  }

  String get _appFolderName => p.basename(widget.currentLinkPath);

  String get _resolvedTargetPath {
    final target = _newTargetController.text.trim();
    if (target.isEmpty) return target;
    if (p.basename(target) == _appFolderName) return target;
    return p.join(target, _appFolderName);
  }

  Future<void> _pickFolder() async {
    final s = context.strings;
    String? result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: s.pickerSelectNewTarget,
    );
    if (result != null) {
      _newTargetController.text = result;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = theme.colors;
    final s = context.strings;

    return GlassDialog(
      title: s.dlgChangeTitle,
      icon: Icons.swap_horiz_rounded,
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
          customStartColor: c.accentAmber,
          customEndColor: c.accentRose,
          icon: Icons.swap_horiz_rounded,
          label: s.btnChangeTarget,
          onPressed: () {
            if (_newTargetController.text.trim().isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(s.errEnterTarget)));
              return;
            }
            Navigator.pop(context, {
              'newTarget': _resolvedTargetPath,
              'moveData': _moveData,
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
            // Current symlink info card
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
                      Icon(Icons.link_rounded, size: 16, color: c.accentCyan),
                      const SizedBox(width: 8),
                      Text(
                        s.labelCurrSymlink,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.currentLinkPath,
                    style: TextStyle(
                      fontFamily: 'Cascadia Code',
                      fontSize: 11.5,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.east_rounded, size: 14, color: c.accentAmber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.currentTargetPath,
                          style: TextStyle(
                            fontFamily: 'Cascadia Code',
                            fontSize: 11.5,
                            color: c.accentAmber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // New target input
            Text(
              s.labelNewTarget,
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
                      controller: _newTargetController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: c.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: s.hintNewTarget(_appFolderName),
                        hintStyle: TextStyle(color: c.textMuted, fontSize: 12),
                        icon: Icon(
                          Icons.drive_file_move_outlined,
                          size: 18,
                          color: c.accentAmber,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _pickFolder,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.accentAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: c.accentAmber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.folder_open_rounded,
                      color: c.accentAmber,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),

            if (_resolvedTargetPath.isNotEmpty) ...[
              const SizedBox(height: 12),
              PreviewBox(label: s.labelFinal, path: _resolvedTargetPath),
            ],

            const SizedBox(height: 14),

            InkWell(
              onTap: () => setState(() => _moveData = !_moveData),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.subCardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.subCardBorder),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _moveData,
                      activeColor: c.accentAmber,
                      onChanged: (v) => setState(() => _moveData = v ?? false),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.optMoveDataNew,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          Text(
                            s.optMoveDataNewSub,
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
    );
  }
}
