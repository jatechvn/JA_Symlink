// lib/modules/ui/main_window.dart
// Main application window widget with symlink table and actions

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic.dart';
import '../symlink_service.dart';
import '../constants.dart';
import '../i18n.dart';
import '../utils.dart';
import 'styles.dart';
import 'dialogs.dart';
import 'package:file_picker/file_picker.dart';

class MainWindow extends StatefulWidget {
  final SymlinkLogic logic;
  final ThemeNotifier themeNotifier;
  final LanguageNotifier languageNotifier;

  const MainWindow({
    super.key,
    required this.logic,
    required this.themeNotifier,
    required this.languageNotifier,
  });

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  AppColors  get _c => widget.themeNotifier.colors;
  AppStrings get _s => widget.languageNotifier.strings;

  List<SymlinkEntry> _entries = [];
  List<SymlinkEntry> _filteredEntries = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String _statusMessage = '';
  double _progressPercent = 0.0;
  String _progressDetail = '';
  String _filterStatus = 'ALL'; // ALL, ACTIVE, REMOVED, CHANGED
  int? _selectedIndex;
  final GlobalKey _themeButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initialize();
    // rebuild when language changes
    widget.languageNotifier.addListener(_onLanguageChange);
  }

  @override
  void dispose() {
    widget.languageNotifier.removeListener(_onLanguageChange);
    super.dispose();
  }

  void _onLanguageChange() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    await widget.logic.initialize();
    _isAdmin = await widget.logic.isAdmin();
    await _refreshEntries();
  }

  Future<void> _refreshEntries() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _entries = await widget.logic.getAllEntries();
      _applyFilter();
      _statusMessage = _s.activeCount(_entries.where((e) => e.isActive).length);
    } catch (e) {
      _statusMessage = 'Error: $e';
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _applyFilter() {
    if (_filterStatus == 'ALL') {
      _filteredEntries = List.from(_entries);
    } else {
      _filteredEntries = _entries.where((e) => e.status == _filterStatus).toList();
    }
  }

  Future<void> _createSymlink() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const CreateSymlinkDialog(),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
        _statusMessage = _s.msgCreating;
        _progressPercent = 0.0;
        _progressDetail = '';
      });

      final opResult = await widget.logic.createSymlink(
        sourcePath: result['source'],
        targetPath: result['target'],
        moveData: result['moveData'],
        killProcesses: result['killProcesses'],
        onProgress: (percent, fileName, sizeInfo) {
          setState(() {
            _progressPercent = percent;
            _progressDetail = '$fileName ($sizeInfo)';
          });
        },
      );

      if (!mounted) return;
      final statusMsg = opResult.success ? _s.msgCreateSuccess : _s.localizeError(opResult.message);
      setState(() {
        _statusMessage = statusMsg;
        _progressPercent = 0.0;
        _progressDetail = '';
      });
      _showSnackbar(statusMsg, isError: !opResult.success);
      await _refreshEntries();
    }
  }

  Future<void> _changeSymlink() async {
    if (_selectedIndex == null || _selectedIndex! >= _filteredEntries.length) {
      _showSnackbar(_s.errSelectActive, isError: true);
      return;
    }

    final entry = _filteredEntries[_selectedIndex!];
    if (!entry.isActive) {
      _showSnackbar(_s.errOnlyChange, isError: true);
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ChangeSymlinkDialog(
        currentLinkPath: entry.linkPath,
        currentTargetPath: entry.targetPath,
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
        _statusMessage = _s.msgChanging;
        _progressPercent = 0.0;
        _progressDetail = '';
      });

      final opResult = await widget.logic.changeSymlink(
        linkPath: entry.linkPath,
        newTargetPath: result['newTarget'],
        moveData: result['moveData'],
        onProgress: (percent, fileName, sizeInfo) {
          setState(() {
            _progressPercent = percent;
            _progressDetail = '$fileName ($sizeInfo)';
          });
        },
      );

      if (!mounted) return;
      final statusMsg = opResult.success ? _s.msgChangeSuccess : _s.localizeError(opResult.message);
      setState(() {
        _statusMessage = statusMsg;
        _progressPercent = 0.0;
        _progressDetail = '';
      });
      _showSnackbar(statusMsg, isError: !opResult.success);
      await _refreshEntries();
    }
  }

  Future<void> _removeSymlink() async {
    if (_selectedIndex == null || _selectedIndex! >= _filteredEntries.length) {
      _showSnackbar(_s.errSelectActive, isError: true);
      return;
    }

    final entry = _filteredEntries[_selectedIndex!];
    if (!entry.isActive) {
      _showSnackbar(_s.errOnlyRemove, isError: true);
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RemoveSymlinkDialog(
        linkPath: entry.linkPath,
        targetPath: entry.targetPath,
        hasBackup: entry.hasBackup,
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
        _statusMessage = _s.msgRemoving;
      });

      final opResult = await widget.logic.removeSymlink(
        linkPath: entry.linkPath,
        restoreBackup: result['restoreBackup'],
      );

      if (!mounted) return;
      final statusMsg = opResult.success ? _s.msgRemoveSuccess : _s.localizeError(opResult.message);
      setState(() => _statusMessage = statusMsg);
      _showSnackbar(statusMsg, isError: !opResult.success);
      _selectedIndex = null;
      await _refreshEntries();
    }
  }

  Future<void> _scanSystem() async {
    setState(() {
      _isLoading = true;
      _statusMessage = _s.msgScanning;
    });

    final results = await widget.logic.scanSystemSymlinks();
    final trackedLinks = _entries.where((e) => e.isActive).map((e) => e.linkPath.toLowerCase()).toSet();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _statusMessage = _s.scanFound(results.length);
    });

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => ScanResultsDialog(
        results: results,
        trackedLinks: trackedLinks,
      ),
    );
  }

  void _showUserGuide() {
    showDialog(
      context: context,
      builder: (_) => const UserGuideDialog(),
    );
  }

  Future<void> _verifySymlinks() async {
    setState(() {
      _isLoading = true;
      _statusMessage = _s.msgVerifying;
    });

    final results = await widget.logic.verifyAndFixEntries();

    if (!mounted) return;

    final fixed  = results.where((r) => r['status'] == 'FIXED').length;
    final ok     = results.where((r) => r['status'] == 'OK').length;
    final broken = results.where((r) => r['status'] != 'OK' && r['status'] != 'FIXED').length;

    setState(() {
      _isLoading = false;
      _statusMessage = _s.verifiedSummary(ok, fixed, broken);
    });

    if (fixed > 0) await _refreshEntries();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => VerifyResultsDialog(results: results),
    );
  }

  Future<void> _exportSymlinks() async {
    final timestamp = formatTimestampFileName();
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Symlinks',
      fileName: 'ja_symlinks_export_$timestamp.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputFile != null) {
      setState(() {
        _isLoading = true;
        _statusMessage = _s.msgProcessing;
      });

      final opResult = await widget.logic.exportSymlinks(outputFile);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = opResult.success ? _s.msgExportSuccess : _s.localizeError(opResult.message);
      });
      _showSnackbar(
        opResult.success ? _s.msgExportSuccess : _s.localizeError(opResult.message),
        isError: !opResult.success,
      );
    }
  }

  Future<void> _importSymlinks() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Symlinks',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      setState(() {
        _isLoading = true;
        _statusMessage = _s.msgProcessing;
      });

      try {
        final importResult = await widget.logic.importSymlinks(filePath);

        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _statusMessage = _s.totalSummary(_entries.length, _entries.where((e) => e.isActive).length);
        });

        await _refreshEntries();

        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => ImportResultsDialog(result: importResult),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _statusMessage = '${_s.errImportFailed}: $e';
        });
        _showSnackbar('${_s.errImportFailed}: $e', isError: true);
      }
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? _c.statusRemoved : _c.statusActive,
              size: 20,
            ),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _c.bgPrimary,
      child: Scaffold(
        body: Column(
          children: [
            _buildActionBar(),
            Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Container(
                        width: 420,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: _c.bgTertiary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _c.borderDefault),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_progressPercent > 0.0) ...[
                              Text(
                                '${(_progressPercent * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _c.linkAccent,
                                  fontFamily: 'Cascadia Code',
                                ),
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: _progressPercent,
                                  backgroundColor: _c.borderDefault,
                                  color: _c.linkAccent,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _statusMessage,
                                style: TextStyle(color: _c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _progressDetail,
                                style: TextStyle(color: _c.textMuted, fontSize: 11, fontFamily: 'Cascadia Code'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ] else ...[
                              CircularProgressIndicator(color: _c.linkAccent),
                              const SizedBox(height: 16),
                              Text(
                                _statusMessage.isNotEmpty ? _statusMessage : _s.msgProcessing,
                                style: TextStyle(color: _c.textMuted, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : _buildTable(),
            ),
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  // ─── Action Bar ──────────────────────────────────────────────────────────

  Widget _buildActionBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _c.bgSecondary,
      child: Row(
        children: [
          // App title
          Icon(Icons.link, color: _c.linkAccent, size: 22),
          SizedBox(width: 10),
          Text(
            appName,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _c.textPrimary, letterSpacing: 0.5),
          ),
          SizedBox(width: 8),
          Text('v$appVersion', style: TextStyle(fontSize: 12, color: _c.textMuted)),
          const Spacer(),
          // Filter chips
          _buildFilterChip('ALL',     _s.filterAll),
          SizedBox(width: 6),
          _buildFilterChip('ACTIVE',  _s.filterActive),
          SizedBox(width: 6),
          _buildFilterChip('CHANGED', _s.filterChanged),
          SizedBox(width: 6),
          _buildFilterChip('REMOVED', _s.filterRemoved),
          SizedBox(width: 20),
          // CRUD buttons
          _buildActionButton(icon: Icons.add_link,   label: _s.btnCreate, onPressed: _createSymlink, color: _c.statusActive),
          SizedBox(width: 8),
          _buildActionButton(icon: Icons.swap_horiz, label: _s.btnChange, onPressed: _changeSymlink, color: _c.statusChanged),
          SizedBox(width: 8),
          _buildActionButton(icon: Icons.link_off,   label: _s.btnRemove, onPressed: _removeSymlink, color: _c.statusRemoved),
          SizedBox(width: 16),
          // Verify, Scan, Import, Export group in a PopupMenu
          PopupMenuButton<String>(
            tooltip: _s.btnMore,
            offset: const Offset(0, 46),
            color: _c.bgSecondary.withValues(alpha: 0.96),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: _c.borderDefault),
            ),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _c.bgTertiary,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _c.borderDefault),
              ),
              child: Icon(Icons.apps, color: _c.linkAccent, size: 20),
            ),
            onSelected: (value) {
              switch (value) {
                case 'verify':
                  _verifySymlinks();
                  break;
                case 'scan':
                  _scanSystem();
                  break;
                case 'import':
                  _importSymlinks();
                  break;
                case 'export':
                  _exportSymlinks();
                  break;
                case 'guide':
                  _showUserGuide();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'verify',
                child: Row(
                  children: [
                    Icon(Icons.verified_outlined, color: _c.statusActive, size: 18),
                    const SizedBox(width: 10),
                    Text(_s.menuVerify, style: TextStyle(fontSize: 13, color: _c.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'scan',
                child: Row(
                  children: [
                    Icon(Icons.radar, color: _c.linkAccent, size: 18),
                    const SizedBox(width: 10),
                    Text(_s.menuScan, style: TextStyle(fontSize: 13, color: _c.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, color: _c.linkAccent, size: 18),
                    const SizedBox(width: 10),
                    Text(_s.menuImport, style: TextStyle(fontSize: 13, color: _c.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, color: _c.statusActive, size: 18),
                    const SizedBox(width: 10),
                    Text(_s.menuExport, style: TextStyle(fontSize: 13, color: _c.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'guide',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: _c.linkAccent, size: 18),
                    const SizedBox(width: 10),
                    Text(_s.menuGuide, style: TextStyle(fontSize: 13, color: _c.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(width: 6),
          // Refresh
          Tooltip(
            message: _s.tooltipRefresh,
            child: IconButton(
              onPressed: _refreshEntries,
              icon: Icon(Icons.refresh, color: _c.textSecondary),
              style: _iconBtnStyle(),
            ),
          ),
          SizedBox(width: 6),
          // Theme toggle
          Tooltip(
            key: _themeButtonKey,
            message: _s.tooltipTheme(_themeModeName),
            child: IconButton(
              onPressed: () {
                final themeReveal = context.findAncestorStateOfType<ThemeRevealState>();
                if (themeReveal != null) {
                  themeReveal.triggerReveal(
                    buttonKey: _themeButtonKey,
                    onToggle: () {
                      widget.themeNotifier.toggle(MediaQuery.platformBrightnessOf(context));
                      setState(() {});
                    },
                  );
                } else {
                  widget.themeNotifier.toggle(MediaQuery.platformBrightnessOf(context));
                  setState(() {});
                }
              },
              icon: Icon(widget.themeNotifier.modeIcon, color: _c.linkAccent),
              style: _iconBtnStyle(),
            ),
          ),
          SizedBox(width: 6),
          // Language toggle — Globe icon + short label
          Tooltip(
            message: '${_s.tooltipLanguage}: ${widget.languageNotifier.language.fullLabel}',
            child: InkWell(
              onTap: () {
                widget.languageNotifier.cycleNext();
                setState(() {});
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 36,
                padding: EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _c.bgTertiary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _c.borderDefault),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language, size: 16, color: _c.linkAccent),
                    SizedBox(width: 5),
                    Text(
                      widget.languageNotifier.language.shortLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _c.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _themeModeName {
    switch (widget.themeNotifier.mode) {
      case AppThemeMode.dark:  return _s.themeDark;
      case AppThemeMode.light: return _s.themeLight;
      case AppThemeMode.auto:  return _s.themeAuto;
    }
  }

  ButtonStyle _iconBtnStyle() => IconButton.styleFrom(
    backgroundColor: _c.bgTertiary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: BorderSide(color: _c.borderDefault),
    ),
  );

  Widget _buildFilterChip(String status, String label) {
    final isSelected = _filterStatus == status;
    final count = status == 'ALL'
        ? _entries.length
        : _entries.where((e) => e.status == status).length;

    return InkWell(
      onTap: () => setState(() {
        _filterStatus = status;
        _selectedIndex = null;
        _applyFilter();
      }),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _c.linkAccent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _c.linkAccent.withValues(alpha: 0.4) : _c.borderDefault,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? _c.linkAccent : _c.textMuted,
              ),
            ),
            SizedBox(width: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? _c.linkAccent.withValues(alpha: 0.18) : _c.bgTertiary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? _c.linkAccent : _c.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      height: 34,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          elevation: 0,
          side: BorderSide(color: color.withValues(alpha: 0.35)),
          padding: EdgeInsets.symmetric(horizontal: 14),
          textStyle: TextStyle(fontFamily: 'Segoe UI', fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ─── Table ───────────────────────────────────────────────────────────────

  Widget _buildTable() {
    if (_filteredEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 64, color: _c.textMuted.withValues(alpha: 0.25)),
            SizedBox(height: 16),
            Text(_s.emptyTitle, style: TextStyle(fontSize: 16, color: _c.textMuted, fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            Text(_s.emptySubtitle, style: TextStyle(fontSize: 13, color: _c.textMuted)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header row
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: _c.bgTertiary,
          child: Row(
            children: [
              SizedBox(width: 44, child: _headerCell(_s.colNum)),
              Expanded(flex: 3, child: _headerCell(_s.colLinkPath)),
              Expanded(flex: 3, child: _headerCell(_s.colTarget)),
              Expanded(flex: 2, child: _headerCell(_s.colBackup)),
              SizedBox(width: 90,  child: _headerCell(_s.colStatus)),
              SizedBox(width: 140, child: _headerCell(_s.colTimestamp)),
            ],
          ),
        ),
        Divider(height: 1),
        // Data rows
        Expanded(
          child: ListView.builder(
            itemCount: _filteredEntries.length,
            itemBuilder: (context, index) => _buildRow(index),
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String text) => Text(
    text,
    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: _c.textMuted, letterSpacing: 0.5),
  );

  Widget _buildRow(int index) {
    final entry = _filteredEntries[index];
    final isSelected = _selectedIndex == index;

    return Material(
      color: isSelected
          ? _c.linkAccent.withValues(alpha: 0.08)
          : (index.isEven ? Colors.transparent : _c.bgSecondary.withValues(alpha: 0.15)),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = isSelected ? null : index),
        hoverColor: _c.bgHover,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _c.borderDefault.withValues(alpha: 0.15))),
          ),
          child: Row(
            children: [
              // Left selection indicator
              Container(
                width: 3, height: 18,
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _c.linkAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              // Row number
              SizedBox(
                width: 33,
                child: Text('${index + 1}', style: TextStyle(color: _c.textMuted, fontSize: 12)),
              ),
              // Link path
              Expanded(
                flex: 3,
                child: Tooltip(
                  message: entry.linkPath,
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 14, color: entry.isActive ? _c.linkAccent : _c.textMuted),
                      SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Clipboard.setData(ClipboardData(text: entry.linkPath)),
                          child: StyledWidgets.pathDisplay(entry.linkPath,
                              color: entry.isActive ? _c.textPrimary : _c.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Target path
              Expanded(
                flex: 3,
                child: Tooltip(
                  message: entry.targetPath,
                  child: Row(
                    children: [
                      Icon(Icons.east, size: 12, color: _c.textMuted),
                      SizedBox(width: 6),
                      Expanded(child: StyledWidgets.pathDisplay(entry.targetPath, color: _c.targetAccent)),
                    ],
                  ),
                ),
              ),
              // Backup
              Expanded(
                flex: 2,
                child: StyledWidgets.pathDisplay(
                  entry.backupPath == 'NONE' ? '-' : entry.backupPath,
                  color: entry.backupPath == 'NONE' ? _c.textMuted : _c.textSecondary,
                ),
              ),
              // Status badge
              SizedBox(width: 90,  child: StyledWidgets.statusBadge(entry.status, _c)),
              // Timestamp
              SizedBox(
                width: 140,
                child: Text(
                  entry.timestamp.replaceAll('_', ' '),
                  style: TextStyle(fontFamily: 'Cascadia Code', fontSize: 11, color: _c.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Status Bar ───────────────────────────────────────────────────────────

  Widget _buildStatusBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _c.bgSecondary,
      child: Row(
        children: [
          // Admin badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _isAdmin
                  ? _c.statusActive.withValues(alpha: 0.12)
                  : _c.statusChanged.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _isAdmin
                    ? _c.statusActive.withValues(alpha: 0.35)
                    : _c.statusChanged.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isAdmin ? Icons.shield : Icons.shield_outlined,
                  size: 13,
                  color: _isAdmin ? _c.statusActive : _c.statusChanged,
                ),
                SizedBox(width: 4),
                Text(
                  _isAdmin ? _s.labelAdmin : _s.labelStandard,
                  style: TextStyle(
                    fontSize: 11,
                    color: _isAdmin ? _c.statusActive : _c.statusChanged,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(_statusMessage, style: TextStyle(fontSize: 12, color: _c.textMuted)),
          ),
          Text(
            _s.totalSummary(_entries.length, _entries.where((e) => e.isActive).length),
            style: TextStyle(fontSize: 11, color: _c.textMuted),
          ),
        ],
      ),
    );
  }
}