// lib/modules/ui/dialogs.dart
// Dialog widgets for symlink operations — fully localized via context.strings

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../i18n.dart';
import '../ui/styles.dart';
import '../logic.dart';

/// Dialog for creating a new symlink
class CreateSymlinkDialog extends StatefulWidget {
  const CreateSymlinkDialog({super.key});

  @override
  State<CreateSymlinkDialog> createState() => _CreateSymlinkDialogState();
}

class _CreateSymlinkDialogState extends State<CreateSymlinkDialog> {
  final _sourceController = TextEditingController();
  final _targetController = TextEditingController();
  bool _moveData = true;
  bool _killProcesses = true;

  AppColors  get _c => context.appColors;
  AppStrings get _s => context.strings;

  @override
  void dispose() {
    _sourceController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  String get _resolvedTargetPath {
    final source = _sourceController.text.trim();
    final target = _targetController.text.trim();
    if (source.isEmpty || target.isEmpty) return target;
    final appName = p.basename(source);
    if (p.basename(target) == appName) return target;
    return p.join(target, appName);
  }

  Future<void> _pickFolder(TextEditingController controller) async {
    String? result = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select Folder');
    if (result != null) {
      controller.text = result;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.add_link, color: _c.linkAccent, size: 24),
        SizedBox(width: 10),
        Text(_s.dlgCreateTitle),
      ]),
      content: SizedBox(
        width: 550,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_s.dlgCreateDesc, style: TextStyle(color: _c.textSecondary, fontSize: 13)),
            SizedBox(height: 20),
            // Source path
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _sourceController,
                  decoration: InputDecoration(
                    labelText: _s.labelSourcePath,
                    hintText: _s.hintSourcePath,
                    prefixIcon: Icon(Icons.folder_outlined, size: 20),
                  ),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: () => _pickFolder(_sourceController),
                icon: Icon(Icons.folder_open, color: _c.linkAccent),
                tooltip: _s.btnBrowse,
              ),
            ]),
            SizedBox(height: 14),
            // Target path
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _targetController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _s.labelTargetFolder,
                    hintText: _s.hintTargetFolder,
                    prefixIcon: Icon(Icons.drive_file_move_outline, size: 20),
                  ),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: () => _pickFolder(_targetController),
                icon: Icon(Icons.folder_open, color: _c.linkAccent),
                tooltip: _s.btnBrowse,
              ),
            ]),
            if (_resolvedTargetPath.isNotEmpty && _sourceController.text.trim().isNotEmpty) ...[
              SizedBox(height: 8),
              _previewBox(_s.labelFinal, _resolvedTargetPath),
            ],
            SizedBox(height: 18),
            // Options box
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _c.bgTertiary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _c.borderDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_s.labelOptions,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _c.textPrimary)),
                  SizedBox(height: 8),
                  CheckboxListTile(
                    value: _moveData,
                    onChanged: (v) => setState(() => _moveData = v ?? true),
                    title: Text(_s.optMoveData, style: TextStyle(fontSize: 13, color: _c.textPrimary)),
                    subtitle: Text(_s.optMoveDataSub, style: TextStyle(fontSize: 11, color: _c.textSecondary)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: _killProcesses,
                    onChanged: (v) => setState(() => _killProcesses = v ?? true),
                    title: Text(_s.optKillProc, style: TextStyle(fontSize: 13, color: _c.textPrimary)),
                    subtitle: Text(_s.optKillProcSub, style: TextStyle(fontSize: 11, color: _c.textSecondary)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(_s.btnCancel)),
        ElevatedButton.icon(
          onPressed: () {
            if (_sourceController.text.trim().isEmpty || _targetController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_s.errFillPaths)));
              return;
            }
            Navigator.pop(context, {
              'source': _sourceController.text.trim(),
              'target': _resolvedTargetPath,
              'moveData': _moveData,
              'killProcesses': _killProcesses,
            });
          },
          icon: Icon(Icons.link, size: 18),
          label: Text(_s.btnCreateSymlink),
        ),
      ],
    );
  }
}

