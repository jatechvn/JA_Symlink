// lib/widgets/storage_savings_card.dart
// Visual Bento Card displaying overall storage savings with animated rolling counter

import 'package:flutter/material.dart';
import '../modules/i18n.dart';
import '../modules/storage/storage_model.dart';
import '../modules/utils.dart';
import '../theme/app_colors.dart';
import 'glass_widgets.dart';

class StorageSavingsCard extends StatelessWidget {
  final StorageSavingsSummary savings;
  final bool isScanning;
  final VoidCallback onRelocateMore;
  final VoidCallback onRecalculate;
  final AppColors colors;

  const StorageSavingsCard({
    super.key,
    required this.savings,
    required this.isScanning,
    required this.onRelocateMore,
    required this.onRecalculate,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      isFeatured: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SavingsHeader(
            colors: colors,
            isScanning: isScanning,
            onRecalculate: onRecalculate,
          ),
          const SizedBox(height: 14),
          _SavingsCounterDisplay(
            savedBytes: savings.totalSavedOnCBytes,
            colors: colors,
          ),
          const SizedBox(height: 6),
          _SavingsSubtitle(
            activeCount: savings.activeLinkCount,
            fileCount: savings.totalFileCount,
            colors: colors,
          ),
          if (savings.perDriveSavings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SavingsBreakdownRow(
              perDriveSavings: savings.perDriveSavings,
              colors: colors,
            ),
          ],
          const SizedBox(height: 14),
          _RelocateActionRow(colors: colors, onRelocateMore: onRelocateMore),
        ],
      ),
    );
  }
}

class _SavingsHeader extends StatelessWidget {
  final AppColors colors;
  final bool isScanning;
  final VoidCallback onRecalculate;

  const _SavingsHeader({
    required this.colors,
    required this.isScanning,
    required this.onRecalculate,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PillBadge(
          label: s.storageSavingsTitle,
          color: colors.accentEmerald,
          bg: colors.accentEmerald.withValues(alpha: 0.12),
          border: colors.accentEmerald.withValues(alpha: 0.35),
          icon: Icons.savings_rounded,
        ),
        IconButton(
          icon: isScanning
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.accentEmerald,
                  ),
                )
              : Icon(Icons.sync_rounded, size: 16, color: colors.textSecondary),
          tooltip: isScanning ? s.storageScanning : 'Tính lại dung lượng',
          onPressed: isScanning ? null : onRecalculate,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class _SavingsCounterDisplay extends StatelessWidget {
  final int savedBytes;
  final AppColors colors;

  const _SavingsCounterDisplay({
    required this.savedBytes,
    required this.colors,
  });

  (double, String) _getDisplayValueAndUnit(int bytes) {
    if (bytes >= 1024 * 1024 * 1024 * 1024) {
      return (bytes / (1024.0 * 1024 * 1024 * 1024), 'TB');
    }
    if (bytes >= 1024 * 1024 * 1024) {
      return (bytes / (1024.0 * 1024 * 1024), 'GB');
    }
    if (bytes >= 1024 * 1024) {
      return (bytes / (1024.0 * 1024), 'MB');
    }
    return (bytes / 1024.0, 'KB');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final (val, unit) = _getDisplayValueAndUnit(savedBytes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.storageSavedOnCLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: colors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: val),
          builder: (context, animatedVal, child) {
            final formattedVal = animatedVal < 10
                ? animatedVal.toStringAsFixed(2)
                : animatedVal.toStringAsFixed(1);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [colors.accentEmerald, colors.accentCyan],
                  ).createShader(bounds),
                  child: Text(
                    formattedVal,
                    style: const TextStyle(
                      fontFamily: 'Cascadia Code',
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  unit,
                  style: TextStyle(
                    fontFamily: 'Cascadia Code',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.accentEmerald,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SavingsSubtitle extends StatelessWidget {
  final int activeCount;
  final int fileCount;
  final AppColors colors;

  const _SavingsSubtitle({
    required this.activeCount,
    required this.fileCount,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    if (activeCount == 0) {
      return Text(
        s.storageSavingsSubtitle,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 11.5,
          height: 1.35,
        ),
      );
    }

    return Text(
      'Ước tính dữ liệu được chuyển hướng qua $activeCount liên kết (${s.totalOffloadedFiles(fileCount)})',
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: 11.5,
        height: 1.35,
      ),
    );
  }
}

class _SavingsBreakdownRow extends StatelessWidget {
  final Map<String, int> perDriveSavings;
  final AppColors colors;

  const _SavingsBreakdownRow({
    required this.perDriveSavings,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: perDriveSavings.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.subCardBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.subCardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_forward_rounded,
                size: 11,
                color: colors.accentCyan,
              ),
              const SizedBox(width: 4),
              Text(
                '${entry.key} ${formatFileSize(entry.value)}',
                style: TextStyle(
                  fontFamily: 'Cascadia Code',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RelocateActionRow extends StatelessWidget {
  final AppColors colors;
  final VoidCallback onRelocateMore;

  const _RelocateActionRow({
    required this.colors,
    required this.onRelocateMore,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return InkWell(
      onTap: onRelocateMore,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.accentEmerald.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colors.accentEmerald.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: colors.accentEmerald,
                ),
                const SizedBox(width: 8),
                Text(
                  s.storageRelocateMore,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colors.accentEmerald,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: colors.accentEmerald,
            ),
          ],
        ),
      ),
    );
  }
}
