import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modules/i18n.dart';
import '../theme/theme_provider.dart';
import '../widgets/glass_widgets.dart';

class UserGuideView extends StatefulWidget {
  const UserGuideView({super.key});

  @override
  State<UserGuideView> createState() => _UserGuideViewState();
}

class _UserGuideViewState extends State<UserGuideView> {
  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final s = context.strings;

    final categories = [
      {'label': s.guideTabGeneral, 'icon': Icons.info_outline_rounded},
      {'label': s.guideTabOps, 'icon': Icons.settings_suggest_rounded},
      {'label': s.guideTabAdv, 'icon': Icons.radar_rounded},
      {'label': s.guideTabSafety, 'icon': Icons.security_rounded},
    ];

    String title = '';
    String content = '';
    IconData contentIcon = Icons.info_rounded;

    switch (_selectedCategoryIndex) {
      case 0:
        title = s.guideGenTitle;
        content = s.guideGenContent;
        contentIcon = Icons.info_outline_rounded;
        break;
      case 1:
        title = s.guideOpsTitle;
        content = s.guideOpsContent;
        contentIcon = Icons.settings_suggest_rounded;
        break;
      case 2:
        title = s.guideAdvTitle;
        content = s.guideAdvContent;
        contentIcon = Icons.radar_rounded;
        break;
      case 3:
        title = s.guideSafetyTitle;
        content = s.guideSafetyContent;
        contentIcon = Icons.security_rounded;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category Pill Selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.subCardBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: colors.subCardBorder),
          ),
          child: Row(
            children: List.generate(categories.length, (index) {
              final isSelected = _selectedCategoryIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategoryIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.accentColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colors.primaryGlow.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          categories[index]['icon'] as IconData,
                          size: 15,
                          color: isSelected
                              ? Colors.white
                              : colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          categories[index]['label'] as String,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : colors.textSecondary,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 14),

        // Main Guide Bento Content Card
        Expanded(
          child: BentoCard(
            colors: colors,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        contentIcon,
                        size: 18,
                        color: colors.accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: colors.subCardBorder, height: 1),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      content,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: colors.textSecondary,
                        height: 1.65,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
