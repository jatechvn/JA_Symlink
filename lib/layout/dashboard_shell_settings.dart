part of 'dashboard_shell.dart';

class TopBarExpandingButton extends StatefulWidget {
  final Widget icon;
  final String? collapsedLabel;
  final String expandedLabel;
  final Color? textColor;
  final VoidCallback onTap;
  final String tooltip;
  final AppColors colors;
  final bool isCompact;

  const TopBarExpandingButton({
    super.key,
    required this.icon,
    this.collapsedLabel,
    required this.expandedLabel,
    this.textColor,
    required this.onTap,
    required this.tooltip,
    required this.colors,
    this.isCompact = false,
  });

  @override
  State<TopBarExpandingButton> createState() => _TopBarExpandingButtonState();
}

class _TopBarExpandingButtonState extends State<TopBarExpandingButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final showLabel =
        _isHovered || (!widget.isCompact && widget.collapsedLabel != null);
    final currentLabel = _isHovered
        ? widget.expandedLabel
        : (widget.collapsedLabel ?? '');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(100),
              splashFactory: NoSplash.splashFactory,
              hoverColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: showLabel ? 11 : 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? colors.cardHoverBg.withValues(alpha: 0.35)
                      : colors.subCardBg,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _isHovered
                        ? (widget.textColor ?? colors.accentCyan).withValues(
                            alpha: 0.65,
                          )
                        : colors.subCardBorder,
                    width: _isHovered ? 1.2 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? (widget.textColor ?? colors.primaryGlow).withValues(
                              alpha: 0.25,
                            )
                          : Colors.black.withValues(alpha: 0.04),
                      blurRadius: _isHovered ? 10 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.icon,
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      clipBehavior: Clip.none,
                      child: showLabel && currentLabel.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 6),
                                Text(
                                  currentLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    color:
                                        widget.textColor ?? colors.textPrimary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef TopBarPillButton = TopBarExpandingButton;

class _SettingsTabSelector extends StatelessWidget {
  const _SettingsTabSelector({
    required this.activeTab,
    required this.colors,
    required this.strings,
    required this.onTabSelected,
  });

  final int activeTab;
  final AppColors colors;
  final AppStrings strings;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.subCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.subCardBorder),
      ),
      child: Row(
        children: [
          _buildItem(0, Icons.tune_rounded, strings.t('tab_settings_ui')),
          _buildItem(1, Icons.menu_book_rounded, strings.t('tab_user_guide')),
          _buildItem(2, Icons.info_outline_rounded, strings.t('tab_about')),
        ],
      ),
    );
  }

  Widget _buildItem(int index, IconData icon, String label) {
    final isSelected = activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      colors.accentColor,
                      colors.accentCyan.withValues(alpha: 0.85),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : colors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGlassTuningTab extends StatelessWidget {
  const _SettingsGlassTuningTab({
    required this.colors,
    required this.theme,
    required this.strings,
    required this.localCardBlur,
    required this.localCardOpacity,
    required this.localDialogBlur,
    required this.localDialogOpacity,
    required this.localDropdownBlur,
    required this.localDropdownOpacity,
    required this.onCardBlurChanged,
    required this.onCardOpacityChanged,
    required this.onDialogBlurChanged,
    required this.onDialogOpacityChanged,
    required this.onDropdownBlurChanged,
    required this.onDropdownOpacityChanged,
    required this.onResetDefaults,
  });

  final AppColors colors;
  final ThemeProvider theme;
  final AppStrings strings;
  final double localCardBlur;
  final double localCardOpacity;
  final double localDialogBlur;
  final double localDialogOpacity;
  final double localDropdownBlur;
  final double localDropdownOpacity;
  final ValueChanged<double> onCardBlurChanged;
  final ValueChanged<double> onCardOpacityChanged;
  final ValueChanged<double> onDialogBlurChanged;
  final ValueChanged<double> onDialogOpacityChanged;
  final ValueChanged<double> onDropdownBlurChanged;
  final ValueChanged<double> onDropdownOpacityChanged;
  final VoidCallback onResetDefaults;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Native Windows Backdrop Blur Effect
          _SettingsWindowEffectCard(
            colors: colors,
            theme: theme,
            strings: strings,
            blurSigma: localCardBlur,
            bgOpacity: localCardOpacity,
          ),
          const SizedBox(height: 14),

          // 2. Liquid Glass & Bento Card Tuning Sliders
          BentoCard(
            colors: colors,
            blurSigma: localCardBlur,
            bgOpacity: localCardOpacity,
            padding: const EdgeInsets.all(16),
            borderRadius: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.blur_on_rounded,
                          size: 18,
                          color: colors.accentPurple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings.t('settings_card_header'),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: onResetDefaults,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Text(
                          strings.t('settings_default'),
                          style: TextStyle(
                            color: colors.accentCyan,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SettingsGlassSlider(
                  label: strings.t('settings_card_blur'),
                  value: localCardBlur,
                  min: 0,
                  max: 40,
                  colors: colors,
                  onChanged: onCardBlurChanged,
                ),
                _SettingsGlassSlider(
                  label: strings.t('settings_card_opacity'),
                  value: localCardOpacity,
                  min: 0.05,
                  max: 1.0,
                  isPercent: true,
                  colors: colors,
                  onChanged: onCardOpacityChanged,
                ),
                const SizedBox(height: 6),
                Divider(color: colors.subCardBorder, height: 1),
                const SizedBox(height: 6),
                _SettingsGlassSlider(
                  label: strings.t('settings_dialog_blur'),
                  value: localDialogBlur,
                  min: 0,
                  max: 40,
                  colors: colors,
                  onChanged: onDialogBlurChanged,
                ),
                _SettingsGlassSlider(
                  label: strings.t('settings_dialog_opacity'),
                  value: localDialogOpacity,
                  min: 0.1,
                  max: 1.0,
                  isPercent: true,
                  colors: colors,
                  onChanged: onDialogOpacityChanged,
                ),
                const SizedBox(height: 6),
                Divider(color: colors.subCardBorder, height: 1),
                const SizedBox(height: 6),
                _SettingsGlassSlider(
                  label: strings.t('settings_dropdown_blur'),
                  value: localDropdownBlur,
                  min: 0,
                  max: 40,
                  colors: colors,
                  onChanged: onDropdownBlurChanged,
                ),
                _SettingsGlassSlider(
                  label: strings.t('settings_dropdown_opacity'),
                  value: localDropdownOpacity,
                  min: 0.1,
                  max: 1.0,
                  isPercent: true,
                  colors: colors,
                  onChanged: onDropdownOpacityChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsWindowEffectCard extends StatelessWidget {
  const _SettingsWindowEffectCard({
    required this.colors,
    required this.theme,
    required this.strings,
    required this.blurSigma,
    required this.bgOpacity,
  });

  final AppColors colors;
  final ThemeProvider theme;
  final AppStrings strings;
  final double blurSigma;
  final double bgOpacity;

  @override
  Widget build(BuildContext context) {
    final current = theme.windowEffect;

    return BentoCard(
      colors: colors,
      blurSigma: blurSigma,
      bgOpacity: bgOpacity,
      padding: const EdgeInsets.all(16),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.window_rounded, size: 18, color: colors.accentCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.t('settings_window_effect'),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.t('settings_window_effect_desc'),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _EffectOptionTile(
            effect: WindowEffect.acrylic,
            title: strings.t('effect_acrylic'),
            desc: strings.t('effect_acrylic_desc'),
            isSelected: current == WindowEffect.acrylic,
            colors: colors,
            onSelect: () => theme.setWindowEffect(WindowEffect.acrylic),
          ),
          const SizedBox(height: 6),
          _EffectOptionTile(
            effect: WindowEffect.aero,
            title: strings.t('effect_aero'),
            desc: strings.t('effect_aero_desc'),
            isSelected: current == WindowEffect.aero,
            colors: colors,
            onSelect: () => theme.setWindowEffect(WindowEffect.aero),
          ),
          const SizedBox(height: 6),
          _EffectOptionTile(
            effect: WindowEffect.mica,
            title: strings.t('effect_mica'),
            desc: strings.t('effect_mica_desc'),
            isSelected: current == WindowEffect.mica,
            colors: colors,
            onSelect: () => theme.setWindowEffect(WindowEffect.mica),
          ),
          const SizedBox(height: 6),
          _EffectOptionTile(
            effect: WindowEffect.tabbed,
            title: strings.t('effect_tabbed'),
            desc: strings.t('effect_tabbed_desc'),
            isSelected: current == WindowEffect.tabbed,
            colors: colors,
            onSelect: () => theme.setWindowEffect(WindowEffect.tabbed),
          ),
          const SizedBox(height: 6),
          _EffectOptionTile(
            effect: WindowEffect.disabled,
            title: strings.t('effect_disabled'),
            desc: strings.t('effect_disabled_desc'),
            isSelected: current == WindowEffect.disabled,
            colors: colors,
            onSelect: () => theme.setWindowEffect(WindowEffect.disabled),
          ),
        ],
      ),
    );
  }
}

class _EffectOptionTile extends StatelessWidget {
  const _EffectOptionTile({
    required this.effect,
    required this.title,
    required this.desc,
    required this.isSelected,
    required this.colors,
    required this.onSelect,
  });

  final WindowEffect effect;
  final String title;
  final String desc;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(10),
        hoverColor: colors.cardHoverBg.withValues(alpha: 0.25),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accentColor.withValues(alpha: 0.14)
                : colors.subCardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? colors.accentColor.withValues(alpha: 0.6)
                  : colors.subCardBorder,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 16,
                color: isSelected ? colors.accentCyan : colors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected
                            ? colors.accentCyan
                            : colors.textPrimary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGlassSlider extends StatelessWidget {
  const _SettingsGlassSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.isPercent = false,
    required this.colors,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final bool isPercent;
  final AppColors colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final display = isPercent
        ? '${(value * 100).round()}%'
        : '${value.toStringAsFixed(0)}px';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                display,
                style: TextStyle(
                  color: colors.accentCyan,
                  fontSize: 11,
                  fontFamily: 'Segoe UI',
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: colors.accentColor,
              inactiveTrackColor: colors.subCardBorder,
              thumbColor: colors.accentCyan,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: isPercent ? 19 : 40,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsUserGuideTab extends StatelessWidget {
  const _SettingsUserGuideTab({required this.colors, required this.strings});

  final AppColors colors;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGuideCard(
            icon: Icons.keyboard_rounded,
            accent: colors.accentCyan,
            title: strings.t('guide_shortcuts_title'),
            desc: strings.t('guide_shortcuts_desc'),
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.touch_app_rounded,
            accent: colors.accentAmber,
            title: strings.t('guide_topbar_title'),
            desc: strings.t('guide_topbar_desc'),
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.speed_rounded,
            accent: colors.accentEmerald,
            title: strings.t('guide_tier_title'),
            desc: strings.t('guide_tier_desc'),
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.swap_vert_rounded,
            accent: colors.accentPurple,
            title: strings.t('guide_scroll_title'),
            desc: strings.t('guide_scroll_desc'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard({
    required IconData icon,
    required Color accent,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.subCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.subCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsAboutTab extends StatelessWidget {
  const _SettingsAboutTab({
    required this.colors,
    required this.theme,
    required this.strings,
    required this.appVersion,
    required this.isDebug,
  });

  final AppColors colors;
  final ThemeProvider theme;
  final AppStrings strings;
  final String appVersion;
  final bool isDebug;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.subCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.accentColor, colors.accentCyan],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primaryGlow.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'JA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            strings.t('about_app_name'),
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          PillBadge(
                            label: isDebug
                                ? strings.debugLabel
                                : strings.releaseLabel,
                            color: isDebug
                                ? colors.accentAmber
                                : colors.accentEmerald,
                            bg:
                                (isDebug
                                        ? colors.accentAmber
                                        : colors.accentEmerald)
                                    .withValues(alpha: 0.12),
                            border:
                                (isDebug
                                        ? colors.accentAmber
                                        : colors.accentEmerald)
                                    .withValues(alpha: 0.3),
                            fontSize: 9.5,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'v$appVersion • ${strings.nativeWindowsFfi}',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11,
                          fontFamily: 'Segoe UI',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.t('about_app_desc'),
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          // System Runtime Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.subCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.subCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.t('about_sys_title'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _buildInfoRow(
                  strings.osLabel,
                  Platform.operatingSystemVersion,
                  colors,
                ),
                _buildInfoRow(
                  strings.cpuCoresLabel,
                  '${theme.cpuCores} Cores',
                  colors,
                ),
                _buildInfoRow(
                  strings.hardwareScoreLabel,
                  '${theme.hardwareScore}/100',
                  colors,
                ),
                _buildInfoRow(
                  strings.graphicsConfigLabel,
                  '${theme.effectiveTier.label} (${theme.effectiveTier.desc})',
                  colors,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Developer & License Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.subCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.subCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.t('about_dev_title'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _buildInfoRow(
                  strings.authorLabel,
                  'JA Tech / Windows Desktop',
                  colors,
                ),
                _buildInfoRow(
                  strings.licenseLabel,
                  'Proprietary (Safe Symlink Manager)',
                  colors,
                ),
                _buildInfoRow(
                  strings.standardLabel,
                  'flutter-app-blueprint v1.0',
                  colors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Segoe UI',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
