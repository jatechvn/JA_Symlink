import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:provider/provider.dart';
import '../dialogs/glass_change_dialog.dart';
import '../dialogs/glass_create_dialog.dart';
import '../dialogs/glass_import_dialog.dart';
import '../dialogs/glass_remove_dialog.dart';
import '../dialogs/glass_scan_dialog.dart';
import '../dialogs/glass_verify_dialog.dart';
import '../modules/i18n.dart';
import '../modules/logic.dart';
import '../modules/symlink_service.dart';
import '../modules/utils.dart';
import '../modules/constants.dart' as constants;
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../views/overview_view.dart';
import '../views/symlink_list_view.dart';
import '../views/system_tools_view.dart';
import '../views/user_guide_view.dart';
import '../widgets/app_toast.dart';
import '../widgets/command_palette.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/mobile_dock_nav.dart';

part 'dashboard_shell_settings.dart';

class DashboardShell extends StatefulWidget {
  final SymlinkLogic logic;
  final String appTitle;
  final String appVersion;
  final bool isDebug;
  final String? buildTimestamp;

  const DashboardShell({
    super.key,
    required this.logic,
    this.appTitle = constants.appName,
    this.appVersion = constants.appVersion,
    this.isDebug = false,
    this.buildTimestamp,
  });

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _currentIndex = 0;
  List<SymlinkEntry> _entries = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  double _progressPercent = 0.0;
  String _progressDetail = '';