/// Dialog for changing symlink target
class ChangeSymlinkDialog extends StatefulWidget {
  final String currentLinkPath;
  final String currentTargetPath;

  const ChangeSymlinkDialog({
    super.key,
    required this.currentLinkPath,
    required this.currentTargetPath,
  });

  @override
  State<ChangeSymlinkDialog> createState() => _ChangeSymlinkDialogState();
}

class _ChangeSymlinkDialogState extends State<ChangeSymlinkDialog> {
  final _newTargetController = TextEditingController();
  bool _moveData = false;

  AppColors  get _c => context.appColors;
  AppStrings get _s => context.strings;

  @override
  void dispose() {
    _newTargetController.dispose();
    super.dispose();
  }

  String get _appFolderName => p.basename(widget.currentLinkPath);

  String get _resolvedTargetPath {
    final target = _newTargetController.text.trim();
    if (target.isEmpty) return target;
    if (p.basename(target) == _appFolderName) return target;
    return p.join(target, _appFolderName);
  }

  Future<void> _pickFolder() async {
    String? result = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select New Target Parent Folder');
    if (result != null) {
      _newTargetController.text = result;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.swap_horiz, color: _c.statusChanged, size: 24),
        SizedBox(width: 10),
        Text(_s.dlgChangeTitle),
      ]),
      content: SizedBox(
        width: 550,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current symlink info
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _c.bgTertiary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _c.borderDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_s.labelCurrSymlink,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _c.textPrimary)),
                  SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.link, size: 16, color: _c.textMuted),
                    SizedBox(width: 8),
                    Expanded(child: StyledWidgets.pathDisplay(widget.currentLinkPath, c: _c)),
                  ]),
                  SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.arrow_forward, size: 16, color: _c.textMuted),
                    SizedBox(width: 8),
                    Expanded(child: StyledWidgets.pathDisplay(widget.currentTargetPath, color: _c.linkAccent)),
                  ]),
                ],
              ),
            ),
            SizedBox(height: 18),
            // New target
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _newTargetController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _s.labelNewTarget,
                    hintText: _s.hintNewTarget(_appFolderName),
                    prefixIcon: Icon(Icons.drive_file_move_outline, size: 20),
                  ),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: _pickFolder,
                icon: Icon(Icons.folder_open, color: _c.linkAccent),
                tooltip: _s.btnBrowse,
              ),
            ]),
            if (_resolvedTargetPath.isNotEmpty) ...[
              SizedBox(height: 8),
              _previewBox(_s.labelFinal, _resolvedTargetPath),
            ],
            SizedBox(height: 14),
            CheckboxListTile(
              value: _moveData,
              onChanged: (v) => setState(() => _moveData = v ?? false),
              title: Text(_s.optMoveDataNew, style: TextStyle(fontSize: 13, color: _c.textPrimary)),
              subtitle: Text(_s.optMoveDataNewSub, style: TextStyle(fontSize: 11, color: _c.textSecondary)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(_s.btnCancel)),
        ElevatedButton.icon(
          onPressed: () {
            if (_newTargetController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_s.errEnterTarget)));
              return;
            }
            Navigator.pop(context, {'newTarget': _resolvedTargetPath, 'moveData': _moveData});
          },
          icon: Icon(Icons.swap_horiz, size: 18),
          label: Text(_s.btnChangeTarget),
          style: ElevatedButton.styleFrom(
            backgroundColor: _c.statusChanged,
            foregroundColor: _c.brightness == Brightness.dark ? const Color(0xFF0D1117) : Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Confirmation dialog for removing symlink
class RemoveSymlinkDialog extends StatefulWidget {
  final String linkPath;
  final String targetPath;
  final bool hasBackup;

  const RemoveSymlinkDialog({
    super.key,
    required this.linkPath,
    required this.targetPath,
    this.hasBackup = false,
  });

  @override
  State<RemoveSymlinkDialog> createState() => _RemoveSymlinkDialogState();
}

class _RemoveSymlinkDialogState extends State<RemoveSymlinkDialog> {
  bool _restoreBackup = false;

  AppColors  get _c => context.appColors;
  AppStrings get _s => context.strings;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.link_off, color: _c.statusRemoved, size: 24),
        SizedBox(width: 10),
        Text(_s.dlgRemoveTitle),
      ]),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _c.statusRemoved.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _c.statusRemoved.withValues(alpha: 0.35)),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber, color: _c.statusRemoved, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text(_s.warnRemove, style: TextStyle(color: _c.textSecondary, fontSize: 13))),
              ]),
            ),
            SizedBox(height: 16),
            Row(children: [
              Icon(Icons.link, size: 16, color: _c.textMuted),
              SizedBox(width: 8),
              Expanded(child: StyledWidgets.pathDisplay(widget.linkPath, c: _c)),
            ]),
            SizedBox(height: 6),
            Row(children: [
              Icon(Icons.arrow_forward, size: 16, color: _c.textMuted),
              SizedBox(width: 8),
              Expanded(child: StyledWidgets.pathDisplay(widget.targetPath, color: _c.linkAccent)),
            ]),
            if (widget.hasBackup) ...[
              SizedBox(height: 14),
              CheckboxListTile(
                value: _restoreBackup,
                onChanged: (v) => setState(() => _restoreBackup = v ?? false),
                title: Text(_s.optRestoreBackup, style: TextStyle(fontSize: 13, color: _c.textPrimary)),
                subtitle: Text(_s.optRestoreBackupSub, style: TextStyle(fontSize: 11, color: _c.textSecondary)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(_s.btnCancel)),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, {'restoreBackup': _restoreBackup}),
          icon: Icon(Icons.delete_outline, size: 18),
          label: Text(_s.btnRemoveConfirm),
          style: ElevatedButton.styleFrom(
            backgroundColor: _c.statusRemoved,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Scan system dialog showing results
class ScanResultsDialog extends StatelessWidget {
  final List<Map<String, String>> results;
  final Set<String> trackedLinks;

  const ScanResultsDialog({
    super.key,
    required this.results,
    required this.trackedLinks,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.radar, color: c.linkAccent, size: 24),
        SizedBox(width: 10),
        Text(s.scanTitle(results.length)),
      ]),
      content: SizedBox(
        width: 650,
        height: 400,
        child: results.isEmpty
            ? Center(child: Text(s.scanEmpty, style: TextStyle(color: c.textMuted)))
            : ListView.separated(
                itemCount: results.length,
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = results[index];
                  final link = item['link'] ?? '';
                  final isTracked = trackedLinks.contains(link.toLowerCase());
                  final badgeText = isTracked ? s.badgeTracked : s.badgeUntracked;
                  final badgeColor = isTracked ? c.statusActive : c.statusChanged;
                  final leadingColor = isTracked ? c.linkAccent : c.statusChanged;

                  return Container(
                    decoration: BoxDecoration(
                      color: isTracked ? null : c.statusChanged.withValues(alpha: 0.08),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        isTracked ? Icons.link : Icons.explore_outlined,
                        size: 18,
                        color: leadingColor,
                      ),
                      title: StyledWidgets.pathDisplay(link, c: c),
                      subtitle: Row(children: [
                        Icon(Icons.arrow_forward, size: 12, color: c.textMuted),
                        SizedBox(width: 4),
                        Expanded(child: StyledWidgets.pathDisplay(item['target'] ?? '', color: c.targetAccent)),
                      ]),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(s.btnClose)),
      ],
    );
  }
}

