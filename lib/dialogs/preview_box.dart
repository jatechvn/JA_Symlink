import 'package:flutter/material.dart';
import '../theme/theme_provider.dart';

/// Shows [path] in a highlighted glass box labeled [label].
class PreviewBox extends StatelessWidget {
  final String label;
  final String path;

  const PreviewBox({super.key, required this.label, required this.path});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.accentEmerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.accentEmerald.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.preview_rounded, size: 15, color: c.accentEmerald),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.textMuted,
            ),
          ),
          Expanded(
            child: Text(
              path,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Cascadia Code',
                color: c.accentEmerald,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
