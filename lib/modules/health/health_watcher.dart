// lib/modules/health/health_watcher.dart
// Real-time health monitoring and auto-reconnection for removable drives and broken symlinks.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import '../native/win_core.dart';
import '../symlink_service.dart';

final _logger = Logger('HealthWatcher');

class HealthWatcher extends ChangeNotifier {
  final SymlinkService _service;
  Timer? _timer;
  bool _isChecking = false;
  int _brokenCount = 0;
  DateTime? _lastCheckTime;

  HealthWatcher(this._service);

  int get brokenCount => _brokenCount;
  DateTime? get lastCheckTime => _lastCheckTime;
  bool get hasIssues => _brokenCount > 0;

  /// Start periodic health monitoring
  void startMonitoring({Duration interval = const Duration(seconds: 15)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => checkHealth());
    // Run an immediate initial check
    checkHealth();
  }

  /// Stop monitoring
  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  /// Run health check immediately
  Future<void> checkHealth() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final entries = await _service.readAllEntries();
      int broken = 0;
      bool stateChanged = false;

      for (final entry in entries) {
        if (!entry.isActive && entry.status != 'DANGLING') continue;

        final targetExists = Directory(entry.targetPath).existsSync();
        final linkExists = Link(entry.linkPath).existsSync();

        if (!targetExists || !linkExists) {
          broken++;
          if (entry.status != 'DANGLING') {
            _logger.warning(
              'Symlink target missing: ${entry.linkPath} -> ${entry.targetPath}',
            );
            await _service.updateHealthStatus(entry, 'DANGLING');
            stateChanged = true;
          }
        } else if (entry.status == 'DANGLING') {
          // Auto-reconnect: target has reappeared (e.g. removable drive re-inserted)
          final isValid = await WindowsNativeEngine.verifySymlink(
            entry.linkPath,
          );
          if (isValid) {
            _logger.info(
              'Auto-reconnected symlink: ${entry.linkPath} -> ${entry.targetPath}',
            );
            await _service.updateHealthStatus(entry, 'ACTIVE');
            stateChanged = true;
          } else {
            broken++;
          }
        }
      }

      _brokenCount = broken;
      _lastCheckTime = DateTime.now();

      if (stateChanged) {
        notifyListeners();
      }
    } catch (e) {
      _logger.warning('HealthWatcher check error: $e');
    } finally {
      _isChecking = false;
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
