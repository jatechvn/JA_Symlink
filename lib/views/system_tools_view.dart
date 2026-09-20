import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_widgets.dart';

class SystemToolsView extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onVerify;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onExportBatchScript;
  final VoidCallback onExportPowerShellScript;
  final VoidCallback onExportSnapshot;
  final VoidCallback onRestoreSnapshot;
  final bool isShellMenuRegistered;
  final VoidCallback onToggleShellMenu;

  const SystemToolsView({
    super.key,
    required this.onScan,
    required this.onVerify,
    required this.onImport,
    required this.onExport,
    required this.onExportBatchScript,
    required this.onExportPowerShellScript,
    required this.onExportSnapshot,
    required this.onRestoreSnapshot,
    required this.isShellMenuRegistered,
    required this.onToggleShellMenu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final s = context.strings;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ToolHeader(colors: colors, title: s.toolsTitle),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ScannerCard(colors: colors, s: s, onScan: onScan),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _IntegrityCard(colors: colors, s: s, onVerify: onVerify),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ShellContextMenuCard(
            colors: colors,
            s: s,
            isRegistered: isShellMenuRegistered,
            onToggle: onToggleShellMenu,
          ),
          const SizedBox(height: 14),
          _SurvivalKitCard(
            colors: colors,
            s: s,
            onExportBatch: onExportBatchScript,
            onExportPowerShell: onExportPowerShellScript,
            onExportSnapshot: onExportSnapshot,
            onRestoreSnapshot: onRestoreSnapshot,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ExportCard(colors: colors, s: s, onExport: onExport),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ImportCard(colors: colors, s: s, onImport: onImport),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RecoveryBanner(colors: colors, s: s),
        ],
      ),
    );
  }
}

class _ToolHeader extends StatelessWidget {
  final AppColors colors;
  final String title;