/// Dialog showing verify results
class VerifyResultsDialog extends StatelessWidget {
  final List<Map<String, String>> results;
  const VerifyResultsDialog({super.key, required this.results});

  Color _statusColor(String status, AppColors c) {
    switch (status) {
      case 'OK':      return c.statusActive;
      case 'FIXED':   return c.statusChanged;
      case 'BROKEN':
      case 'MISSING':
      case 'ERROR':   return c.statusRemoved;
      default:        return c.textMuted;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'OK':      return Icons.check_circle;
      case 'FIXED':   return Icons.build_circle;
      case 'BROKEN':  return Icons.error;
      case 'MISSING': return Icons.help;
      case 'ERROR':   return Icons.warning;
      default:        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;
    final fixed  = results.where((r) => r['status'] == 'FIXED').length;
    final ok     = results.where((r) => r['status'] == 'OK').length;
    final broken = results.where((r) => r['status'] != 'OK' && r['status'] != 'FIXED').length;

    return AlertDialog(
      title: Row(children: [
        Icon(Icons.verified, color: c.statusActive, size: 24),
        SizedBox(width: 10),
        Text(s.dlgVerifyTitle),
        Spacer(),
        Text('$ok ✓  $fixed ⚡  $broken ✗', style: TextStyle(fontSize: 13, color: c.textSecondary)),
      ]),
      content: SizedBox(
        width: 700,
        height: 400,
        child: results.isEmpty
            ? Center(child: Text(s.verifyEmpty, style: TextStyle(color: c.textMuted)))
            : ListView.separated(
                itemCount: results.length,
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final item    = results[index];
                  final status  = item['status'] ?? 'UNKNOWN';
                  final color   = _statusColor(status, c);
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(children: [
                      Icon(_statusIcon(status), size: 20, color: color),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StyledWidgets.pathDisplay(item['link'] ?? '', c: c),
                            SizedBox(height: 4),
                            Row(children: [
                              Text(s.labelCsvTarget, style: TextStyle(fontSize: 10, color: c.textMuted)),
                              Expanded(child: StyledWidgets.pathDisplay(
                                item['csvTarget'] ?? '',
                                color: status == 'OK' ? c.statusActive : c.statusRemoved,
                              )),
                            ]),
                            if (status == 'FIXED') ...[
                              SizedBox(height: 2),
                              Row(children: [
                                Text(s.labelActualTarget, style: TextStyle(fontSize: 10, color: c.statusChanged)),
                                Expanded(child: StyledWidgets.pathDisplay(item['actualTarget'] ?? '', color: c.statusActive)),
                              ]),
                            ],
                            if (status != 'OK' && status != 'FIXED') ...[
                              SizedBox(height: 2),
                              Text(item['actualTarget'] ?? '',
                                  style: TextStyle(fontSize: 11, color: c.statusRemoved)),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.35)),
                        ),
                        child: Text(status,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                      ),
                    ]),
                  );
                },
              ),
      ),
      actions: [
        if (fixed > 0) ...[
          Text(s.verifyFixedMsg(fixed),
              style: TextStyle(color: c.statusChanged, fontSize: 12, fontWeight: FontWeight.w600)),
          SizedBox(width: 12),
        ],
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(s.btnClose)),
      ],
    );
  }
}

