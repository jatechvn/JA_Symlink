import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_widgets.dart';

class SystemToolsView extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onVerify;
  final VoidCallback onImport;
  final VoidCallback onExport;

  const SystemToolsView({
    super.key,
    required this.onScan,
    required this.onVerify,
    required this.onImport,
    required this.onExport,
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
          // Section Title
          Row(
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
                s.toolsTitle,
                style: TextStyle(
                  fontSize: 16,
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Top Tools Row: System Scanner & Integrity Verifier
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System Scanner Card
              Expanded(
                child: BentoCard(
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
                          Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: colors.accentCyan,
                          ),
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
                ),
              ),

              const SizedBox(width: 14),

              // Integrity Verifier Card
              Expanded(
                child: BentoCard(
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
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Bottom Tools Row: Backup & Migration (Export / Import JSON)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Export JSON Card
              Expanded(
                child: BentoCard(
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
                ),
              ),

              const SizedBox(width: 14),

              // Import JSON Card
              Expanded(
                child: BentoCard(
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
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Safety & Crash Recovery Banner Card
          BentoCard(
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
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
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
