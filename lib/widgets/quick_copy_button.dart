// lib/widgets/quick_copy_button.dart
// Interactive clipboard copy button with visual checkmark feedback and smooth micro-interaction

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modules/i18n.dart';
import '../theme/app_colors.dart';

class QuickCopyButton extends StatefulWidget {
  final String textToCopy;
  final AppColors colors;
  final String? tooltip;
  final double iconSize;

  const QuickCopyButton({
    super.key,
    required this.textToCopy,
    required this.colors,
    this.tooltip,
    this.iconSize = 14,
  });

  @override
  State<QuickCopyButton> createState() => _QuickCopyButtonState();
}

class _QuickCopyButtonState extends State<QuickCopyButton> {
  bool _isCopied = false;
  Timer? _resetTimer;
  bool _isCopying = false;
  bool _copyFailed = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    if (widget.textToCopy.isEmpty || _isCopying) return;
    _isCopying = true;
    try {
      await Clipboard.setData(ClipboardData(text: widget.textToCopy));
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCopied = false;
          _copyFailed = true;
        });
      }
      return;
    } finally {
      _isCopying = false;
    }
    if (!mounted) return;

    setState(() {
      _isCopied = true;
      _copyFailed = false;
    });

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _isCopied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final tooltipMessage = _isCopied
        ? s.copiedToClipboard
        : (_copyFailed ? s.copyFailed : (widget.tooltip ?? s.copyPath));

    return Tooltip(
      message: tooltipMessage,
      child: InkWell(
        onTap: _handleCopy,
        borderRadius: BorderRadius.circular(6),
        hoverColor: widget.colors.accentCyan.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              _isCopied
                  ? Icons.check_rounded
                  : (_copyFailed ? Icons.error_outline : Icons.copy_rounded),
              key: ValueKey<bool>(_isCopied),
              size: widget.iconSize,
              color: _isCopied
                  ? widget.colors.accentEmerald
                  : widget.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