/// Dialog showing results of import operation
class ImportResultsDialog extends StatelessWidget {
  final ImportResult result;

  const ImportResultsDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.strings;

    return AlertDialog(
      title: Row(children: [
        Icon(Icons.import_export, color: c.linkAccent, size: 24),
        SizedBox(width: 10),
        Text(s.dlgImportTitle),
      ]),
      content: SizedBox(
        width: 650,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.importSummaryMsg(result.success, result.skipped, result.failed),
              style: TextStyle(color: c.textPrimary, fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 16),
            Text(
              'Details:',
              style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: c.bgTertiary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.borderDefault),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: result.details.length,
                  itemBuilder: (context, index) {
                    final detail = result.details[index];
                    Color textColor = c.textPrimary;
                    IconData icon = Icons.info_outline;
                    Color iconColor = c.textMuted;

                    if (detail.startsWith('Restored')) {
                      textColor = c.statusActive;
                      icon = Icons.check_circle_outline;
                      iconColor = c.statusActive;
                    } else if (detail.startsWith('Skipped')) {
                      textColor = c.textSecondary;
                      icon = Icons.warning_amber_outlined;
                      iconColor = c.statusChanged;
                    } else if (detail.startsWith('Failed')) {
                      textColor = c.statusRemoved;
                      icon = Icons.error_outline;
                      iconColor = c.statusRemoved;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 14, color: iconColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              detail,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Cascadia Code',
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.btnClose),
        ),
      ],
    );
  }
}


