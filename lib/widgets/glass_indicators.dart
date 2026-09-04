part of 'glass_widgets.dart';

class WaveIndicator extends StatefulWidget {
  final Color color;
  final double height;
  const WaveIndicator({super.key, required this.color, this.height = 14});

  @override
  State<WaveIndicator> createState() => _WaveIndicatorState();
}

class _WaveIndicatorState extends State<WaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Stops equalizer bars while window is minimized/hidden (0% background CPU)
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        switch (state) {
          case AppLifecycleState.hidden:
          case AppLifecycleState.paused:
            _controller.stop();
          case AppLifecycleState.resumed:
            _controller.repeat(reverse: true);
          case AppLifecycleState.inactive:
          case AppLifecycleState.detached:
            break;
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        final h1 = (widget.height * (0.3 + 0.7 * val)).clamp(
          3.0,
          widget.height,
        );
        final h2 = (widget.height * (0.9 - 0.6 * val)).clamp(
          3.0,
          widget.height,
        );
        final h3 = (widget.height * (0.4 + 0.5 * (1 - val))).clamp(
          3.0,
          widget.height,
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(h1),
            const SizedBox(width: 2),
            _buildBar(h2),
            const SizedBox(width: 2),
            _buildBar(h3),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

/// Dynamic Island Status Capsule for top header with Asymmetric Marquee text.
class DynamicIslandCapsule extends StatelessWidget {
  final AppColors colors;
  final bool isRunning;
  final String statusText;
  final String? subText;
  final VoidCallback? onTap;
  final Color? customColor;

  const DynamicIslandCapsule({
    super.key,
    required this.colors,
    required this.isRunning,
    required this.statusText,
    this.subText,
    this.onTap,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = customColor ?? colors.accentEmerald;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colors.subCardBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isRunning
                  ? activeColor.withValues(alpha: 0.45)
                  : colors.subCardBorder,
            ),
            boxShadow: [
              if (isRunning)
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRunning) ...[
                WaveIndicator(color: activeColor, height: 12),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeColor,
                    boxShadow: [BoxShadow(color: activeColor, blurRadius: 6)],
                  ),
                ),
              ] else ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.textMuted,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: AsymmetricMarqueeText(
                  text: statusText,
                  style: TextStyle(
                    color: isRunning ? activeColor : colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Segoe UI',
                    letterSpacing: 0.35,
                  ),
                ),
              ),
              if (subText != null && subText!.isNotEmpty) ...[
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(maxWidth: 90),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.subCardBorder.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: AsymmetricMarqueeText(
                    text: subText!,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Segoe UI',
                    ),
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

/// Intelligent Adaptive Sliding Magnetic Pill Tab Bar with Mirror Glass Specular Hover Effect.
class SlidingPillTabBar extends StatefulWidget {
  final AppColors colors;
  final int currentIndex;
  final List<String> tabs;
  final List<IconData> icons;
  final ValueChanged<int> onTabSelected;
  final bool adaptiveCollapse;

  const SlidingPillTabBar({
    super.key,
    required this.colors,
    required this.currentIndex,
    required this.tabs,
    required this.icons,
    required this.onTabSelected,
    this.adaptiveCollapse = true,
  });

  @override
  State<SlidingPillTabBar> createState() => _SlidingPillTabBarState();
}

class _SlidingPillTabBarState extends State<SlidingPillTabBar> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isWideScreen = screenWidth >= 1150 || constraints.maxWidth >= 720;
        final shouldCollapse = widget.adaptiveCollapse && !isWideScreen;

        return Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            color: widget.colors.subCardBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: widget.colors.subCardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.tabs.length, (index) {
                final isSelected = widget.currentIndex == index;
                final isHovered = _hoveredIndex == index;
                final showLabel = isSelected || isHovered || !shouldCollapse;

                final decoration = isSelected
                    ? BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.colors.accentColor,
                            widget.colors.accentCyan.withValues(alpha: 0.88),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.colors.primaryGlow.withValues(
                              alpha: 0.45,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      )
                    : (isHovered
                          ? BoxDecoration(
                              gradient: LinearGradient(
                                begin: const Alignment(-0.8, -1.0),
                                end: const Alignment(0.8, 1.0),
                                colors: [
                                  widget.colors.glassHighlight.withValues(
                                    alpha: 0.32,
                                  ),
                                  widget.colors.cardHoverBg.withValues(
                                    alpha: 0.65,
                                  ),
                                  widget.colors.glassHighlight.withValues(
                                    alpha: 0.08,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: widget.colors.accentColor.withValues(
                                  alpha: 0.45,
                                ),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.colors.accentColor.withValues(
                                    alpha: 0.16,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: widget.colors.glassHighlight
                                      .withValues(alpha: 0.30),
                                  blurRadius: 4,
                                  offset: const Offset(0, -1),
                                ),
                              ],
                            )
                          : const BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.all(
                                Radius.circular(100),
                              ),
                            ));

                final foregroundDeco = isSelected
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                        ),
                      )
                    : (isHovered
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border(
                                top: BorderSide(
                                  color: widget.colors.glassHighlight
                                      .withValues(alpha: 0.95),
                                  width: 1.2,
                                ),
                              ),
                            )
                          : null);

                return MouseRegion(
                  onEnter: (_) => setState(() => _hoveredIndex = index),
                  onExit: (_) => setState(() => _hoveredIndex = null),
                  child: Tooltip(
                    message: widget.tabs[index],
                    waitDuration: const Duration(milliseconds: 600),
                    child: GestureDetector(
                      onTap: () => widget.onTabSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: showLabel ? 12 : 9,
                          vertical: 5.5,
                        ),
                        decoration: decoration,
                        foregroundDecoration: foregroundDeco,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.icons[index],
                              size: 14.5,
                              color: isSelected
                                  ? Colors.white
                                  : (isHovered
                                        ? widget.colors.textPrimary
                                        : widget.colors.textSecondary),
                            ),
                            if (showLabel) ...[
                              const SizedBox(width: 5.5),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: isWideScreen ? 145 : 115,
                                ),
                                child: isSelected
                                    ? AsymmetricMarqueeText(
                                        text: widget.tabs[index],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      )
                                    : Text(
                                        widget.tabs[index],
                                        style: TextStyle(
                                          color: isHovered
                                              ? widget.colors.textPrimary
                                              : widget.colors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: isHovered
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
