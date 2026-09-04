import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../modules/symlink_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_widgets.dart';

class OverviewView extends StatelessWidget {
  final List<SymlinkEntry> entries;
  final bool isAdmin;
  final VoidCallback onCreate;
  final VoidCallback onScan;
  final VoidCallback onVerify;
  final ValueChanged<int> onSelectTab;

  const OverviewView({
    super.key,
    required this.entries,
    required this.isAdmin,
    required this.onCreate,
    required this.onScan,
    required this.onVerify,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final s = context.strings;

    final activeCount = entries.where((e) => e.isActive).length;
    final changedCount = entries.where((e) => e.status == 'CHANGED').length;
    final removedCount = entries.where((e) => e.status == 'REMOVED').length;
    final totalCount = entries.length;

    // Distinct target drives
    final drives = <String>{};
    for (final e in entries.where((e) => e.isActive)) {
      if (e.targetPath.length >= 2 && e.targetPath[1] == ':') {
        drives.add(e.targetPath.substring(0, 2).toUpperCase());
      }
    }

    final recentEntries = entries.take(3).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bento Row: Hero Controller Card + Telemetry Card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Hero Controller Card
              Expanded(
                flex: 12,
                child: BentoCard(
                  colors: colors,
                  isFeatured: true,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PillBadge(
                            label: s.overviewController,
                            color: colors.accentCyan,
                            bg: colors.accentCyan.withValues(alpha: 0.12),
                            border: colors.accentCyan.withValues(alpha: 0.3),
                            icon: Icons.tune_rounded,
                          ),
                          PillBadge(
                            label: isAdmin
                                ? s.labelAdmin.toUpperCase()
                                : s.labelStandard.toUpperCase(),
                            color: isAdmin
                                ? colors.accentEmerald
                                : colors.accentAmber,
                            bg: isAdmin
                                ? colors.accentEmerald.withValues(alpha: 0.12)
                                : colors.accentAmber.withValues(alpha: 0.12),
                            border: isAdmin
                                ? colors.accentEmerald.withValues(alpha: 0.35)
                                : colors.accentAmber.withValues(alpha: 0.35),
                            showDot: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'JA Symlink Manager',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.overviewDescription,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: GlowingActionButton(
                              height: 44,
                              colors: colors,
                              icon: Icons.add_link_rounded,
                              label: s.btnCreate.toUpperCase(),
                              onPressed: onCreate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GlowingActionButton(
                              height: 44,
                              colors: colors,
                              customStartColor: colors.accentPurple,
                              customEndColor: colors.accentCyan,
                              icon: Icons.radar_rounded,
                              label: s.menuScan.toUpperCase(),
                              onPressed: onScan,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Right: Telemetry Console Card
              Expanded(
                flex: 11,
                child: BentoCard(
                  colors: colors,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PillBadge(
                            label: s.storageTelemetry,
                            color: colors.accentEmerald,
                            bg: colors.accentEmerald.withValues(alpha: 0.12),
                            border: colors.accentEmerald.withValues(alpha: 0.3),
                            icon: Icons.hub_rounded,
                          ),
                          WaveIndicator(
                            color: colors.accentEmerald,
                            height: 12,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.subCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.accentEmerald.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.storage_rounded,
                              size: 18,
                              color: colors.accentEmerald,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              drives.isEmpty
                                  ? s.noTargetDrives
                                  : s.drivesLabel(drives.join(', ')),
                              style: TextStyle(
                                color: colors.accentEmerald,
                                fontFamily: 'Cascadia Code',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '$activeCount',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: colors.accentEmerald,
                                  fontFamily: 'Cascadia Code',
                                ),
                              ),
                              Text(
                                s.filterActive,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: colors.subCardBorder,
                          ),
                          Column(
                            children: [
                              Text(
                                '$changedCount',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: colors.accentAmber,
                                  fontFamily: 'Cascadia Code',
                                ),
                              ),
                              Text(
                                s.filterChanged,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: colors.subCardBorder,
                          ),
                          Column(
                            children: [
                              Text(
                                '$removedCount',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: colors.accentRose,
                                  fontFamily: 'Cascadia Code',
                                ),
                              ),
                              Text(
                                s.filterRemoved,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Middle Bento Row: Mini Metrics Cards
          Row(
            children: [
              Expanded(
                child: _buildMiniCard(
                  colors: colors,
                  title: s.totalSymlinks,
                  value: '$totalCount',
                  icon: Icons.link_rounded,
                  iconColor: colors.accentCyan,
                  sub: s.trackedEntries,
                  onTap: () => onSelectTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniCard(
                  colors: colors,
                  title: s.activeLinks,
                  value: '$activeCount',
                  icon: Icons.check_circle_rounded,
                  iconColor: colors.accentEmerald,
                  sub: s.onlineLinked,
                  onTap: () => onSelectTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniCard(
                  colors: colors,
                  title: s.integrityVerify,
                  value: s.check,
                  icon: Icons.verified_user_rounded,
                  iconColor: colors.accentPurple,
                  sub: s.autoFixCsv,
                  onTap: onVerify,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Bottom Bento: Recent Symlinks preview
          BentoCard(
            colors: colors,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: colors.accentCyan,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.recentSymlinks,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => onSelectTab(1),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.viewAll,
                              style: TextStyle(
                                color: colors.accentCyan,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: colors.accentCyan,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (recentEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        s.emptyTitle,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  )
                else
                  ...recentEntries.map((e) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.subCardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.subCardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.link_rounded,
                            size: 16,
                            color: colors.accentEmerald,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.linkPath,
                                  style: TextStyle(
                                    fontFamily: 'Cascadia Code',
                                    fontSize: 11.5,
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 11,
                                      color: colors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        e.targetPath,
                                        style: TextStyle(
                                          fontFamily: 'Cascadia Code',
                                          fontSize: 11,
                                          color: colors.accentCyan,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: s.copyPath,
                            child: IconButton(
                              icon: Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: colors.textSecondary,
                              ),
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: e.linkPath),
                              ),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard({
    required AppColors colors,
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String sub,
    required VoidCallback onTap,
  }) {
    return BentoCard(
      colors: colors,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iconColor.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Segoe UI',
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cascadia Code',
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(color: colors.textSecondary, fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
