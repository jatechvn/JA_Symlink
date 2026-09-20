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
class BentoCard extends StatefulWidget {
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
  final bool enableHoverGlow;

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
    this.enableHoverGlow = true,
  });

  @override
  State<BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<BentoCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgOpacity = widget.bgOpacity;
    final effectiveBg =
        widget.customBg ??
        (bgOpacity != null
            ? widget.colors.cardBg.withValues(alpha: bgOpacity)
            : widget.colors.cardBg);

    // Legibility floor: when opacity < 1.0, force blur >= 6.0
    final double effectiveOpacity = widget.bgOpacity ?? 0.25;
    final double effectiveBlur = effectiveOpacity < 1.0
        ? math.max(widget.blurSigma, 6.0)
        : widget.blurSigma;

    final isGlowActive =
        widget.isFeatured || (_isHovered && widget.enableHoverGlow);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (hovering) {
              if (widget.enableHoverGlow && mounted) {
                setState(() => _isHovered = hovering);
              }
            },
            borderRadius: BorderRadius.circular(widget.borderRadius),
            hoverColor: widget.colors.cardHoverBg.withValues(alpha: 0.15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: effectiveBg,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color:
                      widget.customBorder ??
                      (isGlowActive
                          ? widget.colors.accentColor.withValues(alpha: 0.5)
                          : widget.colors.borderDefault),
                  width: isGlowActive ? 1.2 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  if (isGlowActive)
                    BoxShadow(
                      color: widget.colors.primaryGlow.withValues(
                        alpha: _isHovered ? 0.22 : 0.15,
                      ),
                      blurRadius: _isHovered ? 36 : 30,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border(
                  top: BorderSide(
                    color: isGlowActive
                        ? widget.colors.accentCyan.withValues(alpha: 0.7)
                        : widget.colors.glassHighlight,
                    width: 1,
                  ),
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