  const _ToolHeader({required this.colors, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.accentPurple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colors.accentPurple.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            Icons.build_circle_rounded,
            color: colors.accentPurple,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ScannerCard extends StatelessWidget {
  final AppColors colors;
  final AppStrings s;
  final VoidCallback onScan;

  const _ScannerCard({
    required this.colors,
    required this.s,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PillBadge(
                label: s.scannerBadge,
                color: colors.accentCyan,
                bg: colors.accentCyan.withValues(alpha: 0.12),
                border: colors.accentCyan.withValues(alpha: 0.3),
                icon: Icons.radar_rounded,
              ),
              Icon(Icons.search_rounded, size: 18, color: colors.accentCyan),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.scannerTitle,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.scannerDesc,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: GlowingActionButton(
              height: 40,
              colors: colors,
              customStartColor: colors.accentCyan,
              customEndColor: colors.accentColor,
              icon: Icons.radar_rounded,
              label: s.menuScan,
              onPressed: onScan,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegrityCard extends StatelessWidget {
  final AppColors colors;
  final AppStrings s;
  final VoidCallback onVerify;

  const _IntegrityCard({
    required this.colors,
    required this.s,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PillBadge(
                label: s.integrityBadge,
                color: colors.accentEmerald,
                bg: colors.accentEmerald.withValues(alpha: 0.12),
                border: colors.accentEmerald.withValues(alpha: 0.3),
                icon: Icons.verified_user_rounded,
              ),
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: colors.accentEmerald,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.integrityTitle,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.integrityDesc,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: GlowingActionButton(
              height: 40,
              colors: colors,
              customStartColor: colors.accentEmerald,
              customEndColor: colors.accentCyan,
              icon: Icons.verified_rounded,
              label: s.menuVerify,
              onPressed: onVerify,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurvivalKitCard extends StatelessWidget {
  final AppColors colors;
  final AppStrings s;
  final VoidCallback onExportBatch;
  final VoidCallback onExportPowerShell;
  final VoidCallback onExportSnapshot;
  final VoidCallback onRestoreSnapshot;

  const _SurvivalKitCard({
    required this.colors,
    required this.s,
    required this.onExportBatch,
    required this.onExportPowerShell,
    required this.onExportSnapshot,
    required this.onRestoreSnapshot,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PillBadge(
                label: 'WINDOWS SURVIVAL KIT',
                color: colors.accentAmber,
                bg: colors.accentAmber.withValues(alpha: 0.12),
                border: colors.accentAmber.withValues(alpha: 0.3),
                icon: Icons.terminal_rounded,
              ),
              Icon(Icons.flash_on_rounded, size: 20, color: colors.accentAmber),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.survivalKitTitle,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.survivalKitDesc,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SurvivalButton(
                colors: colors,
                icon: Icons.terminal_rounded,
                label: s.btnExportScript,
                color: colors.accentCyan,
                onPressed: onExportBatch,
              ),
              _SurvivalButton(
                colors: colors,
                icon: Icons.integration_instructions_rounded,
                label: s.btnExportPsScript,
                color: colors.accentColor,
                onPressed: onExportPowerShell,
              ),
              _SurvivalButton(
                colors: colors,
                icon: Icons.save_as_rounded,
                label: s.btnExportSnapshot,
                color: colors.accentAmber,
                onPressed: onExportSnapshot,
              ),
              _SurvivalButton(
                colors: colors,
                icon: Icons.settings_backup_restore_rounded,
                label: s.btnRestoreSnapshot,
                color: colors.accentEmerald,
                onPressed: onRestoreSnapshot,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SurvivalButton extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _SurvivalButton({
    required this.colors,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final AppColors colors;
  final AppStrings s;
  final VoidCallback onExport;

  const _ExportCard({
    required this.colors,
    required this.s,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PillBadge(
                label: s.backupBadge,
                color: colors.accentAmber,
                bg: colors.accentAmber.withValues(alpha: 0.12),
                border: colors.accentAmber.withValues(alpha: 0.3),
                icon: Icons.download_rounded,
              ),
              Icon(
                Icons.file_download_outlined,
                size: 18,
                color: colors.accentAmber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.exportTitle,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.exportDesc,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: GlowingActionButton(
              height: 40,
              colors: colors,
              customStartColor: colors.accentAmber,
              customEndColor: colors.accentRose,
              icon: Icons.download_rounded,
              label: s.menuExport,
              onPressed: onExport,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  final AppColors colors;
  final AppStrings s;
  final VoidCallback onImport;

  const _ImportCard({
    required this.colors,
    required this.s,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PillBadge(
                label: s.restoreBadge,
                color: colors.accentPurple,
                bg: colors.accentPurple.withValues(alpha: 0.12),
                border: colors.accentPurple.withValues(alpha: 0.3),
                icon: Icons.upload_rounded,
              ),
              Icon(
                Icons.file_upload_outlined,
                size: 18,
                color: colors.accentPurple,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.importTitle,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.importDesc,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: GlowingActionButton(
              height: 40,
              colors: colors,
              customStartColor: colors.accentPurple,
              customEndColor: colors.accentCyan,
              icon: Icons.upload_file_rounded,
              label: s.menuImport,
              onPressed: onImport,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryBanner extends StatelessWidget {
  final AppColors colors;
  final AppStrings s;

  const _RecoveryBanner({required this.colors, required this.s});

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.accentEmerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.accentEmerald.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              Icons.security_rounded,
              color: colors.accentEmerald,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.recoveryTitle,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.recoveryDesc,
                  style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellContextMenuCard extends StatelessWidget {
  final AppColors colors;
  final AppStrings s;
  final bool isRegistered;
  final VoidCallback onToggle;

  const _ShellContextMenuCard({
    required this.colors,
    required this.s,
    required this.isRegistered,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PillBadge(
                label: 'WINDOWS EXPLORER',
                color: colors.accentCyan,
                bg: colors.accentCyan.withValues(alpha: 0.12),
                border: colors.accentCyan.withValues(alpha: 0.3),
                icon: Icons.mouse_rounded,
              ),
              PillBadge(
                label: isRegistered
                    ? s.shellMenuRegistered
                    : s.shellMenuNotRegistered,
                color: isRegistered ? colors.accentEmerald : colors.accentAmber,
                bg: (isRegistered ? colors.accentEmerald : colors.accentAmber)
                    .withValues(alpha: 0.12),
                border:
                    (isRegistered ? colors.accentEmerald : colors.accentAmber)
                        .withValues(alpha: 0.3),
                showDot: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.shellContextMenuTitle,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.shellContextMenuDesc,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GlowingActionButton(
              height: 40,
              colors: colors,
              customStartColor: isRegistered
                  ? colors.accentRose
                  : colors.accentCyan,
              customEndColor: isRegistered
                  ? colors.accentAmber
                  : colors.accentColor,
              icon: isRegistered
                  ? Icons.delete_outline_rounded
                  : Icons.add_to_home_screen_rounded,
              label: isRegistered
                  ? s.btnUnregisterShellMenu
                  : s.btnRegisterShellMenu,
              onPressed: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}
