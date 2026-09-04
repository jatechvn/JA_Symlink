part of 'glass_widgets.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.colors,
    required this.child,
    this.blurSigma = 24,
    this.borderRadius = 16,
    this.padding,
    this.borderColor,
    this.backgroundColor,
  });

  final AppColors colors;
  final Widget child;
  final double blurSigma;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveBlur = math.max(blurSigma, 6.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      // RepaintBoundary isolates the BackdropFilter into its own compositor layer
      child: RepaintBoundary(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveBlur,
            sigmaY: effectiveBlur,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? colors.glassBg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor ?? colors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border(
                top: BorderSide(color: colors.glassHighlight, width: 1),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Small rounded-pill badge, optionally with a glowing status dot.
class PillBadge extends StatelessWidget {
  const PillBadge({
    super.key,
    required this.label,
    required this.color,
    required this.bg,
    required this.border,
    this.showDot = false,
    this.icon,
    this.fontSize = 11,
    this.padding,
  });

  final String label;
  final Color color;
  final Color bg;
  final Color border;
  final bool showDot;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [BoxShadow(color: color, blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: fontSize, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted Bento Grid Card with highlight top-border and soft glow on hover.
class BentoCard extends StatelessWidget {
  final AppColors colors;
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final VoidCallback? onTap;
  final bool isFeatured;
  final Color? customBg;
  final Color? customBorder;
  final double? bgOpacity;

  const BentoCard({
    super.key,
    required this.colors,
    required this.child,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(20),
    this.blurSigma = 20,
    this.onTap,
    this.isFeatured = false,
    this.customBg,
    this.customBorder,
    this.bgOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg =
        customBg ??
        (bgOpacity != null
            ? colors.cardBg.withValues(alpha: bgOpacity)
            : colors.cardBg);

    // Legibility floor: when opacity < 1.0, force blur >= 6.0
    final double effectiveOpacity = bgOpacity ?? 0.25;
    final double effectiveBlur = effectiveOpacity < 1.0
        ? math.max(blurSigma, 6.0)
        : blurSigma;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            hoverColor: colors.cardHoverBg.withValues(alpha: 0.15),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: effectiveBg,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color:
                      customBorder ??
                      (isFeatured
                          ? colors.accentColor.withValues(alpha: 0.4)
                          : colors.borderDefault),
                  width: isFeatured ? 1.2 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  if (isFeatured)
                    BoxShadow(
                      color: colors.primaryGlow.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border(
                  top: BorderSide(
                    color: isFeatured
                        ? colors.accentCyan.withValues(alpha: 0.6)
                        : colors.glassHighlight,
                    width: 1,
                  ),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
