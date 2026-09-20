// lib/dialogs/glass_process_lock_dialog.dart
// Interactive Glass Dialog warning user about processes locking target folders.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../modules/process/process_lock_model.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_widgets.dart';

class GlassProcessLockDialog extends StatelessWidget {
  final List<ProcessLockInfo> processes;
  final String folderPath;

  const GlassProcessLockDialog({
    super.key,
    required this.processes,
    required this.folderPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final s = context.strings;

    return GlassDialog(
      title: s.dlgProcessLockTitle,
      icon: Icons.lock_clock_rounded,
      isDark: theme.isDark,
      width: 580,
      actions: [
        Flexible(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(
                  s.btnCancel,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  s.btnIgnoreAndContinue,
                  style: TextStyle(color: colors.accentAmber),
                ),
              ),
              GlowingActionButton(
                label: s.btnKillAndContinue,
                icon: Icons.power_settings_new_rounded,
                colors: colors,
                customStartColor: colors.accentRose,
                customEndColor: colors.accentAmber,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderSection(
            colors: colors,
            desc: s.dlgProcessLockDesc,
            folderPath: folderPath,
          ),
          const SizedBox(height: 14),
          _ProcessListSection(colors: colors, processes: processes),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final AppColors colors;
  final String desc;
  final String folderPath;

  const _HeaderSection({
    required this.colors,
    required this.desc,
    required this.folderPath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          desc,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.subCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.subCardBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 16,
                color: colors.accentAmber,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  folderPath,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontFamily: 'Cascadia Code',
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProcessListSection extends StatelessWidget {
  final AppColors colors;
  final List<ProcessLockInfo> processes;

  const _ProcessListSection({required this.colors, required this.processes});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: processes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final proc = processes[index];
          return _ProcessItemCard(colors: colors, proc: proc);
        },
      ),
    );
  }
}

class _ProcessItemCard extends StatelessWidget {
  final AppColors colors;
  final ProcessLockInfo proc;

  const _ProcessItemCard({required this.colors, required this.proc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.subCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.subCardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.accentRose.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: colors.accentRose,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proc.displayName,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${proc.name} (PID: ${proc.pid})'
                  '${proc.windowTitle.isNotEmpty ? ' • ${proc.windowTitle}' : ''}',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontFamily: 'Cascadia Code',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.accentRose.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'LOCKED',
              style: TextStyle(
                color: colors.accentRose,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
