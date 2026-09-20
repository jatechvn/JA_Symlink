// lib/widgets/empty_state_card.dart
// Frosted Glass Bento Card for empty states with glowing icon and call-to-action button

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glass_widgets.dart';

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? buttonLabel;
  final VoidCallback? onAction;
  final AppColors colors;
  final Color? accentColor;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.colors,
    this.buttonLabel,
    this.onAction,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? colors.accentCyan;

    return BentoCard(
      colors: colors,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EmptyStateIconBox(
              icon: icon,
              accentColor: effectiveAccent,
              colors: colors,
            ),
            const SizedBox(height: 16),
            _EmptyStateTexts(
              title: title,
              description: description,
              colors: colors,
            ),
            if (buttonLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              _EmptyStateAction(
                label: buttonLabel!,
                onAction: onAction!,
                colors: colors,
                accentColor: effectiveAccent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyStateIconBox extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final AppColors colors;

  const _EmptyStateIconBox({
    required this.icon,
    required this.accentColor,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.30),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(child: Icon(icon, size: 26, color: accentColor)),
    );
  }
}

class _EmptyStateTexts extends StatelessWidget {
  final String title;
  final String description;
  final AppColors colors;

  const _EmptyStateTexts({
    required this.title,
    required this.description,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _EmptyStateAction extends StatelessWidget {
  final String label;
  final VoidCallback onAction;
  final AppColors colors;
  final Color accentColor;

  const _EmptyStateAction({
    required this.label,
    required this.onAction,
    required this.colors,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlowingActionButton(
      height: 38,
      colors: colors,
      customStartColor: accentColor,
      customEndColor: colors.accentCyan,
      icon: Icons.add_rounded,
      label: label,
      onPressed: onAction,
    );
  }
}
