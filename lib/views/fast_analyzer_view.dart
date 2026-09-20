// lib/views/fast_analyzer_view.dart
// Ultra-fast MFT / USN disk analyzer view with hierarchical folder tree

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dialogs/glass_create_dialog.dart';
import '../modules/fast_scan/fast_scan_model.dart';
import '../modules/i18n.dart';
import '../modules/logic.dart';
import '../modules/storage/storage_model.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/quick_copy_button.dart';

class FastAnalyzerView extends StatefulWidget {
  final SymlinkLogic logic;
  final VoidCallback onRefreshSymlinks;

  const FastAnalyzerView({
    super.key,
    required this.logic,
    required this.onRefreshSymlinks,
  });

  @override
  State<FastAnalyzerView> createState() => _FastAnalyzerViewState();
}

class _FastAnalyzerViewState extends State<FastAnalyzerView> {
  String _selectedDrive = 'C:';
  String _filterKeyword = '';
  bool _isTreeView = true;
  FolderTreeNode? _rootNode;
  String? _lastLoadedDrive;
  final TextEditingController _filterController = TextEditingController();

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    final service = widget.logic.fastScanService;
    if (service.isScanning) return;
    await service.scanDrive(_selectedDrive);
  }

  Future<void> _toggleNode(FolderTreeNode node) async {
    if (node.isDirectFiles) return;

    if (node.isExpanded) {
      setState(() {
        node.isExpanded = false;
      });
      return;
    }

    if (node.children.isNotEmpty) {
      setState(() {
        node.isExpanded = true;
      });
      return;
    }

    setState(() {
      node.isLoading = true;
    });

    final subfolders = await widget.logic.fastScanService.loadSubfolders(
      node.path,
      driveLetter: _selectedDrive,
      depth: node.depth + 1,
    );

    if (!mounted) return;
    setState(() {
      node.isLoading = false;
      node.children = subfolders;
      node.isExpanded = true;
    });
  }

  void _openInExplorer(String path) {
    if (Platform.isWindows) {
      Process.run('explorer.exe', [path]);
    }
  }

  void _openCreateSymlink(String sourcePath) {
    final theme = context.read<ThemeProvider>();
    final s = context.strings;
    showDialog<bool>(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => GlassDialog(
        title: s.dlgCreateTitle,
        isDark: theme.isDark,
        child: GlassCreateDialog(initialSourcePath: sourcePath),
      ),
    ).then((created) {
      if (created == true) {
        widget.onRefreshSymlinks();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final fastScan = widget.logic.fastScanService;
    final storage = widget.logic.storageService;

    return AnimatedBuilder(
      animation: Listenable.merge([fastScan, storage]),
      builder: (context, _) {
        final result = fastScan.currentResult;
        final isScanning = fastScan.isScanning;
        final drives = storage.drives;

        // Auto initialize root node when a new scan result arrives
        if (result != null && result.success) {
          if (_rootNode == null || _lastLoadedDrive != result.driveLetter) {
            _rootNode = result.buildRootTreeNode();
            _lastLoadedDrive = result.driveLetter;
          }
        } else if (result == null) {
          _rootNode = null;
          _lastLoadedDrive = null;
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FastScanHeader(
                colors: colors,
                isNative: fastScan.isNativeAvailable,
              ),
              const SizedBox(height: 16),
              _DriveSelectorBar(
                drives: drives,
                selectedDrive: _selectedDrive,
                colors: colors,
                onDriveSelected: isScanning
                    ? null
                    : (drive) => setState(() => _selectedDrive = drive),
              ),
              const SizedBox(height: 14),
              _ScanActionBar(
                selectedDrive: _selectedDrive,
                isScanning: isScanning,
                isTreeView: _isTreeView,
                colors: colors,
                onStartScan: _startScan,
                onToggleView: (val) => setState(() => _isTreeView = val),
                filterController: _filterController,
                onFilterChanged: (v) => setState(() => _filterKeyword = v),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _ScanResultsSection(
                  result: result,
                  rootNode: _rootNode,
                  isTreeView: _isTreeView,
                  isScanning: isScanning,
                  filterKeyword: _filterKeyword,
                  colors: colors,
                  onStartScan: _startScan,
                  onToggleNode: _toggleNode,
                  onRelocate: _openCreateSymlink,
                  onExplore: _openInExplorer,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Sub-components
// ─────────────────────────────────────────────

class _FastScanHeader extends StatelessWidget {
  final AppColors colors;
  final bool isNative;

  const _FastScanHeader({required this.colors, required this.isNative});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final badgeColor = isNative ? colors.accentEmerald : colors.accentCyan;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, color: colors.accentCyan, size: 24),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      s.fastScanTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                s.fastScanSubtitle,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        PillBadge(
          label: isNative ? s.fastScanEngineNative : s.fastScanEngineFallback,
          color: badgeColor,
          bg: badgeColor.withValues(alpha: 0.12),
          border: badgeColor.withValues(alpha: 0.35),
          icon: isNative ? Icons.speed_rounded : Icons.alt_route_rounded,
        ),
      ],
    );
  }
}

class _DriveSelectorBar extends StatelessWidget {
  final List<DriveSpaceInfo> drives;
  final String selectedDrive;
  final AppColors colors;
  final ValueChanged<String>? onDriveSelected;

  const _DriveSelectorBar({
    required this.drives,
    required this.selectedDrive,
    required this.colors,
    required this.onDriveSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (drives.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: drives.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final d = drives[index];
          final isSelected =
              d.letter.toUpperCase() == selectedDrive.toUpperCase();
          final borderColor = isSelected
              ? colors.accentCyan
              : colors.borderDefault;

          return InkWell(
            onTap: onDriveSelected == null
                ? null
                : () => onDriveSelected!(d.letter),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.accentCyan.withValues(alpha: 0.1)
                    : colors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        d.letter,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? colors.accentCyan
                              : colors.textPrimary,
                        ),
                      ),
                      Icon(
                        Icons.storage_rounded,
                        size: 16,
                        color: isSelected
                            ? colors.accentCyan
                            : colors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.formattedFree} free',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScanActionBar extends StatelessWidget {
  final String selectedDrive;
  final bool isScanning;
  final bool isTreeView;
  final AppColors colors;
  final VoidCallback onStartScan;
  final ValueChanged<bool> onToggleView;
  final TextEditingController filterController;
  final ValueChanged<String> onFilterChanged;

  const _ScanActionBar({
    required this.selectedDrive,
    required this.isScanning,
    required this.isTreeView,
    required this.colors,
    required this.onStartScan,
    required this.onToggleView,
    required this.filterController,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;

        return Row(
          children: [
            ElevatedButton.icon(
              onPressed: isScanning ? null : onStartScan,
              icon: isScanning
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.flash_on_rounded, size: 16),
              label: Text(
                isScanning ? s.fastScanBtnScanning : s.fastScanBtnStart,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.borderDefault),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: filterController,
                        onChanged: onFilterChanged,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: s.fastScanFilterHint,
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: colors.textSecondary.withValues(alpha: 0.6),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Segmented View Mode Toggle: Tree View vs Top Ranking
            Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: colors.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.borderDefault),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ViewModePill(
                    icon: Icons.account_tree_rounded,
                    label: isCompact ? null : s.fastScanViewTree,
                    tooltip: s.fastScanViewTree,
                    isSelected: isTreeView,
                    colors: colors,
                    onTap: () => onToggleView(true),
                  ),
                  const SizedBox(width: 3),
                  _ViewModePill(
                    icon: Icons.format_list_numbered_rounded,
                    label: isCompact ? null : s.fastScanViewRanking,
                    tooltip: s.fastScanViewRanking,
                    isSelected: !isTreeView,
                    colors: colors,
                    onTap: () => onToggleView(false),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ViewModePill extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  const _ViewModePill({
    required this.icon,
    this.label,
    required this.tooltip,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 8 : 7,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accentCyan.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isSelected
                  ? colors.accentCyan.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? colors.accentCyan : colors.textSecondary,
              ),
              if (label != null) ...[
                const SizedBox(width: 5),
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? colors.accentCyan
                        : colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanResultsSection extends StatelessWidget {
  final DriveScanResult? result;
  final FolderTreeNode? rootNode;
  final bool isTreeView;
  final bool isScanning;
  final String filterKeyword;
  final AppColors colors;
  final VoidCallback onStartScan;
  final Future<void> Function(FolderTreeNode node) onToggleNode;
  final void Function(String path) onRelocate;
  final void Function(String path) onExplore;

  const _ScanResultsSection({
    required this.result,
    required this.rootNode,
    required this.isTreeView,
    required this.isScanning,
    required this.filterKeyword,
    required this.colors,
    required this.onStartScan,
    required this.onToggleNode,
    required this.onRelocate,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;

    if (isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colors.accentCyan),
            const SizedBox(height: 16),
            Text(
              s.fastScanBtnScanning,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    if (result == null ||
        (result!.topHeavyFolders.isEmpty && result!.rootFolders.isEmpty)) {
      return EmptyStateCard(
        title: s.fastScanTitle,
        description: s.fastScanEmptyNotice,
        buttonLabel: s.fastScanBtnStart,
        onAction: onStartScan,
        icon: Icons.offline_bolt_rounded,
        colors: colors,
      );
    }

    final query = filterKeyword.trim().toLowerCase();
    final filteredFolders = result!.topHeavyFolders.where((f) {
      if (query.isEmpty) return true;
      return f.path.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricsBanner(result: result!, colors: colors),
        const SizedBox(height: 12),
        Expanded(
          child: isTreeView && rootNode != null
              ? _FolderTreeView(
                  rootNode: rootNode!,
                  totalDriveBytes: result!.totalSizeBytes,
                  filterKeyword: filterKeyword,
                  colors: colors,
                  onToggleNode: onToggleNode,
                  onRelocate: onRelocate,
                  onExplore: onExplore,
                )
              : _RankingListView(
                  folders: filteredFolders,
                  maxSize: result!.topHeavyFolders.isNotEmpty
                      ? result!.topHeavyFolders.first.sizeBytes
                      : 1,
                  colors: colors,
                  onRelocate: onRelocate,
                  onExplore: onExplore,
                ),
        ),
      ],
    );
  }
}

class _MetricsBanner extends StatelessWidget {
  final DriveScanResult result;
  final AppColors colors;

  const _MetricsBanner({required this.result, required this.colors});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final summary = s.fastScanScannedSummary(
      result.totalFilesScanned,
      result.totalDirectoriesScanned,
      result.formattedDuration,
    );

    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: colors.accentEmerald,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                summary,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          Text(
            result.formattedTotalSize,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Cascadia Code',
              fontWeight: FontWeight.w800,
              color: colors.accentCyan,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Hierarchical Folder Tree View Components
// ─────────────────────────────────────────────

class _FolderTreeView extends StatelessWidget {
  final FolderTreeNode rootNode;
  final int totalDriveBytes;
  final String filterKeyword;
  final AppColors colors;
  final Future<void> Function(FolderTreeNode node) onToggleNode;
  final void Function(String path) onRelocate;
  final void Function(String path) onExplore;

  const _FolderTreeView({
    required this.rootNode,
    required this.totalDriveBytes,
    required this.filterKeyword,
    required this.colors,
    required this.onToggleNode,
    required this.onRelocate,
    required this.onExplore,
  });

  List<FolderTreeNode> _buildVisibleList() {
    final query = filterKeyword.trim().toLowerCase();
    final List<FolderTreeNode> visible = [];

    void traverse(FolderTreeNode node) {
      visible.add(node);
      if (node.isExpanded) {
        for (final child in node.children) {
          if (query.isNotEmpty) {
            if (child.name.toLowerCase().contains(query) ||
                child.path.toLowerCase().contains(query)) {
              traverse(child);
            }
          } else {
            traverse(child);
          }
        }
      }
    }

    traverse(rootNode);
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final visibleNodes = _buildVisibleList();

    return BentoCard(
      colors: colors,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TreeHeaderRow(colors: colors),
          Divider(height: 1, thickness: 1, color: colors.borderDefault),
          Expanded(
            child: visibleNodes.isEmpty
                ? Center(
                    child: Text(
                      context.strings.fastScanNoSubfolders,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: visibleNodes.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: colors.borderDefault.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final node = visibleNodes[index];
                      return _FolderTreeNodeRow(
                        key: ValueKey(node.path),
                        node: node,
                        totalDriveBytes: totalDriveBytes,
                        colors: colors,
                        onToggleNode: () => onToggleNode(node),
                        onRelocate: () => onRelocate(node.path),
                        onExplore: () => onExplore(node.path),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TreeHeaderRow extends StatelessWidget {
  final AppColors colors;

  const _TreeHeaderRow({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.cardHoverBg.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Expanded(
            child: Text(
              'FOLDER / DIRECTORY',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: colors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              '% USAGE',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: colors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            width: 85,
            child: Text(
              'SIZE',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: colors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 75,
            child: Text(
              'FILES',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: colors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 140),
        ],
      ),
    );
  }
}

class _FolderTreeNodeRow extends StatefulWidget {
  final FolderTreeNode node;
  final int totalDriveBytes;
  final AppColors colors;
  final VoidCallback onToggleNode;
  final VoidCallback onRelocate;
  final VoidCallback onExplore;

  const _FolderTreeNodeRow({
    super.key,
    required this.node,
    required this.totalDriveBytes,
    required this.colors,
    required this.onToggleNode,
    required this.onRelocate,
    required this.onExplore,
  });

  @override
  State<_FolderTreeNodeRow> createState() => _FolderTreeNodeRowState();
}

class _FolderTreeNodeRowState extends State<_FolderTreeNodeRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final colors = widget.colors;
    final s = context.strings;
    final ratio = widget.totalDriveBytes > 0
        ? (node.sizeBytes / widget.totalDriveBytes).clamp(0.0, 1.0)
        : 0.0;
    final percentStr = '${(ratio * 100).toStringAsFixed(1)}%';

    final sizeColor = node.sizeBytes >= 10 * 1024 * 1024 * 1024
        ? colors.accentCyan
        : (node.sizeBytes >= 1024 * 1024 * 1024
              ? colors.accentAmber
              : colors.accentEmerald);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: _isHovered
            ? colors.cardHoverBg.withValues(alpha: 0.45)
            : Colors.transparent,
        child: InkWell(
          onTap: node.isDirectFiles ? null : widget.onToggleNode,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              8.0 + node.depth * 18.0,
              6.0,
              12.0,
              6.0,
            ),
            child: Row(
              children: [
                // Expand / Collapse Chevron or Spinner
                _buildExpandControl(node, colors),
                const SizedBox(width: 4),

                // Folder / File Icon
                _buildIcon(node, colors),
                const SizedBox(width: 8),

                // Name & Path Tooltip
                Expanded(
                  child: Tooltip(
                    message: node.isDirectFiles
                        ? s.fastScanDirectFiles
                        : node.path,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      node.name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: node.depth == 0
                            ? FontWeight.w800
                            : (node.isExpanded
                                  ? FontWeight.w700
                                  : FontWeight.w600),
                        color: node.isDirectFiles
                            ? colors.textSecondary
                            : colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Percentage Mini Bar
                SizedBox(
                  width: 90,
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 4,
                            backgroundColor: colors.borderDefault.withValues(
                              alpha: 0.25,
                            ),
                            valueColor: AlwaysStoppedAnimation(sizeColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        percentStr,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'Cascadia Code',
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Formatted Size
                SizedBox(
                  width: 85,
                  child: Text(
                    node.formattedSize,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Cascadia Code',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: sizeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // File count
                SizedBox(
                  width: 75,
                  child: Text(
                    '${node.fileCount}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Cascadia Code',
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Actions (Explorer, Symlink, Copy)
                _buildActionButtons(node, colors, s),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandControl(FolderTreeNode node, AppColors colors) {
    if (node.isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: colors.accentCyan,
            ),
          ),
        ),
      );
    }
    if (node.isDirectFiles || !node.hasChildren) {
      return const SizedBox(width: 20, height: 20);
    }
    return SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: AnimatedRotation(
          turns: node.isExpanded ? 0.25 : 0.0,
          duration: const Duration(milliseconds: 180),
          child: Icon(
            Icons.play_arrow_rounded,
            size: 15,
            color: colors.accentCyan,
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(FolderTreeNode node, AppColors colors) {
    if (node.isDirectFiles) {
      return Icon(
        Icons.insert_drive_file_outlined,
        size: 16,
        color: colors.accentAmber,
      );
    }
    if (node.depth == 0) {
      return Icon(Icons.storage_rounded, size: 16, color: colors.accentCyan);
    }
    return Icon(
      node.isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded,
      size: 16,
      color: colors.accentCyan.withValues(alpha: 0.85),
    );
  }

  Widget _buildActionButtons(
    FolderTreeNode node,
    AppColors colors,
    AppStrings s,
  ) {
    return SizedBox(
      width: 130,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          QuickCopyButton(
            textToCopy: node.path,
            colors: colors,
            tooltip: 'Sao chép đường dẫn',
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.folder_open_rounded, size: 15),
            color: colors.textSecondary,
            tooltip: s.fastScanExploreAction,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: widget.onExplore,
          ),
          const SizedBox(width: 4),
          if (!node.isDirectFiles && node.depth > 0)
            ElevatedButton(
              onPressed: widget.onRelocate,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentCyan.withValues(alpha: 0.15),
                foregroundColor: colors.accentCyan,
                elevation: 0,
                side: BorderSide(
                  color: colors.accentCyan.withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: const Size(0, 24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_rounded, size: 12),
                  SizedBox(width: 2),
                  Text(
                    'Symlink',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          else
            const SizedBox(width: 50),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Flat Ranking List View (Alternative Mode)
// ─────────────────────────────────────────────

class _RankingListView extends StatelessWidget {
  final List<FastFolderNode> folders;
  final int maxSize;
  final AppColors colors;
  final void Function(String path) onRelocate;
  final void Function(String path) onExplore;

  const _RankingListView({
    required this.folders,
    required this.maxSize,
    required this.colors,
    required this.onRelocate,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: folders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final folder = folders[index];
        return _FolderCard(
          rank: index + 1,
          folder: folder,
          maxSize: maxSize,
          colors: colors,
          onRelocate: () => onRelocate(folder.path),
          onExplore: () => onExplore(folder.path),
        );
      },
    );
  }
}

class _FolderCard extends StatelessWidget {
  final int rank;
  final FastFolderNode folder;
  final int maxSize;
  final AppColors colors;
  final VoidCallback onRelocate;
  final VoidCallback onExplore;

  const _FolderCard({
    required this.rank,
    required this.folder,
    required this.maxSize,
    required this.colors,
    required this.onRelocate,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final ratio = maxSize > 0
        ? (folder.sizeBytes / maxSize).clamp(0.0, 1.0)
        : 0.0;
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : (rank == 2
              ? const Color(0xFFC0C0C0)
              : (rank == 3 ? const Color(0xFFCD7F32) : colors.textSecondary));

    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Rank
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: rankColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Path
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.folderName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      folder.path,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              QuickCopyButton(
                textToCopy: folder.path,
                colors: colors,
                tooltip: 'Sao chép đường dẫn',
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                color: colors.textSecondary,
                tooltip: s.fastScanExploreAction,
                onPressed: onExplore,
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: onRelocate,
                icon: const Icon(Icons.link_rounded, size: 14),
                label: Text(
                  s.fastScanRelocateAction,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentCyan.withValues(alpha: 0.15),
                  foregroundColor: colors.accentCyan,
                  elevation: 0,
                  side: BorderSide(
                    color: colors.accentCyan.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Size Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    backgroundColor: colors.borderDefault.withValues(
                      alpha: 0.3,
                    ),
                    valueColor: AlwaysStoppedAnimation(colors.accentCyan),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                folder.formattedSize,
                style: TextStyle(
                  fontFamily: 'Cascadia Code',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: colors.accentCyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
