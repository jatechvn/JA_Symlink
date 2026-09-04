import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:provider/provider.dart';
import '../modules/app_config.dart';
import 'app_colors.dart';
import 'styles_win10.dart';
import 'styles_win11.dart';
import 'window_effect_helper.dart';

/// Performance Tier Mode for Graphic & Hardware Tuning.
enum PerfTierMode {
  auto('auto', 'Auto'),
  ultra('ultra', 'Ultra'),
  balanced('balanced', 'Balanced'),
  lite('lite', 'Lite');

  final String id;
  final String label;
  const PerfTierMode(this.id, this.label);

  static PerfTierMode fromId(String id) {
    switch (id) {
      case 'ultra':
        return PerfTierMode.ultra;
      case 'balanced':
        return PerfTierMode.balanced;
      case 'lite':
        return PerfTierMode.lite;
      default:
        return PerfTierMode.auto;
    }
  }
}

/// Effective Hardware Graphic Tier
enum HardwareTier {
  ultra('Ultra', '120 FPS • Max Glass', Icons.bolt_rounded, Color(0xFF0066FF)),
  balanced(
    'Balanced',
    '60 FPS • Laptop Opt',
    Icons.balance_rounded,
    Color(0xFF10B981),
  ),
  lite('Lite', 'Low Power • Zero Lag', Icons.eco_rounded, Color(0xFFF59E0B));

  final String label;
  final String desc;
  final IconData icon;
  final Color color;
  const HardwareTier(this.label, this.desc, this.icon, this.color);
}

class ThemeProvider extends ChangeNotifier {
  static const double _maxGlassBlur = 40.0;
  static const double _minCardOpacity = 0.05;
  static const double _minSurfaceOpacity = 0.1;

  String _themeMode = 'dark';
  bool _isWin11 = false;

  // Performance & Graphic Tier Profiling
  PerfTierMode _perfMode = PerfTierMode.auto;
  late HardwareTier _detectedTier;
  int _cpuCores = 4;
  int _hardwareScore = 50;

  // Glassmorphism live tuning parameters
  double _cardBlur = 20.0;
  double _cardOpacity = 0.25;
  double _dialogBlur = 20.0;
  double _dialogOpacity = 0.85;
  double _dropdownBlur = 20.0;
  double _dropdownOpacity = 0.86;

  // Native Windows backdrop blur effect
  WindowEffect _windowEffect = WindowEffect.acrylic;

  ThemeProvider({String? initialMode}) {
    if (initialMode != null && initialMode.isNotEmpty) {
      _themeMode = initialMode;
    } else {
      _themeMode = AppConfig.get('theme', defaultValue: 'dark');
    }
    final savedPerf = AppConfig.get('perf_mode', defaultValue: 'auto');
    _perfMode = PerfTierMode.fromId(savedPerf);

    _detectWindowsVersion();
    final savedEffect = AppConfig.getWindowEffect();
    _windowEffect = WindowEffectHelper.parseEffect(
      savedEffect,
      isWin11: _isWin11,
    );
    _profileHardware();
    _restoreSavedGlassmorphism();
  }

  void _detectWindowsVersion() {
    if (!Platform.isWindows) return;
    try {
      final versionStr = Platform.operatingSystemVersion;
      final match = RegExp(r'Build\s+(\d+)').firstMatch(versionStr);
      if (match != null) {
        final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
        _isWin11 = buildNumber >= 22000;
      }
    } catch (_) {}
  }

  void _profileHardware() {
    try {
      _cpuCores = Platform.numberOfProcessors;
    } catch (_) {
      _cpuCores = 4;
    }

    int score = 50;
    if (_cpuCores >= 8) {
      score += 30;
    } else if (_cpuCores >= 4) {
      score += 10;
    } else {
      score -= 25;
    }

    if (_isWin11) score += 10;

    _hardwareScore = score.clamp(10, 100);
    if (_hardwareScore < 40) {
      _detectedTier = HardwareTier.lite;
    } else if (_hardwareScore < 70) {
      _detectedTier = HardwareTier.balanced;
    } else {
      _detectedTier = HardwareTier.ultra;
    }

    _applyTierParameters(effectiveTier, notify: false);
  }

  PerfTierMode get perfMode => _perfMode;
  HardwareTier get detectedTier => _detectedTier;
  HardwareTier get effectiveTier {
    switch (_perfMode) {
      case PerfTierMode.auto:
        return _detectedTier;
      case PerfTierMode.ultra:
        return HardwareTier.ultra;
      case PerfTierMode.balanced:
        return HardwareTier.balanced;
      case PerfTierMode.lite:
        return HardwareTier.lite;
    }
  }

