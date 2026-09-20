// lib/widgets/live_drive_bar_widget.dart
// Real-time visual progress bar widget for all Windows drives in Bento Grid

import 'package:flutter/material.dart';
import '../modules/i18n.dart';
import '../modules/storage/storage_model.dart';
import '../theme/app_colors.dart';
import 'glass_widgets.dart';

class LiveDriveBarWidget extends StatelessWidget {
  final List<DriveSpaceInfo> drives;
  final bool isLoading;
  final VoidCallback onRefresh;
  final ValueChanged<String> onOpenExplorer;
  final AppColors colors;

  const LiveDriveBarWidget({
    super.key,
    required this.drives,
    required this.isLoading,
    required this.onRefresh,
    required this.onOpenExplorer,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _DriveBarHeader(
            colors: colors,
            isLoading: isLoading,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 12),
          if (drives.isEmpty && isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (drives.isEmpty)
            _EmptyDrivesNotice(colors: colors)
          else
            _DriveItemList(
              drives: drives,
              colors: colors,
              onOpenExplorer: onOpenExplorer,
            ),
        ],
      ),
    );
  }
}

class _DriveBarHeader extends StatelessWidget {
  final AppColors colors;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _DriveBarHeader({
    required this.colors,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PillBadge(
              label: s.driveSpaceTitle,
              color: colors.accentCyan,
              bg: colors.accentCyan.withValues(alpha: 0.12),
              border: colors.accentCyan.withValues(alpha: 0.35),
              icon: Icons.storage_rounded,
            ),
            const SizedBox(width: 8),
            WaveIndicator(color: colors.accentCyan, height: 10),
          ],
        ),
        IconButton(
          icon: isLoading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.accentCyan,
                  ),
                )
              : Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: colors.textSecondary,
                ),
          tooltip: s.driveRefreshTooltip,
          onPressed: isLoading ? null : onRefresh,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class _EmptyDrivesNotice extends StatelessWidget {
  final AppColors colors;

  const _EmptyDrivesNotice({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          'Không tìm thấy ổ đĩa',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}

class _DriveItemList extends StatelessWidget {
  final List<DriveSpaceInfo> drives;
  final AppColors colors;
  final ValueChanged<String> onOpenExplorer;

  const _DriveItemList({
    required this.drives,
    required this.colors,
    required this.onOpenExplorer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < drives.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _DriveItemCard(
            drive: drives[i],
            colors: colors,
            onOpen: () => onOpenExplorer(drives[i].letter),
          ),
        ],
      ],
    );
  }
}

class _DriveItemCard extends StatelessWidget {
  final DriveSpaceInfo drive;
  final AppColors colors;
  final VoidCallback onOpen;

  const _DriveItemCard({
    required this.drive,
    required this.colors,
    required this.onOpen,
  });

  Color _getBarColor() {
    switch (drive.urgency) {
      case DriveUrgency.critical:
        return colors.accentRose;
      case DriveUrgency.warning:
        return colors.accentAmber;
      case DriveUrgency.normal:
        return drive.isSystemDrive ? colors.accentCyan : colors.accentEmerald;
    }
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _getBarColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.subCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: drive.urgency == DriveUrgency.critical
              ? colors.accentRose.withValues(alpha: 0.35)
              : colors.subCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DriveCardTopRow(
            drive: drive,
            colors: colors,
            barColor: barColor,
            onOpen: onOpen,
          ),
          const SizedBox(height: 7),
          _DriveProgressBar(
            percent: drive.usedPercent,
            barColor: barColor,
            colors: colors,
          ),
          const SizedBox(height: 6),
          _DriveCardBottomRow(drive: drive, colors: colors, barColor: barColor),
        ],
      ),
    );
  }
}

class _DriveCardTopRow extends StatelessWidget {
  final DriveSpaceInfo drive;
  final AppColors colors;
  final Color barColor;
  final VoidCallback onOpen;

  const _DriveCardTopRow({
    required this.drive,
    required this.colors,
    required this.barColor,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Row(
      children: [
        Icon(
          drive.driveKind == DriveKind.removable
              ? Icons.usb_rounded
              : Icons.dns_rounded,
          size: 15,
          color: barColor,
        ),
        const SizedBox(width: 6),
        Text(
          drive.letter,
          style: TextStyle(
            fontFamily: 'Cascadia Code',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        if (drive.label.isNotEmpty) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              drive.label,
              style: TextStyle(
                fontSize: 11.5,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Spacer(),
        _DriveKindBadge(drive: drive, colors: colors),
        const SizedBox(width: 4),
        Tooltip(
          message: s.driveOpenExplorer,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(
                Icons.open_in_new_rounded,
                size: 13,
                color: colors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DriveKindBadge extends StatelessWidget {
  final DriveSpaceInfo drive;
  final AppColors colors;

  const _DriveKindBadge({required this.drive, required this.colors});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    String badgeText = s.driveLocalBadge;
    Color badgeColor = colors.accentCyan;

    if (drive.isSystemDrive) {
      badgeText = s.driveSystemBadge;
      badgeColor = colors.accentCyan;
    } else if (drive.driveKind == DriveKind.removable) {
      badgeText = s.driveUsbBadge;
      badgeColor = colors.accentAmber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: badgeColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DriveProgressBar extends StatelessWidget {
  final double percent;
  final Color barColor;
  final AppColors colors;

  const _DriveProgressBar({
    required this.percent,
    required this.barColor,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final filledWidth = (totalWidth * percent).clamp(4.0, totalWidth);

        return Container(
          height: 7,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                width: filledWidth,
                height: 7,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [barColor.withValues(alpha: 0.75), barColor],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: barColor.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DriveCardBottomRow extends StatelessWidget {
  final DriveSpaceInfo drive;
  final AppColors colors;
  final Color barColor;

  const _DriveCardBottomRow({
    required this.drive,
    required this.colors,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final pctString = (drive.usedPercent * 100).toStringAsFixed(1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          s.driveFreeOfTotal(drive.formattedFree, drive.formattedTotal),
          style: TextStyle(
            fontSize: 10.5,
            color: colors.textMuted,
            fontFamily: 'Segoe UI',
          ),
        ),
        Text(
          s.driveUsedPercent('$pctString%'),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: barColor,
            fontFamily: 'Cascadia Code',
          ),
        ),
      ],
    );
  }
}
