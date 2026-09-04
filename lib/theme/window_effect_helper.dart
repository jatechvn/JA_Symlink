// lib/theme/window_effect_helper.dart
// Manages native Windows composition backdrop effects (Acrylic, Aero, Mica, Tabbed)
// Ensures zero-alpha guards and correct DWM initialization timing.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import '../modules/app_config.dart';

class WindowEffectHelper {
  static WindowEffect parseEffect(String id, {bool isWin11 = false}) {
    switch (id.toLowerCase()) {
      case 'acrylic':
        return WindowEffect.acrylic;
      case 'aero':
        return WindowEffect.aero;
      case 'mica':
        return WindowEffect.mica;
      case 'tabbed':
        return WindowEffect.tabbed;
      case 'disabled':
        return WindowEffect.disabled;
      case 'auto':
      default:
        return isWin11 ? WindowEffect.acrylic : WindowEffect.aero;
    }
  }

  static String effectToId(WindowEffect effect) {
    switch (effect) {
      case WindowEffect.acrylic:
        return 'acrylic';
      case WindowEffect.aero:
        return 'aero';
      case WindowEffect.mica:
        return 'mica';
      case WindowEffect.tabbed:
        return 'tabbed';
      case WindowEffect.disabled:
        return 'disabled';
      default:
        return 'acrylic';
    }
  }

  static Future<void> apply({
    required WindowEffect effect,
    required bool isDark,
  }) async {
    if (!Platform.isWindows) return;
    try {
      if (effect == WindowEffect.disabled || !AppConfig.enableTransparency) {
        await Window.setEffect(effect: WindowEffect.disabled);
        return;
      }

      // Safe non-zero alpha tint to prevent Windows DWM zero-alpha solid color fallback
      final Color tintColor = isDark
          ? const Color(0x1F0A0C1C) // ~12% dark slate navy tint
          : const Color(0x1FF8FAFC); // ~12% light cool white tint

      await Window.setEffect(effect: effect, color: tintColor, dark: isDark);
    } catch (e) {
      debugPrint('WindowEffectHelper.apply error: $e');
    }
  }
}