  String get perfLabel {
    if (_perfMode == PerfTierMode.auto) {
      return 'Auto (${effectiveTier.label})';
    }
    return _perfMode.label;
  }

  int get cpuCores => _cpuCores;
  int get hardwareScore => _hardwareScore;

  /// Cycles through: auto -> ultra -> balanced -> lite -> auto
  void cyclePerfTier() {
    switch (_perfMode) {
      case PerfTierMode.auto:
        _perfMode = PerfTierMode.ultra;
        break;
      case PerfTierMode.ultra:
        _perfMode = PerfTierMode.balanced;
        break;
      case PerfTierMode.balanced:
        _perfMode = PerfTierMode.lite;
        break;
      case PerfTierMode.lite:
        _perfMode = PerfTierMode.auto;
        break;
    }
    AppConfig.set('perf_mode', _perfMode.id);
    _applyTierParameters(effectiveTier, notify: true);
    unawaited(_persistGlassmorphism());
  }

  void setPerfTierMode(PerfTierMode mode) {
    if (_perfMode != mode) {
      _perfMode = mode;
      AppConfig.set('perf_mode', _perfMode.id);
      _applyTierParameters(effectiveTier, notify: true);
      unawaited(_persistGlassmorphism());
    }
  }

  void _applyTierParameters(HardwareTier tier, {bool notify = true}) {
    switch (tier) {
      case HardwareTier.ultra:
        _cardBlur = 20.0;
        _cardOpacity = 0.25;
        _dialogBlur = 20.0;
        _dialogOpacity = 0.85;
        _dropdownBlur = 20.0;
        _dropdownOpacity = 0.86;
        break;
      case HardwareTier.balanced:
        _cardBlur = 14.0;
        _cardOpacity = 0.35;
        _dialogBlur = 16.0;
        _dialogOpacity = 0.92;
        _dropdownBlur = 14.0;
        _dropdownOpacity = 0.96;
        break;
      case HardwareTier.lite:
        _cardBlur = 0.0;
        _cardOpacity = 0.75;
        _dialogBlur = 8.0;
        _dialogOpacity = 0.95;
        _dropdownBlur = 0.0;
        _dropdownOpacity = 0.98;
        break;
    }
    if (notify) notifyListeners();
  }

  double _readGlassValue(
    String key,
    double fallback, {
    required double min,
    required double max,
  }) {
    final parsed = double.tryParse(AppConfig.get(key));
    if (parsed == null || !parsed.isFinite) return fallback;
    return parsed.clamp(min, max).toDouble();
  }

  void _restoreSavedGlassmorphism() {
    _cardBlur = _readGlassValue(
      'card_blur',
      _cardBlur,
      min: 0,
      max: _maxGlassBlur,
    );
    _cardOpacity = _readGlassValue(
      'card_opacity',
      _cardOpacity,
      min: _minCardOpacity,
      max: 1,
    );
    _dialogBlur = _readGlassValue(
      'dialog_blur',
      _dialogBlur,
      min: 0,
      max: _maxGlassBlur,
    );
    _dialogOpacity = _readGlassValue(
      'dialog_opacity',
      _dialogOpacity,
      min: _minSurfaceOpacity,
      max: 1,
    );
    _dropdownBlur = _readGlassValue(
      'dropdown_blur',
      _dropdownBlur,
      min: 0,
      max: _maxGlassBlur,
    );
    _dropdownOpacity = _readGlassValue(
      'dropdown_opacity',
      _dropdownOpacity,
      min: _minSurfaceOpacity,
      max: 1,
    );
  }

  String get themeMode => _themeMode;

