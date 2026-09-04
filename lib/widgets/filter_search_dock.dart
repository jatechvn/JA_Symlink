import 'package:flutter/material.dart';
import '../modules/i18n.dart';
import '../theme/app_colors.dart';
import 'glass_widgets.dart';

/// A search field + horizontal row of toggleable filter pills, styled to
/// match the glass design system.
class FilterSearchDock extends StatelessWidget {
  const FilterSearchDock({
    super.key,
    required this.colors,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterSelected,
    this.filterCounts,
    this.filterLabels,
    this.searchController,
    this.onSearchChanged,
    this.searchHint,
    this.trailing,
  });

  final AppColors colors;
  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;
  final Map<String, int>? filterCounts;
  final Map<String, String>? filterLabels;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final String? searchHint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final localizedSearchHint = searchHint ?? context.strings.searchPathsHint;
    return GlassContainer(
      colors: colors,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: colors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: localizedSearchHint,
                    hintStyle: TextStyle(color: colors.textMuted),
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          if (filters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(color: colors.subCardBorder, height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: filters.map((f) {
                final isSelected = f == selectedFilter;
                final count = filterCounts?[f];
                final label = filterLabels?[f] ?? f;

                return GestureDetector(
                  onTap: () => onFilterSelected(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? colors.accentColor : colors.subCardBg,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : colors.subCardBorder,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colors.primaryGlow.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : colors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (count != null) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : colors.subCardBorder.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
