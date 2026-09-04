import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../modules/logic.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_widgets.dart';

class GlassImportDialog extends StatelessWidget {
  final ImportResult result;

  const GlassImportDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = theme.colors;
    final s = context.strings;

    return GlassDialog(
      title: s.dlgImportTitle,
      icon: Icons.import_export_rounded,
      isDark: theme.isDark,
      blurSigma: theme.dialogBlur,
      bgOpacity: theme.dialogOpacity,
      width: 680,
      height: 460,
      actions: [
        GlowingActionButton(
          height: 36,
          colors: c,
          icon: Icons.check_rounded,
          label: s.btnClose,
          onPressed: () => Navigator.pop(context),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.subCardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.subCardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: c.accentCyan,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.importSummaryMsg(
                        result.success,
                        result.skipped,
                        result.failed,
                      ),
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
            const SizedBox(height: 14),
            Text(
              s.importDetails,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: c.subCardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.subCardBorder),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: result.details.length,
                  separatorBuilder: (_, __) => Divider(
                    color: c.subCardBorder.withValues(alpha: 0.5),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final detail = result.details[index];
                    final localizedDetail = s.localizeImportDetail(detail);
                    Color textColor = c.textPrimary;
                    IconData icon = Icons.info_outline_rounded;
                    Color iconColor = c.textMuted;

                    if (detail.startsWith('Restored')) {
                      textColor = c.accentEmerald;
                      icon = Icons.check_circle_outline_rounded;
                      iconColor = c.accentEmerald;
                    } else if (detail.startsWith('Skipped')) {
                      textColor = c.textSecondary;
                      icon = Icons.warning_amber_rounded;
                      iconColor = c.accentAmber;
                    } else if (detail.startsWith('Failed')) {
                      textColor = c.accentRose;
                      icon = Icons.error_outline_rounded;
                      iconColor = c.accentRose;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6.0,
                        horizontal: 4.0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 14, color: iconColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              localizedDetail,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Cascadia Code',
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