  bool get isDark {
    if (_themeMode == 'dark') return true;
    if (_themeMode == 'light') return false;
    final brightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  bool get isWin11 => _isWin11;

  double get cardBlur => _cardBlur;
  double get cardOpacity => _cardOpacity;
  double get dialogBlur => _dialogBlur;
  double get dialogOpacity => _dialogOpacity;
  double get dropdownBlur => _dropdownBlur;
  double get dropdownOpacity => _dropdownOpacity;

  AppColors get colors {
    if (isDark) {
      return _isWin11 ? win11DarkColors : win10DarkColors;
    } else {
      return _isWin11 ? win11LightColors : win10LightColors;
    }
  }

  WindowEffect get windowEffect => _windowEffect;

  /// Update native Windows backdrop blur effect (Acrylic, Aero, Mica, Tabbed, Disabled)
  void setWindowEffect(WindowEffect effect) {
    _windowEffect = effect;
    AppConfig.setWindowEffect(WindowEffectHelper.effectToId(effect));
    WindowEffectHelper.apply(effect: _windowEffect, isDark: isDark);
    notifyListeners();
  }

  /// 1-Click Direct Toggle between Light and Dark
  void toggleTheme() {
    _themeMode = isDark ? 'light' : 'dark';
    AppConfig.set('theme', _themeMode);
    WindowEffectHelper.apply(effect: _windowEffect, isDark: isDark);
    notifyListeners();
  }

  void setThemeMode(String mode) {
    _themeMode = mode;
    AppConfig.set('theme', _themeMode);
    WindowEffectHelper.apply(effect: _windowEffect, isDark: isDark);
    notifyListeners();
  }

  /// Real-time live tuning for Glassmorphism sliders
  void setLiveGlassmorphism({
    double? cardBlur,
    double? cardOpacity,
    double? dialogBlur,
    double? dialogOpacity,
    double? dropdownBlur,
    double? dropdownOpacity,
    bool persist = false,
  }) {
    if (cardBlur != null) {
      _cardBlur = _sanitizeGlassValue(cardBlur, min: 0, max: _maxGlassBlur);
    }
    if (cardOpacity != null) {
      _cardOpacity = _sanitizeGlassValue(
        cardOpacity,
        min: _minCardOpacity,
        max: 1,
      );
    }
    if (dialogBlur != null) {
      _dialogBlur = _sanitizeGlassValue(dialogBlur, min: 0, max: _maxGlassBlur);
    }
    if (dialogOpacity != null) {
      _dialogOpacity = _sanitizeGlassValue(
        dialogOpacity,
        min: _minSurfaceOpacity,
        max: 1,
      );
    }
    if (dropdownBlur != null) {
      _dropdownBlur = _sanitizeGlassValue(
        dropdownBlur,
        min: 0,
        max: _maxGlassBlur,
      );
    }
    if (dropdownOpacity != null) {
      _dropdownOpacity = _sanitizeGlassValue(
        dropdownOpacity,
        min: _minSurfaceOpacity,
        max: 1,
      );
    }
    if (persist) unawaited(_persistGlassmorphism());
    notifyListeners();
  }

  double _sanitizeGlassValue(
    double value, {
    required double min,
    required double max,
  }) {
    if (!value.isFinite) return min;
    return value.clamp(min, max).toDouble();
  }

  Future<void> _persistGlassmorphism() async {
    await AppConfig.set('card_blur', _cardBlur.toString());
    await AppConfig.set('card_opacity', _cardOpacity.toString());
    await AppConfig.set('dialog_blur', _dialogBlur.toString());
    await AppConfig.set('dialog_opacity', _dialogOpacity.toString());
    await AppConfig.set('dropdown_blur', _dropdownBlur.toString());
    await AppConfig.set('dropdown_opacity', _dropdownOpacity.toString());
  }

  void setCardBlur(double blur) {
    _cardBlur = _sanitizeGlassValue(blur, min: 0, max: _maxGlassBlur);
    notifyListeners();
  }

  void setCardOpacity(double opacity) {
    _cardOpacity = _sanitizeGlassValue(opacity, min: _minCardOpacity, max: 1);
    notifyListeners();
  }

  void setDialogBlur(double blur) {
    _dialogBlur = _sanitizeGlassValue(blur, min: 0, max: _maxGlassBlur);
    notifyListeners();
  }

  void setDialogOpacity(double opacity) {
    _dialogOpacity = _sanitizeGlassValue(
      opacity,
      min: _minSurfaceOpacity,
      max: 1,
    );
    notifyListeners();
  }

  void setDropdownBlur(double blur) {
    _dropdownBlur = _sanitizeGlassValue(blur, min: 0, max: _maxGlassBlur);
    notifyListeners();
  }

  void setDropdownOpacity(double opacity) {
    _dropdownOpacity = _sanitizeGlassValue(
      opacity,
      min: _minSurfaceOpacity,
      max: 1,
    );
    notifyListeners();
  }

  void resetToDefaults() {
    _perfMode = PerfTierMode.auto;
    AppConfig.set('perf_mode', 'auto');
    _cardBlur = 20.0;
    _cardOpacity = 0.25;
    _dialogBlur = 20.0;
    _dialogOpacity = 0.85;
    _dropdownBlur = 20.0;
    _dropdownOpacity = 0.86;
    _profileHardware();
    unawaited(_persistGlassmorphism());
    notifyListeners();
  }
}

extension ThemeExtension on BuildContext {
  AppColors get appColors => watch<ThemeProvider>().colors;
}
