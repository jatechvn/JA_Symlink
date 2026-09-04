import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_widgets.dart';

class GlassRemoveDialog extends StatefulWidget {
  final String linkPath;
  final String targetPath;
  final bool hasBackup;

  const GlassRemoveDialog({
    super.key,
    required this.linkPath,
    required this.targetPath,
    this.hasBackup = false,
  });

  @override
  State<GlassRemoveDialog> createState() => _GlassRemoveDialogState();
}

class _GlassRemoveDialogState extends State<GlassRemoveDialog> {
  bool _restoreBackup = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = theme.colors;
    final s = context.strings;

    return GlassDialog(
      title: s.dlgRemoveTitle,
      icon: Icons.link_off_rounded,
      isDark: theme.isDark,
      blurSigma: theme.dialogBlur,
      bgOpacity: theme.dialogOpacity,
      width: 540,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.btnCancel, style: TextStyle(color: c.textSecondary)),
        ),
        const SizedBox(width: 8),
        GlowingActionButton(
          height: 38,
          colors: c,
          isDestructive: true,
          icon: Icons.delete_outline_rounded,
          label: s.btnRemoveConfirm,
          onPressed: () =>
              Navigator.pop(context, {'restoreBackup': _restoreBackup}),
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Alert Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.accentRose.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.accentRose.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: c.accentRose,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.warnRemove,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Path information
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
                      Icon(Icons.link_rounded, size: 16, color: c.accentRose),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.linkPath,
                          style: TextStyle(
                            fontFamily: 'Cascadia Code',
                            fontSize: 11.5,
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: c.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.targetPath,
                          style: TextStyle(
                            fontFamily: 'Cascadia Code',
                            fontSize: 11.5,
                            color: c.accentCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (widget.hasBackup) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: () => setState(() => _restoreBackup = !_restoreBackup),
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
                        value: _restoreBackup,
                        activeColor: c.accentRose,
                        onChanged: (v) =>
                            setState(() => _restoreBackup = v ?? false),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.optRestoreBackup,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                            Text(
                              s.optRestoreBackupSub,
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
          ],
        ),
      ),
    );
  }
}