// ─── Shared preview box widget ────────────────────────────────────────────────

Widget _previewBox(String label, String path) {
  // Needs context for colors/strings — use a Builder
  return Builder(builder: (context) {
    final c = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.targetAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.targetAccent.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.preview, size: 14, color: c.targetAccent),
        SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11, color: c.textMuted)),
        Expanded(child: StyledWidgets.pathDisplay(path, color: c.targetAccent)),
      ]),
    );
  });
}

/// Detailed split-pane User Guide dialog
class UserGuideDialog extends StatefulWidget {
  const UserGuideDialog({super.key});

  @override
  State<UserGuideDialog> createState() => _UserGuideDialogState();
}

class _UserGuideDialogState extends State<UserGuideDialog> {
  int _selectedTabIndex = 0;

  AppColors  get _c => context.appColors;
  AppStrings get _s => context.strings;

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _c.bgHover : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border(left: BorderSide(color: _c.borderHighlight, width: 3.5))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? _c.borderHighlight : _c.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? _c.textPrimary : _c.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'label': _s.guideTabGeneral, 'icon': Icons.info_outline},
      {'label': _s.guideTabOps, 'icon': Icons.settings_suggest_outlined},
      {'label': _s.guideTabAdv, 'icon': Icons.radar},
      {'label': _s.guideTabSafety, 'icon': Icons.security_outlined},
    ];

    String title = '';
    String content = '';
    IconData contentIcon = Icons.info;

    switch (_selectedTabIndex) {
      case 0:
        title = _s.guideGenTitle;
        content = _s.guideGenContent;
        contentIcon = Icons.info_outline;
        break;
      case 1:
        title = _s.guideOpsTitle;
        content = _s.guideOpsContent;
        contentIcon = Icons.settings_suggest_outlined;
        break;
      case 2:
        title = _s.guideAdvTitle;
        content = _s.guideAdvContent;
        contentIcon = Icons.radar;
        break;
      case 3:
        title = _s.guideSafetyTitle;
        content = _s.guideSafetyContent;
        contentIcon = Icons.security_outlined;
        break;
    }

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _c.borderDefault)),
        ),
        child: Row(children: [
          Icon(Icons.help_outline, color: _c.linkAccent, size: 24),
          const SizedBox(width: 10),
          Text(_s.dlgGuideTitle, style: const TextStyle(fontSize: 16)),
        ]),
      ),
      content: SizedBox(
        width: 850,
        height: 500,
        child: Row(
          children: [
            // Left sidebar for navigation tabs
            Container(
              width: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: _c.borderDefault)),
                color: _c.bgPrimary.withValues(alpha: 0.3),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(
                  tabs.length,
                  (index) => _buildTabItem(
                    index,
                    tabs[index]['label'] as String,
                    tabs[index]['icon'] as IconData,
                  ),
                ),
              ),
            ),
            // Right content panel
            Expanded(
              child: Container(
                color: _c.bgSecondary.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(contentIcon, color: _c.linkAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _c.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _c.bgTertiary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _c.borderDefault),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            content,
                            style: TextStyle(
                              fontSize: 13,
                              color: _c.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_s.btnClose),
          ),
        ),
      ],
    );
  }
}
