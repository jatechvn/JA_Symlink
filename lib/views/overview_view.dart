// lib/views/overview_view.dart
// Main overview dashboard view featuring Storage Savings Counter and Live Drive Space Bar

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../modules/logic/symlink_logic.dart';
import '../modules/storage/storage_model.dart';
import '../modules/symlink_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/live_drive_bar_widget.dart';
import '../widgets/quick_copy_button.dart';
import '../widgets/storage_distribution_chart.dart';
import '../widgets/storage_savings_card.dart';
import '../widgets/system_health_gauge.dart';

class OverviewView extends StatefulWidget {
  final List<SymlinkEntry> entries;
  final bool isAdmin;
  final VoidCallback onCreate;
  final VoidCallback onScan;
  final VoidCallback onVerify;
  final ValueChanged<int> onSelectTab;
  final SymlinkLogic? logic;

  const OverviewView({
    super.key,
    required this.entries,
    required this.isAdmin,
    required this.onCreate,
    required this.onScan,
    required this.onVerify,
    required this.onSelectTab,
    this.logic,
  });

  @override
  State<OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends State<OverviewView> {
  Timer? _driveTimer;
  List<DriveSpaceInfo> _drives = [];
  StorageSavingsSummary _savings = StorageSavingsSummary.empty;
  bool _isLoadingDrives = false;
  bool _isCalculatingSavings = false;

  @override
  void initState() {
    super.initState();
    _initStorageData();
    widget.logic?.storageService.addListener(_onStorageServiceChanged);
    _driveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_isLoadingDrives) _refreshDrives();
    });
  }

  @override
  void didUpdateWidget(covariant OverviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logic != widget.logic) {
      oldWidget.logic?.storageService.removeListener(_onStorageServiceChanged);
      widget.logic?.storageService.addListener(_onStorageServiceChanged);
    }
    if (oldWidget.entries.length != widget.entries.length ||
        oldWidget.logic != widget.logic) {
      _recalculateSavings();
    }
  }

  @override
  void dispose() {
    _driveTimer?.cancel();
    widget.logic?.storageService.removeListener(_onStorageServiceChanged);
    super.dispose();
  }

  void _onStorageServiceChanged() {
    if (!mounted) return;
    final svc = widget.logic?.storageService;
    if (svc != null) {
      setState(() {
        _drives = svc.drives;
        _savings = svc.savings;
        _isCalculatingSavings = svc.isScanning;
      });
    }
  }

  Future<void> _initStorageData() async {
    final logic = widget.logic;
    if (logic == null) return;

    setState(() {
      _isLoadingDrives = true;
      _isCalculatingSavings = true;
    });

    try {
      final drives = await logic.getDriveSpaces();
      final savings = await logic.calculateStorageSavings(widget.entries);
      if (!mounted) return;
      setState(() {
        _drives = drives;
        _savings = savings;
        _isLoadingDrives = false;
        _isCalculatingSavings = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingDrives = false;
          _isCalculatingSavings = false;
        });
      }
    }
  }

  Future<void> _refreshDrives() async {
    final logic = widget.logic;
    if (logic == null) return;
    setState(() => _isLoadingDrives = true);
    final drives = await logic.getDriveSpaces(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _drives = drives;
      _isLoadingDrives = false;
    });
  }

  Future<void> _recalculateSavings() async {
    final logic = widget.logic;
    if (logic == null) return;
    setState(() => _isCalculatingSavings = true);
    final savings = await logic.calculateStorageSavings(
      widget.entries,
      forceRefresh: true,
    );
    if (!mounted) return;
    setState(() {
      _savings = savings;
      _isCalculatingSavings = false;
    });
  }

  void _openDriveInExplorer(String letter) {
    widget.logic?.openDriveInExplorer(letter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;

    final activeCount = widget.entries.where((e) => e.isActive).length;
    final totalCount = widget.entries.length;
    final recentEntries = widget.entries.take(3).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bento Row: Hero Controller Card + Storage Savings Counter Card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 12,
                child: _HeroControllerCard(
                  colors: colors,
                  isAdmin: widget.isAdmin,
                  onCreate: widget.onCreate,
                  onScan: widget.onScan,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 12,
                child: StorageSavingsCard(
                  savings: _savings,
                  isScanning: _isCalculatingSavings,
                  onRelocateMore: () => widget.onSelectTab(1),
                  onRecalculate: _recalculateSavings,
                  colors: colors,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Middle Section: Live Drive Space Bar + Visual Intelligence (Health Gauge + Distribution Chart)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 13,
                child: LiveDriveBarWidget(
                  drives: _drives,
                  isLoading: _isLoadingDrives,
                  onRefresh: _refreshDrives,
                  onOpenExplorer: _openDriveInExplorer,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 11,
                child: Column(
                  children: [
                    SystemHealthGauge(
                      totalLinks: widget.entries
                          .where((e) => e.isActive || e.status == 'DANGLING')
                          .length,
                      activeLinks: activeCount,
                      brokenCount: widget.entries
                          .where((e) => e.status == 'DANGLING')
                          .length,
                      onVerify: widget.onVerify,
                      colors: colors,
                    ),
                    const SizedBox(height: 14),
                    StorageDistributionChart(savings: _savings, colors: colors),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Mini Metrics Row
          _MiniMetricsRow(
            colors: colors,
            totalCount: totalCount,
            activeCount: activeCount,
            savedGbFormatted: _savings.formattedSavedOnC,
            onSelectTab: widget.onSelectTab,
            onVerify: widget.onVerify,
          ),

          const SizedBox(height: 14),

          // Bottom Bento: Recent Symlinks preview
          _RecentSymlinksCard(
            recentEntries: recentEntries,
            colors: colors,
            onViewAll: () => widget.onSelectTab(2),
            onCreate: widget.onCreate,
            logic: widget.logic,
          ),
        ],
      ),
    );
  }
}

class _HeroControllerCard extends StatelessWidget {
  final AppColors colors;
  final bool isAdmin;
  final VoidCallback onCreate;
  final VoidCallback onScan;

  const _HeroControllerCard({
    required this.colors,
    required this.isAdmin,
    required this.onCreate,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return BentoCard(
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
                color: isAdmin ? colors.accentEmerald : colors.accentAmber,
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
    );
  }
}

class _MiniMetricsRow extends StatelessWidget {
  final AppColors colors;
  final int totalCount;
  final int activeCount;
  final String savedGbFormatted;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onVerify;

  const _MiniMetricsRow({
    required this.colors,
    required this.totalCount,
    required this.activeCount,
    required this.savedGbFormatted,
    required this.onSelectTab,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Row(
      children: [
        Expanded(
          child: _MiniCard(
            colors: colors,
            title: s.totalSymlinks,
            value: '$totalCount',
            icon: Icons.link_rounded,
            iconColor: colors.accentCyan,
            sub: s.trackedEntries,
            onTap: () => onSelectTab(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniCard(
            colors: colors,
            title: s.activeLinks,
            value: '$activeCount',
            icon: Icons.check_circle_rounded,
            iconColor: colors.accentEmerald,
            sub: s.onlineLinked,
            onTap: () => onSelectTab(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniCard(
            colors: colors,
            title: s.storageOffloaded.toUpperCase(),
            value: savedGbFormatted,
            icon: Icons.auto_awesome_rounded,
            iconColor: colors.accentAmber,
            sub: 'TIẾT KIỆM Ổ C',
            onTap: () => onSelectTab(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniCard(
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
    );
  }
}

class _MiniCard extends StatelessWidget {
  final AppColors colors;
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String sub;
  final VoidCallback onTap;

  const _MiniCard({
    required this.colors,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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

class _RecentSymlinksCard extends StatelessWidget {
  final List<SymlinkEntry> recentEntries;
  final AppColors colors;
  final VoidCallback onViewAll;
  final VoidCallback onCreate;
  final SymlinkLogic? logic;

  const _RecentSymlinksCard({
    required this.recentEntries,
    required this.colors,
    required this.onViewAll,
    required this.onCreate,
    this.logic,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return BentoCard(
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
                onTap: onViewAll,
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
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: EmptyStateCard(
                icon: Icons.link_off_rounded,
                title: s.emptySymlinksTitle,
                description: s.emptySymlinksDesc,
                buttonLabel: s.btnCreate.toUpperCase(),
                onAction: onCreate,
                colors: colors,
              ),
            )
          else
            ...recentEntries.map(
              (e) => _RecentSymlinkItem(entry: e, colors: colors, logic: logic),
            ),
        ],
      ),
    );
  }
}

class _RecentSymlinkItem extends StatelessWidget {
  final SymlinkEntry entry;
  final AppColors colors;
  final SymlinkLogic? logic;

  const _RecentSymlinkItem({
    required this.entry,
    required this.colors,
    this.logic,
  });

  @override
  Widget build(BuildContext context) {
    final stat = logic?.storageService.getStatForTarget(entry.targetPath);

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
          Icon(Icons.link_rounded, size: 16, color: colors.accentEmerald),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.linkPath,
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
                        entry.targetPath,
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
          if (stat != null && stat.sizeBytes > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.accentEmerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: colors.accentEmerald.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                stat.formattedSize,
                style: TextStyle(
                  fontFamily: 'Cascadia Code',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.accentEmerald,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          QuickCopyButton(textToCopy: entry.linkPath, colors: colors),
        ],
      ),
    );
  }
}
