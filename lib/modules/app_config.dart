// lib/modules/app_config.dart
// Simple INI-style config file reader/writer
// Stores config.ini next to the executable in release, or in the workspace root in debug

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Static config manager — call initialize() once at startup
class AppConfig {
  static String? _configPath;
  static Map<String, String> _values = {};
  static bool enableTransparency = true;

  /// Initialize and load config from disk.
  /// Creates config.ini with defaults if it doesn't exist.
  static Future<void> initialize() async {
    try {
      if (kDebugMode) {
        // During development/debugging, place in the current working directory (project root)
        _configPath = p.join(Directory.current.path, 'config.ini');
      } else {
        // In release mode, place config.ini next to the running executable
        final exeDir = p.dirname(Platform.resolvedExecutable);
        _configPath = p.join(exeDir, 'config.ini');
      }
      await _load();
    } catch (_) {
      _configPath = 'config.ini';
      await _load();
    }

    // Default transparency is true (Win11 uses Acrylic, Win10 uses GPU-accelerated 0ms Aero)
    final transparencyStr = get('enable_transparency', defaultValue: 'true');
    enableTransparency = transparencyStr == 'true';
    if (_values['enable_transparency'] == null) {
      await set('enable_transparency', transparencyStr);
    }

    // Window backdrop effect: 'acrylic' (Win11 frosted glass), 'aero' (Win10 GPU lag-free), 'mica', 'tabbed', 'disabled'
    final defaultEffect = _isWindows11OrNewer() ? 'acrylic' : 'aero';
    final effectStr = get('window_effect', defaultValue: defaultEffect);
    if (_values['window_effect'] == null) {
      await set('window_effect', effectStr);
    }
  }

  static String getWindowEffect() {
    final defaultEffect = _isWindows11OrNewer() ? 'acrylic' : 'aero';
    return get('window_effect', defaultValue: defaultEffect);
  }

  static Future<void> setWindowEffect(String effect) async {
    await set('window_effect', effect);
  }

  static bool _isWindows11OrNewer() {
    if (!Platform.isWindows) return false;
    try {
      final versionStr = Platform.operatingSystemVersion;
      final match = RegExp(r'Build\s+(\d+)').firstMatch(versionStr);
      if (match != null) {
        final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
        return buildNumber >= 22000;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> _load() async {
    try {
      final file = File(_configPath!);
      if (!file.existsSync()) {
        _values = {'language': 'en'};
        await _save();
        return;
      }

      _values = {};
      final lines = file.readAsLinesSync();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty ||
            trimmed.startsWith('#') ||
            trimmed.startsWith('[')) {
          continue;
        }
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx > 0) {
          final key = trimmed.substring(0, eqIdx).trim();
          final value = trimmed.substring(eqIdx + 1).trim();
          _values[key] = value;
        }
      }
    } catch (_) {
      // Fallback defaults on read error
      _values = {'language': 'en'};
    }
  }

  static Future<void> _save() async {
    try {
      if (_configPath == null) return;
      final file = File(_configPath!);
      final parent = file.parent;
      if (!parent.existsSync()) {
        parent.createSync(recursive: true);
      }
      final buffer = StringBuffer();
      buffer.writeln('[app]');
      _values.forEach((k, v) => buffer.writeln('$k=$v'));
      file.writeAsStringSync(buffer.toString());
    } catch (_) {
      // Fallback
    }
  }

  /// Get a config value by key, with optional default.
  static String get(String key, {String defaultValue = ''}) {
    return _values[key] ?? defaultValue;
  }

  /// Set a config value and immediately persist to disk.
  static Future<void> set(String key, String value) async {
    _values[key] = value;
    await _save();
  }

  /// Get path to transaction log file pending_operation.json
  static String getPendingOpPath() {
    if (_configPath != null) {
      return p.join(p.dirname(_configPath!), 'pending_operation.json');
    }
    return 'pending_operation.json';
  }
}
