import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_widgets.dart';

class GlassVerifyDialog extends StatelessWidget {
  final List<Map<String, String>> results;

  const GlassVerifyDialog({super.key, required this.results});

  Color _statusColor(String status, dynamic c) {
    switch (status) {
      case 'OK':
        return c.accentEmerald;
      case 'FIXED':
        return c.accentAmber;
      case 'BROKEN':
      case 'MISSING':
      case 'ERROR':
        return c.accentRose;
      default:
        return c.textMuted;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'OK':
        return Icons.check_circle_rounded;
      case 'FIXED':
        return Icons.build_circle_rounded;
      case 'BROKEN':
        return Icons.error_rounded;
      case 'MISSING':
        return Icons.help_outline_rounded;
      case 'ERROR':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = theme.colors;
    final s = context.strings;

    final fixed = results.where((r) => r['status'] == 'FIXED').length;
    final ok = results.where((r) => r['status'] == 'OK').length;
    final broken = results
        .where((r) => r['status'] != 'OK' && r['status'] != 'FIXED')
        .length;

    return GlassDialog(
      title: s.dlgVerifyTitle,
      icon: Icons.verified_rounded,
      isDark: theme.isDark,
      blurSigma: theme.dialogBlur,
      bgOpacity: theme.dialogOpacity,
      width: 720,
      height: 480,
      headerTrailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.subCardBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: c.subCardBorder),
        ),
        child: Text(
          '$ok ✓   $fixed ⚡   $broken ✗',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: c.textSecondary,
            fontFamily: 'Segoe UI',
          ),
        ),
      ),
      actions: [
        if (fixed > 0) ...[
          Text(
            s.verifyFixedMsg(fixed),
            style: TextStyle(
              color: c.accentAmber,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
        ],
        GlowingActionButton(
          height: 36,
          colors: c,
          icon: Icons.check_rounded,
          label: s.btnClose,
          onPressed: () => Navigator.pop(context),
        ),
      ],
      child: results.isEmpty
          ? Center(
              child: Text(
                s.verifyEmpty,
                style: TextStyle(color: c.textMuted, fontSize: 13),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = results[index];
                final status = item['status'] ?? 'UNKNOWN';
                final color = _statusColor(status, c);

                return BentoCard(
                  colors: c,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  borderRadius: 12,
                  child: Row(
                    children: [
                      Icon(_statusIcon(status), size: 18, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['link'] ?? '',
                              style: TextStyle(
                                fontFamily: 'Cascadia Code',
                                fontSize: 12,
                                color: c.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  s.labelCsvTarget,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: c.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item['csvTarget'] ?? '',
                                    style: TextStyle(
                                      fontFamily: 'Cascadia Code',
                                      fontSize: 11,
                                      color: status == 'OK'
                                          ? c.accentEmerald
                                          : c.accentRose,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (status == 'FIXED') ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    s.labelActualTarget,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: c.accentAmber,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      item['actualTarget'] ?? '',
                                      style: TextStyle(
                                        fontFamily: 'Cascadia Code',
                                        fontSize: 11,
                                        color: c.accentEmerald,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PillBadge(
                        label: s.statusLabel(status),
                        color: color,
                        bg: color.withValues(alpha: 0.12),
                        border: color.withValues(alpha: 0.35),
                        fontSize: 10,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
