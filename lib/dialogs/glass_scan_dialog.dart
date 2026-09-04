import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_widgets.dart';

class GlassScanDialog extends StatelessWidget {
  final List<Map<String, String>> results;
  final Set<String> trackedLinks;

  const GlassScanDialog({
    super.key,
    required this.results,
    required this.trackedLinks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = theme.colors;
    final s = context.strings;

    return GlassDialog(
      title: s.scanTitle(results.length),
      icon: Icons.radar_rounded,
      isDark: theme.isDark,
      blurSigma: theme.dialogBlur,
      bgOpacity: theme.dialogOpacity,
      width: 700,
      height: 480,
      actions: [
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
                s.scanEmpty,
                style: TextStyle(color: c.textMuted, fontSize: 13),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = results[index];
                final link = item['link'] ?? '';
                final target = item['target'] ?? '';
                final isTracked = trackedLinks.contains(link.toLowerCase());
                final badgeText = isTracked ? s.badgeTracked : s.badgeUntracked;
                final badgeColor = isTracked ? c.accentEmerald : c.accentAmber;

                return BentoCard(
                  colors: c,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  borderRadius: 12,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          isTracked
                              ? Icons.link_rounded
                              : Icons.explore_outlined,
                          size: 16,
                          color: badgeColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  Clipboard.setData(ClipboardData(text: link)),
                              child: Text(
                                link,
                                style: TextStyle(
                                  fontFamily: 'Cascadia Code',
                                  fontSize: 12,
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 12,
                                  color: c.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    target,
                                    style: TextStyle(
                                      fontFamily: 'Cascadia Code',
                                      fontSize: 11,
                                      color: c.accentCyan,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      PillBadge(
                        label: badgeText,
                        color: badgeColor,
                        bg: badgeColor.withValues(alpha: 0.12),
                        border: badgeColor.withValues(alpha: 0.35),
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
