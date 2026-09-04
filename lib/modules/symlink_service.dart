// lib/modules/symlink_service.dart
// Manages JSON history and log operations for symlinks

import 'dart:io';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'constants.dart';
import 'utils.dart';
import 'native/win_core.dart';

final _logger = Logger('SymlinkService');

/// Represents a single symlink entry
class SymlinkEntry {
  final String timestamp;
  final String linkPath;
  final String targetPath;
  final String backupPath;
  String status;

  SymlinkEntry({
    required this.timestamp,
    required this.linkPath,
    required this.targetPath,
    required this.backupPath,
    required this.status,
  });

  /// Parse from JSON Map
  factory SymlinkEntry.fromJson(Map<String, dynamic> json) {
    return SymlinkEntry(
      timestamp: json['timestamp'] as String? ?? '',
      linkPath: json['linkPath'] as String? ?? '',
      targetPath: json['targetPath'] as String? ?? '',
      backupPath: json['backupPath'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  /// Convert to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'linkPath': linkPath,
      'targetPath': targetPath,
      'backupPath': backupPath,
      'status': status,
    };
  }

  /// Parse from CSV line (pipe-delimited) - kept for backward migration
  factory SymlinkEntry.fromCsvLine(String line) {
    final parts = line.split(csvDelimiter);
    if (parts.length < 5) {
      throw FormatException('Invalid CSV line: $line');
    }
    return SymlinkEntry(
      timestamp: parts[0].trim(),
      linkPath: parts[1].trim(),
      targetPath: parts[2].trim(),
      backupPath: parts[3].trim(),
      status: parts[4].trim(),
    );
  }

  bool get isActive => status == statusActive;
  bool get hasBackup =>
      backupPath != csvEmptyPlaceholder && backupPath.isNotEmpty;

  @override
  String toString() =>
      'SymlinkEntry(link=$linkPath, target=$targetPath, status=$status)';
}

/// Service for managing symlink history JSON and log files
class SymlinkService {
  late String _csvPath;
  late String _jsonPath;
  late String _logPath;

  SymlinkService() {
    final dataDir = p.join(Directory.current.path, 'assets', 'data');
    _csvPath = p.join(dataDir, defaultHistoryFile);
    _jsonPath = p.join(dataDir, 'symlink_history.json');
    _logPath = p.join(dataDir, defaultLogFile);
  }

  /// Initialize data directory and files, performs migration if CSV exists
  Future<void> initialize() async {
    final dataDir = Directory(p.dirname(_jsonPath));
    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }

    final jsonFile = File(_jsonPath);
    final csvFile = File(_csvPath);

    // Auto-migration from CSV to JSON
    if (!jsonFile.existsSync()) {
      final migratedEntries = <SymlinkEntry>[];
      if (csvFile.existsSync()) {
        _logger.info('CSV history file found. Migrating to JSON...');
        try {
          final lines = csvFile.readAsLinesSync();
          for (int i = 1; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isEmpty) continue;
            try {
              migratedEntries.add(SymlinkEntry.fromCsvLine(line));
            } catch (e) {
              _logger.warning('Migration: skipping invalid CSV line $i: $e');
            }
          }
          _logger.info(
            'Migrated ${migratedEntries.length} entries from CSV to JSON.',
          );
        } catch (e) {
          _logger.severe('Failed to read CSV for migration: $e');
        }
      }

      // Write initial JSON array (with migrated entries if any, otherwise empty)
      final jsonStr = const JsonEncoder.withIndent(
        '  ',
      ).convert(migratedEntries.map((e) => e.toJson()).toList());
      jsonFile.writeAsStringSync(jsonStr);

