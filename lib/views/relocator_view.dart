// lib/views/relocator_view.dart
// 1-Click Smart Relocator View: scans and relocates massive dev/AI caches from C: to secondary drives.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dialogs/process_lock_guard.dart';
import '../modules/i18n.dart';
import '../modules/logic.dart';
import '../modules/relocator/relocator_model.dart';
import '../modules/relocator/relocator_operation.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_widgets.dart';

class RelocatorView extends StatefulWidget {
  final SymlinkLogic logic;
  final VoidCallback onRefreshSymlinks;

  const RelocatorView({
    super.key,
    required this.logic,
    required this.onRefreshSymlinks,
  });

  @override
  State<RelocatorView> createState() => _RelocatorViewState();
}

class _RelocatorViewState extends State<RelocatorView> {
  late List<RelocatorPreset> _presets;
  List<DriveTargetInfo> _drives = [];
  String _selectedDrive = 'D:';
  RelocatorCategory _selectedCategory = RelocatorCategory.all;
  bool _isScanning = false;
  String? _activeRelocatingId;
  double _progressPercent = 0.0;
  String _progressDetail = '';

  @override
  void initState() {
    super.initState();
    _presets = widget.logic.relocatorService.getBuiltInPresets();
    _loadDrivesAndScan();
  }

  Future<void> _loadDrivesAndScan() async {
    final drives = await widget.logic.relocatorService
        .getAvailableTargetDrives();
    if (!mounted) return;
    setState(() {
      _drives = drives;
      if (drives.isNotEmpty && !drives.any((d) => d.letter == _selectedDrive)) {
        _selectedDrive = drives.first.letter;
      }
    });
    await _scanAllPresets();
  }

  Future<void> _scanAllPresets() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    for (final preset in _presets) {
      if (!mounted) break;
      await widget.logic.relocatorService.scanPreset(preset);
      if (mounted) setState(() {});
    }

    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  DriveTargetInfo? get _currentDriveInfo {
    for (final d in _drives) {
      if (d.letter == _selectedDrive) return d;
    }
    return _drives.isNotEmpty ? _drives.first : null;
  }

  List<RelocatorPreset> get _filteredPresets {
    if (_selectedCategory == RelocatorCategory.all) return _presets;
    return _presets.where((p) => p.category == _selectedCategory).toList();
  }

