// lib/modules/native_bridge.dart
// Dynamic routing bridge connecting Business Logic and native Core

import 'dart:io' show Platform;
import 'package:logging/logging.dart';
import 'native/win_core.dart';

final _logger = Logger('NativeBridge');

abstract class NativeEngine {
  dynamic heavyCompute(dynamic dataInput);
}

class NativeBridge {
  final String osName;
  NativeEngine? engine;

  NativeBridge() : osName = Platform.operatingSystem {
    _initializeEngine();
  }

  /// Dynamically initializes OS-specific optimized engine
  void _initializeEngine() {
    try {
      if (Platform.isWindows) {
        engine = WindowsNativeEngine();
      } else {
        _logger.warning(
          '[BRIDGE] OS $osName is not supported. Using fallback.',
        );
      }
    } catch (e) {
      _logger.severe('[BRIDGE] Failed to initialize engine for $osName: $e');
    }
  }

  /// Executes low-level native calls if available
  dynamic executeHeavyTask(dynamic dataInput) {
    if (engine != null) {
      return engine!.heavyCompute(dataInput);
    }
    return _pureDartFallback(dataInput);
  }

  /// Standard Dart fallback logic
  dynamic _pureDartFallback(dynamic dataInput) {
    _logger.info('[BRIDGE] Processing using pure Dart algorithm.');
    return dataInput;
  }
}

// Singleton instance
final nativeAgent = NativeBridge();