      // If migration succeeded, rename the CSV file to .bak to be safe
      if (csvFile.existsSync() && migratedEntries.isNotEmpty) {
        try {
          csvFile.renameSync('$_csvPath.bak');
          _logger.info('Renamed old CSV history to $_csvPath.bak');
        } catch (e) {
          _logger.warning('Failed to rename old CSV file: $e');
        }
      }
    }
  }

  /// Read all entries from JSON
  Future<List<SymlinkEntry>> readAllEntries() async {
    final jsonFile = File(_jsonPath);
    if (!jsonFile.existsSync()) {
      return [];
    }

    try {
      final jsonStr = jsonFile.readAsStringSync();
      if (jsonStr.trim().isEmpty) return [];
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) {
        throw const FormatException('History JSON must contain an array');
      }

      final entries = <SymlinkEntry>[];
      for (var index = 0; index < decoded.length; index++) {
        final item = decoded[index];
        if (item is! Map) {
          _logger.warning('Skipping invalid history item at index $index');
          continue;
        }
        try {
          entries.add(SymlinkEntry.fromJson(Map<String, dynamic>.from(item)));
        } catch (itemError) {
          _logger.warning(
            'Skipping invalid history item at index $index: $itemError',
          );
        }
      }
      return entries;
    } catch (e) {
      _logger.severe('Failed to read JSON history: $e');
      // Do not turn a corrupt/unreadable history into an empty list: callers
      // might otherwise overwrite the user's remaining history on the next
      // save. Let the operation surface the persistence problem instead.
      rethrow;
    }
  }

  /// Get only ACTIVE symlinks
  Future<List<SymlinkEntry>> getActiveEntries() async {
    final all = await readAllEntries();
    return all.where((e) => e.isActive).toList();
  }

  /// Add a new entry to JSON
  Future<void> addEntry(SymlinkEntry entry) async {
    final entries = await readAllEntries();
    entries.add(entry);
    await _saveJson(entries);
    _logger.info('Added JSON entry: $entry');
  }

  /// Save the entire entries list to JSON file
  Future<void> _saveJson(List<SymlinkEntry> entries) async {
    try {
      final jsonFile = File(_jsonPath);
      final jsonStr = const JsonEncoder.withIndent(
        '  ',
      ).convert(entries.map((e) => e.toJson()).toList());
      jsonFile.writeAsStringSync(jsonStr);
    } catch (e) {
      _logger.severe('Failed to save JSON history: $e');
      rethrow;
    }
  }

  /// Update entry status (e.g., ACTIVE -> REMOVED)
  Future<void> updateEntryStatus(
    String linkPath,
    String oldStatus,
    String newStatus,
  ) async {
    final entries = await readAllEntries();
    bool updated = false;
    for (final entry in entries) {
      if (entry.linkPath.toLowerCase() == linkPath.toLowerCase() &&
          entry.status == oldStatus) {
        entry.status = newStatus;
        updated = true;
        _logger.info(
          'Updated status in JSON: $linkPath from $oldStatus to $newStatus',
        );
      }
    }
    if (updated) {
      await _saveJson(entries);
    }
  }

  /// Fix an entry's target path (when JSON doesn't match actual symlink target)
  Future<void> fixEntryTarget(String linkPath, String newTargetPath) async {
    final entries = await readAllEntries();
    bool updated = false;
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.linkPath.toLowerCase() == linkPath.toLowerCase() &&
          entry.status == statusActive) {
        entries[i] = SymlinkEntry(
          timestamp: entry.timestamp,
          linkPath: entry.linkPath,
          targetPath: newTargetPath,
          backupPath: entry.backupPath,
          status: entry.status,
        );
        updated = true;
        _logger.info('Fixed target in JSON: $linkPath -> $newTargetPath');
      }
    }
    if (updated) {
      await _saveJson(entries);
    }
  }

  /// Write to human-readable log file
  Future<void> writeLog(
    String operation,
    String linkPath,
    String targetPath, {
    String? details,
  }) async {
    final logFile = File(_logPath);
    final timestamp = formatTimestampDisplay();
    final logEntry = StringBuffer();
    logEntry.writeln('[$timestamp] $operation');
    logEntry.writeln('  Link:   $linkPath');
    logEntry.writeln('  Target: $targetPath');
    if (details != null) {
      logEntry.writeln('  Detail: $details');
    }
    logEntry.writeln('---');

    logFile.writeAsStringSync(logEntry.toString(), mode: FileMode.append);
  }

  /// Scan system for existing symlinks in common directories
  Future<List<Map<String, String>>> scanSystemSymlinks() async {
    final results = <Map<String, String>>[];

    // Scan common directories recursively using WindowsNativeEngine.scanSymlinks
    final scanPaths = [
      p.join(Platform.environment['USERPROFILE'] ?? '', 'AppData', 'Local'),
      p.join(Platform.environment['USERPROFILE'] ?? '', 'AppData', 'Roaming'),
      Platform.environment['ProgramFiles'] ?? r'C:\Program Files',
      Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)',
      Platform.environment['ProgramData'] ?? r'C:\ProgramData',
    ];

    final seenLinks = <String>{};
    const systemJunctions = {
      'application data',
      'history',
      'temporary internet files',
      'content.ie5',
      'local settings',
      'templates',
      'cookies',
      'nethood',
      'printhood',
      'recent',
      'sendto',
      'start menu',
      'my documents',
      'desktop',
      'documents',
    };

    for (final scanPath in scanPaths) {
      final dir = Directory(scanPath);
      if (!dir.existsSync()) continue;

      try {
        _logger.info('Scanning directory recursively: $scanPath');
        final pathResults = await WindowsNativeEngine.scanSymlinks(scanPath);
        for (final item in pathResults) {
          final link = item['link'];
          final target = item['target'];
          if (link != null && target != null) {
            final normalizedLink = normalizePath(link);
            final linkName = p.basename(normalizedLink).toLowerCase();
            if (systemJunctions.contains(linkName)) {
              continue;
            }

            final key = normalizedLink.toLowerCase();
            if (!seenLinks.contains(key)) {
              seenLinks.add(key);
              results.add({
                'link': normalizedLink,
                'target': normalizePath(target),
              });
            }
          }
        }
      } catch (e) {
        _logger.warning('Cannot scan $scanPath: $e');
      }
    }

    return results;
  }

  String get csvPath => _csvPath;
  String get logPath => _logPath;
}
