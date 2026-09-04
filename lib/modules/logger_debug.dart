// lib/modules/logger_debug.dart
// Verbose logging strategy (Level.ALL), 7-day retention.

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

IOSink? _debugLogSink;

void setupDebugLogger() {
  Logger.root.level = Level.ALL;

  final logDir = Directory(p.join(Directory.current.path, 'logs'));
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }

  final now = DateTime.now();
  final logFileName =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.log';
  _debugLogSink = File(
    p.join(logDir.path, logFileName),
  ).openWrite(mode: FileMode.append);

  Logger.root.onRecord.listen((record) {
    final buffer = StringBuffer()
      ..write(
        '[${record.time}] ${record.level.name}: ${record.loggerName} - ${record.message}',
      );
    if (record.error != null) buffer.write('\n  ERROR: ${record.error}');
    if (record.stackTrace != null) {
      buffer.write('\n  STACKTRACE: ${record.stackTrace}');
    }
    final logText = buffer.toString();
    // ignore: avoid_print
    print(logText);
    _debugLogSink?.writeln(logText);
  });

  rotateDebugLogs(logDir);
}

/// Deletes debug log files older than 7 days.
void rotateDebugLogs(Directory logDir) {
  try {
    final limit = DateTime.now().subtract(const Duration(days: 7));
    for (final entity in logDir.listSync()) {
      if (entity is File &&
          entity.path.endsWith('.log') &&
          entity.statSync().modified.isBefore(limit)) {
        entity.deleteSync();
      }
    }
  } catch (_) {}
}

void disposeDebugLogger() {
  _debugLogSink?.close();
}