  static const double _mobileBreakpoint = 768;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await widget.logic.initialize();
    if (!mounted) return;
    _isAdmin = await widget.logic.isAdmin();
    if (!mounted) return;
    await _refreshEntries();
  }

  Future<void> _refreshEntries() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _entries = await widget.logic.getAllEntries();
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          colors: context.read<ThemeProvider>().colors,
          message: '${context.strings.errorLoadingData}: $e',
          icon: Icons.error_outline_rounded,
          accentColor: context.read<ThemeProvider>().colors.accentRose,
        );
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _createSymlink() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const GlassCreateDialog(),
    );

    if (result != null && mounted) {
      final s = context.strings;
      final c = context.read<ThemeProvider>().colors;

      setState(() {
        _isLoading = true;
        _progressPercent = 0.0;
        _progressDetail = '';
      });

      final opResult = await widget.logic.createSymlink(
        sourcePath: result['source'],
        targetPath: result['target'],
        moveData: result['moveData'],
        killProcesses: result['killProcesses'],
        onProgress: (percent, fileName, sizeInfo) {
          if (!mounted) return;
          setState(() {
            _progressPercent = percent;
            _progressDetail = '$fileName ($sizeInfo)';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _progressPercent = 0.0;
        _progressDetail = '';
      });

      final statusMsg = opResult.success
          ? s.msgCreateSuccess
          : s.localizeError(opResult.message);

      showAppToast(
        context,
        colors: c,
        message: statusMsg,
        icon: opResult.success
            ? Icons.check_circle_rounded
            : Icons.error_outline_rounded,
        accentColor: opResult.success ? c.accentEmerald : c.accentRose,
      );

      await _refreshEntries();
    }
  }

  Future<void> _changeSymlink(SymlinkEntry entry) async {
    final s = context.strings;
    final c = context.read<ThemeProvider>().colors;

    if (!entry.isActive) {
      showAppToast(
        context,
        colors: c,
        message: s.errOnlyChange,
        icon: Icons.warning_amber_rounded,
        accentColor: c.accentAmber,
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => GlassChangeDialog(
        currentLinkPath: entry.linkPath,
        currentTargetPath: entry.targetPath,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _isLoading = true;
        _progressPercent = 0.0;
        _progressDetail = '';
      });

      final opResult = await widget.logic.changeSymlink(
        linkPath: entry.linkPath,
        newTargetPath: result['newTarget'],
        moveData: result['moveData'],
        onProgress: (percent, fileName, sizeInfo) {
          if (!mounted) return;
          setState(() {
            _progressPercent = percent;
            _progressDetail = '$fileName ($sizeInfo)';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _progressPercent = 0.0;
        _progressDetail = '';
      });

      final statusMsg = opResult.success
          ? s.msgChangeSuccess
          : s.localizeError(opResult.message);

      showAppToast(
        context,
        colors: c,
        message: statusMsg,
        icon: opResult.success
            ? Icons.check_circle_rounded
            : Icons.error_outline_rounded,
        accentColor: opResult.success ? c.accentEmerald : c.accentRose,
      );

      await _refreshEntries();
    }
  }

  Future<void> _removeSymlink(SymlinkEntry entry) async {
    final s = context.strings;
    final c = context.read<ThemeProvider>().colors;

    if (!entry.isActive) {
      showAppToast(
        context,
        colors: c,
        message: s.errOnlyRemove,
        icon: Icons.warning_amber_rounded,
        accentColor: c.accentAmber,
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => GlassRemoveDialog(
        linkPath: entry.linkPath,
        targetPath: entry.targetPath,
        hasBackup: entry.hasBackup,
      ),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);

      final opResult = await widget.logic.removeSymlink(
        linkPath: entry.linkPath,
        restoreBackup: result['restoreBackup'],
      );

      if (!mounted) return;
      final statusMsg = opResult.success
          ? s.msgRemoveSuccess
          : s.localizeError(opResult.message);

      showAppToast(
        context,
        colors: c,
        message: statusMsg,
        icon: opResult.success
            ? Icons.check_circle_rounded
            : Icons.error_outline_rounded,
        accentColor: opResult.success ? c.accentEmerald : c.accentRose,
      );

      await _refreshEntries();
    }
  }

  Future<void> _scanSystem() async {
    final s = context.strings;
    final c = context.read<ThemeProvider>().colors;

    setState(() => _isLoading = true);
    late final List<Map<String, String>> results;
    try {
      results = await widget.logic.scanSystemSymlinks();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAppToast(
        context,
        colors: c,
        message: '${s.errorScan}: $e',
        icon: Icons.error_outline_rounded,
        accentColor: c.accentRose,
      );
      return;
    }
    final trackedLinks = _entries
        .where((e) => e.isActive)
        .map((e) => e.linkPath.toLowerCase())
        .toSet();

    if (!mounted) return;
    setState(() => _isLoading = false);

    showAppToast(
      context,
      colors: c,
      message: s.scanFound(results.length),
      icon: Icons.radar_rounded,
      accentColor: c.accentCyan,
    );

    await showDialog(
      context: context,
      builder: (_) =>
          GlassScanDialog(results: results, trackedLinks: trackedLinks),
    );
  }

  Future<void> _verifySymlinks() async {
    final s = context.strings;
    final c = context.read<ThemeProvider>().colors;

    setState(() => _isLoading = true);
    late final List<Map<String, String>> results;
    try {
      results = await widget.logic.verifyAndFixEntries();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAppToast(
        context,
        colors: c,
        message: '${s.errorVerify}: $e',
        icon: Icons.error_outline_rounded,
        accentColor: c.accentRose,
      );
      return;
    }

    if (!mounted) return;
    final fixed = results.where((r) => r['status'] == 'FIXED').length;
    final ok = results.where((r) => r['status'] == 'OK').length;
    final broken = results
        .where((r) => r['status'] != 'OK' && r['status'] != 'FIXED')
        .length;

    if (fixed > 0) await _refreshEntries();
    if (!mounted) return;
    setState(() => _isLoading = false);

    showAppToast(
      context,
      colors: c,
      message: s.verifiedSummary(ok, fixed, broken),
      icon: Icons.verified_user_rounded,
      accentColor: c.accentEmerald,
    );

    await showDialog(
      context: context,
      builder: (_) => GlassVerifyDialog(results: results),
    );
  }

  Future<void> _exportSymlinks() async {
    final s = context.strings;
    final c = context.read<ThemeProvider>().colors;
    final timestamp = formatTimestampFileName();

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: s.pickerExportTitle,
      fileName: 'ja_symlinks_export_$timestamp.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputFile != null && mounted) {
      setState(() => _isLoading = true);
      final opResult = await widget.logic.exportSymlinks(outputFile);

      if (!mounted) return;
      setState(() => _isLoading = false);

      showAppToast(
        context,
        colors: c,
        message: opResult.success
            ? s.msgExportSuccess
            : s.localizeError(opResult.message),
        icon: opResult.success
            ? Icons.download_done_rounded
            : Icons.error_outline_rounded,
        accentColor: opResult.success ? c.accentEmerald : c.accentRose,
      );
    }
  }

  Future<void> _importSymlinks() async {
    final s = context.strings;
    final c = context.read<ThemeProvider>().colors;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: s.pickerImportTitle,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null && mounted) {
      final filePath = result.files.single.path!;
      setState(() => _isLoading = true);

      try {
        final importResult = await widget.logic.importSymlinks(filePath);

        if (!mounted) return;
        setState(() => _isLoading = false);

        await _refreshEntries();

        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => GlassImportDialog(result: importResult),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        showAppToast(
          context,
          colors: c,
          message: '${s.errImportFailed}: $e',
          icon: Icons.error_outline_rounded,
          accentColor: c.accentRose,
        );
      }
    }
  }

  List<CommandPaletteItem> _buildPaletteItems() {
    final s = context.strings;
    final theme = context.read<ThemeProvider>();
    final lang = context.read<LanguageNotifier>();

    return [
      CommandPaletteItem(
        label: s.btnCreate,
        subtitle: s.dlgCreateDesc,
        icon: Icons.add_link_rounded,
        onSelect: _createSymlink,
      ),
      CommandPaletteItem(
        label: s.menuScan,
        subtitle: s.tooltipScan,
        icon: Icons.radar_rounded,
        onSelect: _scanSystem,
      ),
      CommandPaletteItem(
        label: s.menuVerify,
        subtitle: s.tooltipVerify,
        icon: Icons.verified_user_rounded,
        onSelect: _verifySymlinks,
      ),
      CommandPaletteItem(
        label: s.menuExport,
        subtitle: s.tooltipExport,
        icon: Icons.download_rounded,
        onSelect: _exportSymlinks,
      ),
      CommandPaletteItem(
        label: s.menuImport,
        subtitle: s.tooltipImport,
        icon: Icons.upload_rounded,
        onSelect: _importSymlinks,
      ),
      CommandPaletteItem(
        label: s.paletteTheme,
        subtitle: s.paletteThemeDesc,
        icon: Icons.palette_rounded,
        onSelect: () => theme.toggleTheme(),
      ),
      CommandPaletteItem(
        label: s.paletteGlassSettings,
        subtitle: s.paletteGlassSettingsDesc,
        icon: Icons.tune_rounded,
        onSelect: () => _showGlassSettingsDialog(context, theme),
      ),
      CommandPaletteItem(
        label: s.languageCommand(lang.language.fullLabel),
        subtitle: s.languageCommandDesc,
        icon: Icons.language_rounded,
        onSelect: () => lang.cycleNext(),
      ),
      CommandPaletteItem(
        label: s.openTab(s.navOverview),
        icon: Icons.dashboard_rounded,
        onSelect: () => setState(() => _currentIndex = 0),
      ),
      CommandPaletteItem(
        label: s.openTab(s.navSymlinks),
        icon: Icons.link_rounded,
        onSelect: () => setState(() => _currentIndex = 1),
      ),
      CommandPaletteItem(
        label: s.openTab(s.navTools),
        icon: Icons.build_circle_rounded,
        onSelect: () => setState(() => _currentIndex = 2),
      ),
      CommandPaletteItem(
        label: s.openTab(s.navGuide),
        icon: Icons.menu_book_rounded,
        onSelect: () => setState(() => _currentIndex = 3),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final isMobile = MediaQuery.of(context).size.width < _mobileBreakpoint;

    return CommandPaletteShortcut(
      items: _buildPaletteItems,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 1. Mesh Gradient Base Tint
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.bgSecondary,
                      colors.bgSecondary.withValues(alpha: 0.5),
                      colors.bgSecondary.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),

            // 2. GPU-Composited Floating Mesh Orbs
            Positioned.fill(child: MeshBackground(colors: colors)),

            // 3. Main Scaffold Layout: Header + Content
            Column(
              children: [
                _buildTopHeader(context, theme, colors, isMobile),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, isMobile ? 84 : 16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _buildCurrentView(),
                    ),
                  ),
                ),
              ],
            ),

            // 4. Determinate Progress Overlay when copying
            if (_progressPercent > 0.0)
              Positioned(
                bottom: 24,
                right: 24,
                child: BentoCard(
                  colors: colors,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          value: _progressPercent,
                          strokeWidth: 2.5,
                          color: colors.accentCyan,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(_progressPercent * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                              fontFamily: 'Cascadia Code',
                            ),
                          ),
                          Text(
                            _progressDetail,
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // 5. Floating Mobile Bottom Dock (narrow screens)
            if (isMobile)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MobileDockNav(
                  colors: colors,
                  currentIndex: _currentIndex,
                  tabs: [s.navOverview, s.navSymlinks, s.navTools, s.navGuide],
                  icons: const [
                    Icons.dashboard_rounded,
                    Icons.link_rounded,
                    Icons.build_circle_rounded,
                    Icons.menu_book_rounded,
                  ],
                  onTabSelected: (index) =>
                      setState(() => _currentIndex = index),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    if (_isLoading && _entries.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: context.watch<ThemeProvider>().colors.accentCyan,
        ),
      );
    }
    switch (_currentIndex) {
      case 0:
        return OverviewView(
          key: const ValueKey('Overview'),
          entries: _entries,
          isAdmin: _isAdmin,
          onCreate: _createSymlink,
          onScan: _scanSystem,
          onVerify: _verifySymlinks,
          onSelectTab: (idx) => setState(() => _currentIndex = idx),
        );
      case 1:
        return SymlinkListView(
          key: const ValueKey('Symlinks'),
          entries: _entries,
          onCreate: _createSymlink,
          onChange: _changeSymlink,
          onRemove: _removeSymlink,
          onRefresh: _refreshEntries,
        );
      case 2:
        return SystemToolsView(
          key: const ValueKey('Tools'),
          onScan: _scanSystem,
          onVerify: _verifySymlinks,
          onImport: _importSymlinks,
          onExport: _exportSymlinks,
        );
      case 3:
        return const UserGuideView(key: ValueKey('Guide'));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTopHeader(
    BuildContext context,
    ThemeProvider theme,
    AppColors colors,
    bool isMobile,
  ) {
    final s = context.strings;
    final lang = context.watch<LanguageNotifier>();
    final activeCount = _entries.where((e) => e.isActive).length;
    final timestamp = widget.buildTimestamp ?? _getFallbackBuildTimestamp();
    final isCompact = MediaQuery.of(context).size.width < 1220;

    final tabLabels = [s.navOverview, s.navSymlinks, s.navTools, s.navGuide];
    final tabIcons = [
      Icons.dashboard_rounded,
      Icons.link_rounded,
      Icons.build_circle_rounded,
      Icons.menu_book_rounded,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.headerBg,
        border: Border(
          bottom: BorderSide(color: colors.headerBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Brand Logo + Title + Version Tag
          InkWell(
            onTap: () => setState(() => _currentIndex = 0),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.accentColor, colors.accentCyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primaryGlow.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'JA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.appTitle,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        PillBadge(
                          label: _isAdmin
                              ? s.labelAdmin.toUpperCase()
                              : s.labelStandard.toUpperCase(),
                          color: _isAdmin
                              ? colors.accentEmerald
                              : colors.accentAmber,
                          bg: _isAdmin
                              ? colors.accentEmerald.withValues(alpha: 0.15)
                              : colors.accentAmber.withValues(alpha: 0.15),
                          border: _isAdmin
                              ? colors.accentEmerald.withValues(alpha: 0.4)
                              : colors.accentAmber.withValues(alpha: 0.4),
                          icon: _isAdmin
                              ? Icons.shield_rounded
                              : Icons.shield_outlined,
                          fontSize: 9.5,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 140,
                      child: AsymmetricMarqueeText(
                        text: widget.isDebug
                            ? 'DEBUG · v${widget.appVersion} ($timestamp)'
                            : 'v${widget.appVersion}',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontFamily: 'Cascadia Code',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Sliding Pill Tab Bar (Centered)
          Expanded(
            child: isMobile
                ? const SizedBox.shrink()
                : Center(
                    child: SlidingPillTabBar(
                      colors: colors,
                      currentIndex: _currentIndex,
                      tabs: tabLabels,
                      icons: tabIcons,
                      onTabSelected: (index) =>
                          setState(() => _currentIndex = index),
                    ),
                  ),
          ),

          const SizedBox(width: 12),

          // Dynamic Island Status Capsule
          DynamicIslandCapsule(
            colors: colors,
            isRunning: activeCount > 0,
            statusText: s.activeBadge(activeCount),
            subText: _isAdmin ? s.labelAdmin.toUpperCase() : s.standardShort,
            onTap: () => setState(() => _currentIndex = 1),
          ),

          const SizedBox(width: 10),

          // Command Palette Shortcut Button (Ctrl+K)
          Tooltip(
            message: s.spotlightTooltip,
            child: InkWell(
              onTap: () =>
                  showCommandPalette(context, items: _buildPaletteItems()),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.subCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.subCardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    KbdTag(label: 'Ctrl+K', colors: colors),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 1. Performance Tier Switcher (⚡ Auto / Ultra / Balanced / Lite)
          TopBarExpandingButton(
            icon: Icon(
              theme.effectiveTier.icon,
              color: theme.effectiveTier.color,
              size: 14,
            ),
            collapsedLabel: isCompact ? null : theme.perfLabel,
            expandedLabel: '⚡ ${theme.perfLabel}',
            textColor: theme.effectiveTier.color,
            isCompact: isCompact,
            tooltip: s.t('perf_tooltip'),
            colors: colors,
            onTap: () {
              theme.cyclePerfTier();
              showAppToast(
                context,
                message: s.performanceChanged(theme.perfLabel, theme.cpuCores),
                colors: colors,
                icon: Icons.bolt_rounded,
              );
            },
          ),

          const SizedBox(width: 6),

          // 2. Quick Language Switcher (🌐 EN / 中 / VN)
          TopBarExpandingButton(
            icon: Icon(
              Icons.language_rounded,
              size: 14,
              color: colors.accentCyan,
            ),
            collapsedLabel: isCompact ? null : lang.language.shortLabel,
            expandedLabel:
                '${lang.language.shortLabel} ${lang.language.fullLabel}',
            textColor: colors.accentCyan,
            isCompact: isCompact,
            tooltip: s.t('lang_tooltip'),
            colors: colors,
            onTap: () {
              lang.cycleNext();
              showAppToast(
                context,
                message: s.languageChanged(lang.language.fullLabel),
                colors: colors,
                icon: Icons.language_rounded,
              );
            },
          ),

          const SizedBox(width: 6),

          // 3. 1-Click Theme Toggle Button with Hover Zoom & Full Text
          TopBarExpandingButton(
            icon: Icon(
              theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: theme.isDark ? colors.accentAmber : colors.accentPurple,
              size: 14,
            ),
            collapsedLabel: null,
            expandedLabel: s.t(theme.isDark ? 'theme_light' : 'theme_dark'),
            textColor: theme.isDark ? colors.accentAmber : colors.accentPurple,
            isCompact: isCompact,
            tooltip: s.t('theme_tooltip'),
            colors: colors,
            onTap: () => theme.toggleTheme(),
          ),

          const SizedBox(width: 6),

          // 4. Glassmorphism Settings Button with Hover Zoom & Full Text
          TopBarExpandingButton(
            icon: Icon(
              Icons.settings_rounded,
              color: colors.textSecondary,
              size: 14,
            ),
            collapsedLabel: null,
            expandedLabel: s.t('settings_btn_label'),
            textColor: colors.accentCyan,
            isCompact: isCompact,
            tooltip: s.t('settings_tooltip'),
            colors: colors,
            onTap: () => _showGlassSettingsDialog(context, theme),
          ),
        ],
      ),
    );
  }

  void _showGlassSettingsDialog(BuildContext context, ThemeProvider theme) {
    final colors = theme.colors;
    final s = context.strings;
    final origCardBlur = theme.cardBlur;
    final origCardOpacity = theme.cardOpacity;
    final origDialogBlur = theme.dialogBlur;
    final origDialogOpacity = theme.dialogOpacity;
    final origDropdownBlur = theme.dropdownBlur;
    final origDropdownOpacity = theme.dropdownOpacity;

    double localCardBlur = origCardBlur;
    double localCardOpacity = origCardOpacity;
    double localDialogBlur = origDialogBlur;
    double localDialogOpacity = origDialogOpacity;
    double localDropdownBlur = origDropdownBlur;
    double localDropdownOpacity = origDropdownOpacity;

    int activeTab = 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return GlassDialog(
              title: s.t('settings_dialog_title'),
              icon: Icons.tune_rounded,
              isDark: theme.isDark,
              width: 600,
              height: 560,
              blurSigma: localDialogBlur,
              bgOpacity: localDialogOpacity,
              actions: [
                TextButton(
                  onPressed: () {
                    theme.setLiveGlassmorphism(
                      cardBlur: origCardBlur,
                      cardOpacity: origCardOpacity,
                      dialogBlur: origDialogBlur,
                      dialogOpacity: origDialogOpacity,
                      dropdownBlur: origDropdownBlur,
                      dropdownOpacity: origDropdownOpacity,
                      persist: false,
                    );
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    s.t('action_cancel'),
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                GlowingActionButton(
                  height: 36,
                  colors: colors,
                  icon: Icons.save_rounded,
                  label: s.t('action_save'),
                  onPressed: () {
                    theme.setLiveGlassmorphism(
                      cardBlur: localCardBlur,
                      cardOpacity: localCardOpacity,
                      dialogBlur: localDialogBlur,
                      dialogOpacity: localDialogOpacity,
                      dropdownBlur: localDropdownBlur,
                      dropdownOpacity: localDropdownOpacity,
                      persist: true,
                    );
                    Navigator.pop(ctx);
                  },
                ),
              ],
              child: Column(
                children: [
                  _SettingsTabSelector(
                    activeTab: activeTab,
                    colors: colors,
                    strings: s,
                    onTabSelected: (index) {
                      setDialogState(() => activeTab = index);
                    },
                  ),
                  Divider(color: colors.subCardBorder, height: 1),
                  Expanded(
                    child: activeTab == 0
                        ? _SettingsGlassTuningTab(
                            colors: colors,
                            theme: theme,
                            strings: s,
                            localCardBlur: localCardBlur,
                            localCardOpacity: localCardOpacity,
                            localDialogBlur: localDialogBlur,
                            localDialogOpacity: localDialogOpacity,
                            localDropdownBlur: localDropdownBlur,
                            localDropdownOpacity: localDropdownOpacity,
                            onCardBlurChanged: (v) {
                              setDialogState(() => localCardBlur = v);
                              theme.setLiveGlassmorphism(cardBlur: v);
                            },
                            onCardOpacityChanged: (v) {
                              setDialogState(() => localCardOpacity = v);
                              theme.setLiveGlassmorphism(cardOpacity: v);
                            },
                            onDialogBlurChanged: (v) {
                              setDialogState(() => localDialogBlur = v);
                              theme.setLiveGlassmorphism(dialogBlur: v);
                            },
                            onDialogOpacityChanged: (v) {
                              setDialogState(() => localDialogOpacity = v);
                              theme.setLiveGlassmorphism(dialogOpacity: v);
                            },
                            onDropdownBlurChanged: (v) {
                              setDialogState(() => localDropdownBlur = v);
                              theme.setLiveGlassmorphism(dropdownBlur: v);
                            },
                            onDropdownOpacityChanged: (v) {
                              setDialogState(() => localDropdownOpacity = v);
                              theme.setLiveGlassmorphism(dropdownOpacity: v);
                            },
                            onResetDefaults: () {
                              setDialogState(() {
                                localCardBlur = 20.0;
                                localCardOpacity = 0.25;
                                localDialogBlur = 20.0;
                                localDialogOpacity = 0.85;
                                localDropdownBlur = 20.0;
                                localDropdownOpacity = 0.86;
                              });
                              theme.setLiveGlassmorphism(
                                cardBlur: 20.0,
                                cardOpacity: 0.25,
                                dialogBlur: 20.0,
                                dialogOpacity: 0.85,
                                dropdownBlur: 20.0,
                                dropdownOpacity: 0.86,
                              );
                            },
                          )
                        : (activeTab == 1
                              ? _SettingsUserGuideTab(
                                  colors: colors,
                                  strings: s,
                                )
                              : _SettingsAboutTab(
                                  colors: colors,
                                  theme: theme,
                                  strings: s,
                                  appVersion: widget.appVersion,
                                  isDebug: widget.isDebug,
                                )),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getFallbackBuildTimestamp() {
    try {
      final exe = File(Platform.resolvedExecutable);
      final so = File(
        '${exe.parent.path}${Platform.pathSeparator}data${Platform.pathSeparator}app.so',
      );
      final f = so.existsSync() ? so : (exe.existsSync() ? exe : null);
      if (f != null) {
        final dt = f.lastModifiedSync();
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }
}