  int get _totalRelocatableBytes {
    int total = 0;
    for (final p in _presets) {
      if (p.isRelocatable) total += p.sizeBytes;
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  Future<void> _startRelocation(RelocatorPreset preset) async {
    final targetPath = widget.logic.relocatorService.suggestTargetPath(
      preset,
      _selectedDrive,
    );

    final s = context.strings;
    final colors = context.read<ThemeProvider>().colors;

    // Show Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return GlassDialog(
          title: 'Xác nhận Di dời ${preset.name}',
          isDark: context.read<ThemeProvider>().isDark,
          width: 540,
          icon: preset.icon,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                s.btnCancel,
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            GlowingActionButton(
              label: 'Bắt đầu di dời',
              icon: Icons.drive_file_move_rounded,
              colors: colors,
              customStartColor: colors.accentEmerald,
              customEndColor: colors.accentCyan,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Thư mục dữ liệu sẽ được di chuyển an toàn sang ổ đĩa đích và tạo Symbolic Link tại vị trí ban đầu trên ổ C:',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              _buildPathReviewRow(
                'Nguồn (Source):',
                preset.actualPath ?? '',
                colors,
              ),
              const SizedBox(height: 8),
              _buildPathReviewRow('Đích (Target):', targetPath, colors),
              const SizedBox(height: 8),
              _buildPathReviewRow(
                'Dung lượng giải phóng:',
                preset.formattedSize,
                colors,
                isHighlight: true,
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final sourcePath = preset.actualPath ?? preset.pathResolver();
    if (!await confirmProcessLocks(context, widget.logic, sourcePath)) return;

    if (!mounted) return;

    setState(() {
      _activeRelocatingId = preset.id;
      _progressPercent = 0.0;
      _progressDetail = '';
    });

    final result = await performRelocation(
      logic: widget.logic,
      preset: preset,
      targetPath: targetPath,
      onProgress: (percent, file, size) {
        if (!mounted) return;
        setState(() {
          _progressPercent = percent;
          _progressDetail = '$file ($size)';
        });
      },
    );

    if (!mounted) return;

    setState(() {
      _activeRelocatingId = null;
      _progressPercent = 0.0;
      _progressDetail = '';
    });

    if (result.success) {
      widget.onRefreshSymlinks();
      showAppToast(
        context,
        colors: colors,
        message: 'Đã giải phóng thành công ${preset.formattedSize} cho ổ C!',
        icon: Icons.check_circle_rounded,
        accentColor: colors.accentEmerald,
      );
    } else {
      showAppToast(
        context,
        colors: colors,
        message: result.message,
        icon: Icons.error_outline_rounded,
        accentColor: colors.accentRose,
      );
    }
  }

  Widget _buildPathReviewRow(
    String label,
    String value,
    AppColors colors, {
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.subCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.subCardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlight ? colors.accentEmerald : colors.textPrimary,
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w500,
                fontFamily: isHighlight ? 'Cascadia Code' : 'Segoe UI',
              ),
              overflow: TextOverflow.ellipsis,
            ),
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Control Card
          _buildHeroControlCard(colors, s),

          const SizedBox(height: 14),

          // 2. Category Filter Pills
          _buildCategoryFilterRow(colors),

          const SizedBox(height: 14),

          // 3. Presets Grid
          _buildPresetsGrid(colors, s),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeroControlCard(AppColors colors, AppStrings s) {
    final drive = _currentDriveInfo;

    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.all(20),
      borderRadius: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Info & Title
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PillBadge(
                      label: 'SMART RELOCATOR',
                      color: colors.accentCyan,
                      bg: colors.accentCyan.withValues(alpha: 0.12),
                      border: colors.accentCyan.withValues(alpha: 0.3),
                      icon: Icons.auto_awesome_rounded,
                    ),
                    const SizedBox(width: 8),
                    if (_isScanning)
                      Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.accentAmber,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Đang quét ổ đĩa...',
                            style: TextStyle(
                              color: colors.accentAmber,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  s.relocatorTitle,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.relocatorSubtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                if (_totalRelocatableBytes > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Có thể giải phóng: ${_formatBytes(_totalRelocatableBytes)}',
                    style: TextStyle(
                      color: colors.accentCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 20),

          // Right: Drive Selector & Scan Button
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.subCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.subCardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.targetDriveLabel,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (drive != null)
                        Text(
                          drive.formattedFree,
                          style: TextStyle(
                            color: colors.accentEmerald,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Cascadia Code',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.borderDefault),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedDrive,
                              dropdownColor: colors.sidebarBg,
                              isExpanded: true,
                              icon: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: colors.accentCyan,
                              ),
                              items: _drives.map((d) {
                                return DropdownMenuItem<String>(
                                  value: d.letter,
                                  child: Text(
                                    'Ổ đĩa ${d.letter} (${d.formattedFree})',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedDrive = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: s.btnScanAll,
                        onPressed: _isScanning ? null : _scanAllPresets,
                        style: IconButton.styleFrom(
                          backgroundColor: colors.accentColor.withValues(
                            alpha: 0.15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: colors.accentCyan,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterRow(AppColors colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: RelocatorCategory.values.map((cat) {
          final isSelected = cat == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedCategory = cat),
              borderRadius: BorderRadius.circular(100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.accentColor.withValues(alpha: 0.2)
                      : colors.subCardBg,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? colors.accentCyan
                        : colors.subCardBorder,
                    width: isSelected ? 1.2 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 14,
                      color: isSelected ? colors.accentCyan : colors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat.label,
                      style: TextStyle(
                        color: isSelected
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPresetsGrid(AppColors colors, AppStrings s) {
    final presets = _filteredPresets;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 960
            ? 3
            : (constraints.maxWidth > 640 ? 2 : 1);
        final cardWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: presets.map((preset) {
            return SizedBox(
              width: cardWidth,
              child: _buildPresetCard(preset, colors, s),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPresetCard(
    RelocatorPreset preset,
    AppColors colors,
    AppStrings s,
  ) {
    final isRelocatingThis = _activeRelocatingId == preset.id;
    final accent = preset.accentColor ?? colors.accentCyan;

    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.all(16),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Name + Category Pill
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Icon(preset.icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preset.category.label,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Description
          Text(
            preset.description,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.5,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // Bottom Action & Status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Size Badge or Status Label
              _buildPresetStatusBadge(preset, colors, s),

              // Action Button
              if (preset.isRelocatable && !isRelocatingThis)
                GlowingActionButton(
                  height: 32,
                  colors: colors,
                  customStartColor: accent,
                  customEndColor: colors.accentColor,
                  icon: Icons.drive_file_move_rounded,
                  label: '${s.btnRelocate} $_selectedDrive',
                  onPressed: () => _startRelocation(preset),
                )
              else if (isRelocatingThis)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        value: _progressPercent > 0 ? _progressPercent : null,
                        strokeWidth: 2,
                        color: colors.accentCyan,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(_progressPercent * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: colors.accentCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cascadia Code',
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (isRelocatingThis && _progressDetail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _progressDetail,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 10.5,
                fontFamily: 'Cascadia Code',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetStatusBadge(
    RelocatorPreset preset,
    AppColors colors,
    AppStrings s,
  ) {
    switch (preset.status) {
      case RelocatorStatus.scanning:
        return Text(
          'Đang tính...',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        );
      case RelocatorStatus.detected:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colors.accentAmber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colors.accentAmber.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storage_rounded, size: 12, color: colors.accentAmber),
              const SizedBox(width: 4),
              Text(
                preset.formattedSize,
                style: TextStyle(
                  color: colors.accentAmber,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Cascadia Code',
                ),
              ),
            ],
          ),
        );
      case RelocatorStatus.alreadySymlinked:
        return PillBadge(
          label: s.alreadySymlinked,
          color: colors.accentEmerald,
          bg: colors.accentEmerald.withValues(alpha: 0.12),
          border: colors.accentEmerald.withValues(alpha: 0.3),
          showDot: true,
        );
      case RelocatorStatus.completed:
        return PillBadge(
          label: 'Đã di dời thành công',
          color: colors.accentEmerald,
          bg: colors.accentEmerald.withValues(alpha: 0.12),
          border: colors.accentEmerald.withValues(alpha: 0.3),
          icon: Icons.check_circle_rounded,
        );
      case RelocatorStatus.notFound:
      default:
        return Text(
          s.notFound,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        );
    }
  }
}
