// lib/widgets/system_health_gauge.dart
// Interactive System Health & Integrity Gauge with neon glow meter and 1-click repair action

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../modules/i18n.dart';
import '../theme/app_colors.dart';
import 'glass_widgets.dart';

class SystemHealthGauge extends StatelessWidget {
  final int totalLinks;
  final int activeLinks;
  final int brokenCount;
  final VoidCallback onVerify;
  final AppColors colors;

  const SystemHealthGauge({
    super.key,
    required this.totalLinks,
    required this.activeLinks,
    required this.brokenCount,
    required this.onVerify,
    required this.colors,
  });

  double get _healthPercent {
    if (totalLinks <= 0) return 1.0;
    final healthy = math.max(0, activeLinks);
    return (healthy / totalLinks).clamp(0.0, 1.0);
  }

  Color get _statusColor {
    if (brokenCount > 0) return colors.accentAmber;
    if (_healthPercent >= 0.99) return colors.accentEmerald;
    return colors.accentCyan;
  }

  IconData get _statusIcon {
    if (brokenCount > 0) return Icons.gpp_maybe_rounded;
    if (_healthPercent >= 0.99) return Icons.gpp_good_rounded;
    return Icons.shield_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;
    final statusIcon = _statusIcon;
    final pct = _healthPercent;

    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _GaugeHeader(colors: colors, statusColor: statusColor),
          const SizedBox(height: 12),
          _GaugeCenterDisplay(
            percent: pct,
            statusColor: statusColor,
            statusIcon: statusIcon,
            brokenCount: brokenCount,
            totalLinks: totalLinks,
            colors: colors,
          ),
          const SizedBox(height: 12),
          _GaugeActionRow(
            brokenCount: brokenCount,
            onVerify: onVerify,
            colors: colors,
            statusColor: statusColor,
          ),
        ],
      ),
    );
  }
}

class _GaugeHeader extends StatelessWidget {
  final AppColors colors;
  final Color statusColor;

  const _GaugeHeader({required this.colors, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PillBadge(
          label: s.systemHealthTitle,
          color: statusColor,
          bg: statusColor.withValues(alpha: 0.12),
          border: statusColor.withValues(alpha: 0.35),
          icon: Icons.health_and_safety_rounded,
        ),
        WaveIndicator(color: statusColor, height: 10),
      ],
    );
  }
}

class _GaugeCenterDisplay extends StatelessWidget {
  final double percent;
  final Color statusColor;
  final IconData statusIcon;
  final int brokenCount;
  final int totalLinks;
  final AppColors colors;

  const _GaugeCenterDisplay({
    required this.percent,
    required this.statusColor,
    required this.statusIcon,
    required this.brokenCount,
    required this.totalLinks,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final pctScore = (percent * 100).toStringAsFixed(0);

    return Row(
      children: [
        // Circular Neon Gauge
        SizedBox(
          width: 76,
          height: 76,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: percent),
            builder: (context, animatedPercent, child) {
              return CustomPaint(
                painter: _HealthMeterPainter(
                  percent: animatedPercent,
                  statusColor: statusColor,
                  colors: colors,
                ),
                child: Center(
                  child: Icon(statusIcon, color: statusColor, size: 26),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        // Score description
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$pctScore%',
                    style: TextStyle(
                      fontFamily: 'Cascadia Code',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    brokenCount > 0
                        ? s.healthIssuesDetected
                        : s.healthAllHealthy,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                brokenCount > 0
                    ? s.healthBrokenDetails(brokenCount)
                    : s.healthTrackedDetails(totalLinks),
                style: TextStyle(
                  fontSize: 10.5,
                  color: colors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthMeterPainter extends CustomPainter {
  final double percent;
  final Color statusColor;
  final AppColors colors;

  _HealthMeterPainter({
    required this.percent,
    required this.statusColor,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeWidth = 6.0;

    // Background track
    final bgPaint = Paint()
      ..color = colors.subCardBorder.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Neon Arc
    final arcPaint = Paint()
      ..color = statusColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * math.pi * percent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HealthMeterPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.statusColor != statusColor;
  }
}

class _GaugeActionRow extends StatelessWidget {
  final int brokenCount;
  final VoidCallback onVerify;
  final AppColors colors;
  final Color statusColor;

  const _GaugeActionRow({
    required this.brokenCount,
    required this.onVerify,
    required this.colors,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return InkWell(
      onTap: onVerify,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, size: 13, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  s.btnVerifyAndFix,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            Icon(Icons.arrow_forward_rounded, size: 13, color: statusColor),
          ],
        ),
      ),
    );
  }
}
