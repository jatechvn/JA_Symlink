import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../modules/symlink_service.dart';
import '../theme/theme_provider.dart';
import '../widgets/filter_search_dock.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_widgets.dart';

class SymlinkListView extends StatefulWidget {
  final List<SymlinkEntry> entries;
  final VoidCallback onCreate;
  final ValueChanged<SymlinkEntry> onChange;
  final ValueChanged<SymlinkEntry> onRemove;
  final VoidCallback onRefresh;

  const SymlinkListView({
    super.key,
    required this.entries,
    required this.onCreate,
    required this.onChange,
    required this.onRemove,
    required this.onRefresh,
  });

  @override
  State<SymlinkListView> createState() => _SymlinkListViewState();
}

class _SymlinkListViewState extends State<SymlinkListView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'ALL';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SymlinkEntry> get _filteredEntries {
    return widget.entries.where((e) {
      // 1. Filter by status
      if (_selectedFilter != 'ALL' && e.status != _selectedFilter) {
        return false;
      }
      // 2. Filter by search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchLink = e.linkPath.toLowerCase().contains(q);
        final matchTarget = e.targetPath.toLowerCase().contains(q);
        final matchBackup = e.backupPath.toLowerCase().contains(q);
        return matchLink || matchTarget || matchBackup;
      }
      return true;
    }).toList();
  }

  void _showDetail(BuildContext context, SymlinkEntry entry) {
    final theme = context.read<ThemeProvider>();
    final c = theme.colors;
    final s = context.strings;

    Color badgeColor = c.accentEmerald;
    if (entry.status == 'CHANGED') badgeColor = c.accentAmber;
    if (entry.status == 'REMOVED') badgeColor = c.accentRose;

    showDialog(
      context: context,
      builder: (_) => DetailDialog(
        title: s.detailTitle,
        isDark: theme.isDark,
        badges: [
          PillBadge(
            label: s.statusLabel(entry.status),
            color: badgeColor,
            bg: badgeColor.withValues(alpha: 0.12),
            border: badgeColor.withValues(alpha: 0.35),
            showDot: true,
          ),
          if (entry.hasBackup)
            PillBadge(
              label: s.hasBackup,
              color: c.accentCyan,
              bg: c.accentCyan.withValues(alpha: 0.12),
              border: c.accentCyan.withValues(alpha: 0.35),
              icon: Icons.backup_rounded,
            ),
        ],
        subtitle:
            '${s.timestampLabel}: ${entry.timestamp.replaceAll('_', ' ')}',
        description: s.detailDescription,
        tags: [
          '${s.sourceLabel}: ${entry.linkPath}',
          '${s.targetLabel}: ${entry.targetPath}',
          if (entry.hasBackup) '${s.backupLabel}: ${entry.backupPath}',
        ],
        actions: [
          if (entry.isActive) ...[
            GlowingActionButton(
              height: 36,
              colors: c,
              customStartColor: c.accentAmber,
              customEndColor: c.accentRose,
              icon: Icons.swap_horiz_rounded,
              label: s.btnChange,
              onPressed: () {
                Navigator.pop(context);
                widget.onChange(entry);
              },
            ),
            const SizedBox(width: 8),
            GlowingActionButton(
              height: 36,
              colors: c,
              isDestructive: true,
              icon: Icons.delete_outline_rounded,
              label: s.btnRemove,
              onPressed: () {
                Navigator.pop(context);
                widget.onRemove(entry);
              },
            ),
            const SizedBox(width: 8),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.btnClose, style: TextStyle(color: c.textSecondary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final s = context.strings;

    final filterCounts = {
      'ALL': widget.entries.length,
      'ACTIVE': widget.entries.where((e) => e.isActive).length,
      'CHANGED': widget.entries.where((e) => e.status == 'CHANGED').length,
      'REMOVED': widget.entries.where((e) => e.status == 'REMOVED').length,
    };

    final filterLabels = {
      'ALL': s.filterAll,
      'ACTIVE': s.filterActive,
      'CHANGED': s.filterChanged,
      'REMOVED': s.filterRemoved,
    };

    final filtered = _filteredEntries;

    return Column(
      children: [
        // Top Search & Filter Dock
        FilterSearchDock(
          colors: colors,
          filters: const ['ALL', 'ACTIVE', 'CHANGED', 'REMOVED'],
          selectedFilter: _selectedFilter,
          filterCounts: filterCounts,
          filterLabels: filterLabels,
          searchController: _searchController,
          searchHint: s.searchPathsHint,
          onFilterSelected: (f) => setState(() => _selectedFilter = f),
          onSearchChanged: (q) => setState(() => _searchQuery = q.trim()),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlowingActionButton(
                height: 36,
                colors: colors,
                icon: Icons.add_link_rounded,
                label: s.btnCreate,
                onPressed: widget.onCreate,
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: s.tooltipRefresh,
                child: InkWell(
                  onTap: widget.onRefresh,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.subCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.subCardBorder),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // List of Bento Cards
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: BentoCard(
                    colors: colors,
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.link_off_rounded,
                          size: 48,
                          color: colors.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.emptyTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.emptySubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        GlowingActionButton(
                          height: 38,
                          colors: colors,
                          icon: Icons.add_link_rounded,
                          label: s.btnCreate,
                          onPressed: widget.onCreate,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final isFeatured = entry.isActive;

                    Color statusColor = colors.accentEmerald;
                    if (entry.status == 'CHANGED') {
                      statusColor = colors.accentAmber;
                    }
                    if (entry.status == 'REMOVED') {
                      statusColor = colors.accentRose;
                    }

                    return BentoCard(
                      colors: colors,
                      onTap: () => _showDetail(context, entry),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          // Status icon box
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              entry.isActive
                                  ? Icons.link_rounded
                                  : (entry.status == 'CHANGED'
                                        ? Icons.swap_horiz_rounded
                                        : Icons.link_off_rounded),
                              size: 18,
                              color: statusColor,
                            ),
                          ),

                          const SizedBox(width: 14),

                          // Paths & metadata
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.linkPath,
                                        style: TextStyle(
                                          fontFamily: 'Cascadia Code',
                                          fontSize: 12.5,
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    PillBadge(
                                      label: s.statusLabel(entry.status),
                                      color: statusColor,
                                      bg: statusColor.withValues(alpha: 0.12),
                                      border: statusColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      showDot: isFeatured,
                                      fontSize: 10,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 13,
                                      color: colors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        entry.targetPath,
                                        style: TextStyle(
                                          fontFamily: 'Cascadia Code',
                                          fontSize: 11.5,
                                          color: colors.accentCyan,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (entry.hasBackup) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.backup_rounded,
                                        size: 11,
                                        color: colors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${s.backupLabel}: ${entry.backupPath}',
                                          style: TextStyle(
                                            fontFamily: 'Cascadia Code',
                                            fontSize: 10.5,
                                            color: colors.textMuted,
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

                          const SizedBox(width: 12),

                          // Quick Action Buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: s.copyPath,
                                child: InkWell(
                                  onTap: () => Clipboard.setData(
                                    ClipboardData(text: entry.linkPath),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: colors.subCardBg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: colors.subCardBorder,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.copy_rounded,
                                      size: 14,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              if (entry.isActive) ...[
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: s.btnChange,
                                  child: InkWell(
                                    onTap: () => widget.onChange(entry),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: colors.accentAmber.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: colors.accentAmber.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.swap_horiz_rounded,
                                        size: 14,
                                        color: colors.accentAmber,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: s.btnRemove,
                                  child: InkWell(
                                    onTap: () => widget.onRemove(entry),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: colors.accentRose.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: colors.accentRose.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 14,
                                        color: colors.accentRose,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
