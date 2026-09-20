// lib/widgets/storage_distribution_chart.dart
// Interactive segmented Donut Chart displaying storage savings distribution across drives

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../modules/i18n.dart';
import '../modules/storage/storage_model.dart';
import '../modules/utils.dart';
import '../theme/app_colors.dart';
import 'glass_widgets.dart';

class StorageDistributionChart extends StatefulWidget {
  final StorageSavingsSummary savings;
  final AppColors colors;

  const StorageDistributionChart({
    super.key,
    required this.savings,
    required this.colors,
  });

  @override
  State<StorageDistributionChart> createState() =>
      _StorageDistributionChartState();
}

class _StorageDistributionChartState extends State<StorageDistributionChart> {
  String? _hoveredDrive;

  final List<Color> _palette = const [
    Color(0xFF00E5FF), // Cyan
    Color(0xFF00E676), // Emerald
    Color(0xFFFFB300), // Amber
    Color(0xFFB388FF), // Purple
    Color(0xFFFF5252), // Rose
    Color(0xFF448AFF), // Blue
  ];

  Color _getColorForIndex(int idx) => _palette[idx % _palette.length];

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: widget.colors,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChartHeader(colors: widget.colors),
          const SizedBox(height: 14),
          _ChartContentRow(
            savings: widget.savings,
            colors: widget.colors,
            hoveredDrive: _hoveredDrive,
            onHoverDrive: (drive) => setState(() => _hoveredDrive = drive),
            paletteGetter: _getColorForIndex,
          ),
        ],
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  final AppColors colors;

  const _ChartHeader({required this.colors});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PillBadge(
          label: s.storageDistributionTitle,
          color: colors.accentPurple,
          bg: colors.accentPurple.withValues(alpha: 0.12),
          border: colors.accentPurple.withValues(alpha: 0.35),
          icon: Icons.pie_chart_rounded,
        ),
        Text(
          s.savingsBreakdown,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ChartContentRow extends StatelessWidget {
  final StorageSavingsSummary savings;
  final AppColors colors;
  final String? hoveredDrive;
  final ValueChanged<String?> onHoverDrive;
  final Color Function(int) paletteGetter;

  const _ChartContentRow({
    required this.savings,
    required this.colors,
    required this.hoveredDrive,
    required this.onHoverDrive,
    required this.paletteGetter,
  });

  @override
  Widget build(BuildContext context) {
    if (savings.perDriveSavings.isEmpty || savings.totalSavedBytes <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            context.strings.distributionEmpty,
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Donut ring
        SizedBox(
          width: 120,
          height: 120,
          child: _DonutChartWidget(
            savings: savings,
            colors: colors,
            hoveredDrive: hoveredDrive,
            paletteGetter: paletteGetter,
          ),
        ),
        const SizedBox(width: 18),
        // Legend list
        Expanded(
          child: _ChartLegendList(
            perDrive: savings.perDriveSavings,
            totalBytes: savings.totalSavedBytes,
            colors: colors,
            hoveredDrive: hoveredDrive,
            onHoverDrive: onHoverDrive,
            paletteGetter: paletteGetter,
          ),
        ),
      ],
    );
  }
}

class _DonutChartWidget extends StatelessWidget {
  final StorageSavingsSummary savings;
  final AppColors colors;
  final String? hoveredDrive;
  final Color Function(int) paletteGetter;

  const _DonutChartWidget({
    required this.savings,
    required this.colors,
    required this.hoveredDrive,
    required this.paletteGetter,
  });

  @override
  Widget build(BuildContext context) {
    final entries = savings.perDriveSavings.entries.toList();

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, progress, child) {
        return CustomPaint(
          painter: _DonutPainter(
            entries: entries,
            totalBytes: savings.totalSavedBytes,
            colors: colors,
            hoveredDrive: hoveredDrive,
            paletteGetter: paletteGetter,
            animationProgress: progress,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${savings.activeLinkCount}',
                  style: TextStyle(
                    fontFamily: 'Cascadia Code',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.strings.distributionLinks,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: colors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final int totalBytes;
  final AppColors colors;
  final String? hoveredDrive;
  final Color Function(int) paletteGetter;
  final double animationProgress;

  _DonutPainter({
    required this.entries,
    required this.totalBytes,
    required this.colors,
    required this.hoveredDrive,
    required this.paletteGetter,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalBytes <= 0 || entries.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const strokeWidth = 10.0;

    // Background track
    final bgPaint = Paint()
      ..color = colors.subCardBorder.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    double startAngle = -math.pi / 2;
    final totalSweep = 2 * math.pi * animationProgress;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final fraction = (entry.value / totalBytes).clamp(0.0, 1.0);
      final sweepAngle = fraction * totalSweep;
      final isHovered = hoveredDrive != null && hoveredDrive == entry.key;

      final color = paletteGetter(i);
      final segmentPaint = Paint()
        ..color = isHovered ? color : color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? strokeWidth + 3 : strokeWidth
        ..strokeCap = StrokeCap.round;

      // Small gap between segments
      final adjustedSweep = math.max(0.0, sweepAngle - 0.08);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        adjustedSweep,
        false,
        segmentPaint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.hoveredDrive != hoveredDrive ||
        oldDelegate.totalBytes != totalBytes ||
        oldDelegate.colors != colors ||
        !listEquals(
          oldDelegate.entries.map((e) => e.key).toList(),
          entries.map((e) => e.key).toList(),
        ) ||
        !listEquals(
          oldDelegate.entries.map((e) => e.value).toList(),
          entries.map((e) => e.value).toList(),
        );
  }
}

class _ChartLegendList extends StatelessWidget {
  final Map<String, int> perDrive;
  final int totalBytes;
  final AppColors colors;
  final String? hoveredDrive;
  final ValueChanged<String?> onHoverDrive;
  final Color Function(int) paletteGetter;

  const _ChartLegendList({
    required this.perDrive,
    required this.totalBytes,
    required this.colors,
    required this.hoveredDrive,
    required this.onHoverDrive,
    required this.paletteGetter,
  });

  @override
  Widget build(BuildContext context) {
    final entries = perDrive.entries.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _LegendItem(
            driveLetter: entries[i].key,
            bytes: entries[i].value,
            totalBytes: totalBytes,
            color: paletteGetter(i),
            isHovered: hoveredDrive == entries[i].key,
            onHover: (hovering) =>
                onHoverDrive(hovering ? entries[i].key : null),
            colors: colors,
          ),
        ],
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String driveLetter;
  final int bytes;
  final int totalBytes;
  final Color color;
  final bool isHovered;
  final ValueChanged<bool> onHover;
  final AppColors colors;

  const _LegendItem({
    required this.driveLetter,
    required this.bytes,
    required this.totalBytes,
    required this.color,
    required this.isHovered,
    required this.onHover,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalBytes > 0
        ? (bytes / totalBytes * 100).toStringAsFixed(0)
        : '0';

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isHovered ? color.withValues(alpha: 0.12) : colors.subCardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isHovered
                ? color.withValues(alpha: 0.4)
                : colors.subCardBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: isHovered
                    ? [BoxShadow(color: color, blurRadius: 6)]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              driveLetter,
              style: TextStyle(
                fontFamily: 'Cascadia Code',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              formatFileSize(bytes),
              style: TextStyle(
                fontFamily: 'Cascadia Code',
                fontSize: 11,
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$pct%',
                style: TextStyle(
                  fontFamily: 'Cascadia Code',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
