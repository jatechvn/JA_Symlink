// lib/modules/snapshot/snapshot_service.dart
// Windows Reinstall Survival Kit: generates standalone recovery scripts (.bat / .ps1)
// and handles snapshot backups for seamless restore after fresh OS installs.

import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import '../logic.dart';
import '../symlink_service.dart';
import '../utils.dart';

final _logger = Logger('SnapshotService');

class SnapshotRestoreResult {
  final int total;
  final int restored;
  final int skipped;
  final int failed;
  final List<String> errors;

  const SnapshotRestoreResult({
    required this.total,
    required this.restored,
    required this.skipped,
    required this.failed,
    required this.errors,
  });
}

class SnapshotService {
  // Disconnected drives must not disappear from recovery backups.
  static bool _isRecoverable(SymlinkEntry entry) =>
      entry.isActive || entry.status == 'DANGLING';

  static String _batchPath(String path) {
    if (path.isEmpty || RegExp(r'[\x00-\x1f\x7f"<>|]').hasMatch(path)) {
      throw const FormatException('Unsafe path in batch snapshot');
    }
    return path.replaceAll('%', '%%');
  }

  /// Generate standalone Windows Batch script (.bat) that can be run with
  /// Administrator privileges to recreate all active symlinks after a fresh Windows install.
  static String generateBatchScript(List<SymlinkEntry> entries) {
    final activeEntries = entries.where(_isRecoverable).toList();
    final buffer = StringBuffer();

    buffer.writeln('@echo off');
    buffer.writeln('setlocal DisableDelayedExpansion');
    buffer.writeln('chcp 65001 >nul');
    buffer.writeln(':: ===================================================');
    buffer.writeln(':: JA Symlink Manager - Standalone Windows Restore Kit');
    buffer.writeln(':: Generated at: ${formatTimestampDisplay()}');
    buffer.writeln(':: Total Symlinks: ${activeEntries.length}');
    buffer.writeln(':: ===================================================');
    buffer.writeln('');
    buffer.writeln(':: Check for Administrative privileges');
    buffer.writeln('net session >nul 2>&1');
    buffer.writeln('if %errorlevel% neq 0 (');
    buffer.writeln(
      '    echo [!] Vui lòng bấm chuột phải vào file này và chọn "Run as administrator"!',
    );
    buffer.writeln('    pause');
    buffer.writeln('    exit /b 1');
    buffer.writeln(')');
    buffer.writeln('');
    buffer.writeln(
      'echo [i] Đang tiến hành khôi phục ${activeEntries.length} Symbolic Links...',
    );
    buffer.writeln('echo.');

    for (int i = 0; i < activeEntries.length; i++) {
      final entry = activeEntries[i];
      final link = _batchPath(entry.linkPath);
      final target = _batchPath(entry.targetPath);

      buffer.writeln(':: [${i + 1}/${activeEntries.length}] Restore link');
      buffer.writeln('if not exist "$target" (');
      buffer.writeln(
        '    echo [!] Ổ đĩa/Thư mục đích không tồn tại: "$target"',
      );
      buffer.writeln('    echo     Bỏ qua symlink này...');
      buffer.writeln(') else (');
      buffer.writeln('    if exist "$link" (');
      buffer.writeln('        echo [~] Đã tồn tại thư mục/symlink: "$link"');
      buffer.writeln('    ) else (');
      buffer.writeln('        mklink /D "$link" "$target"');
      buffer.writeln('    )');
      buffer.writeln(')');
      buffer.writeln('echo.');
    }

    buffer.writeln('echo [OK] Hoàn tất quá trình khôi phục!');
    buffer.writeln('pause');

    return buffer.toString();
  }

  /// Generate standalone PowerShell script (.ps1)
  static String generatePowerShellScript(List<SymlinkEntry> entries) {
    final activeEntries = entries.where(_isRecoverable).toList();
    final buffer = StringBuffer();

    buffer.writeln('#Requires -RunAsAdministrator');
    buffer.writeln('# ===================================================');
    buffer.writeln('# JA Symlink Manager - Standalone PowerShell Restore Kit');
    buffer.writeln('# Generated at: ${formatTimestampDisplay()}');
    buffer.writeln('# ===================================================');
    buffer.writeln('[Console]::OutputEncoding = [System.Text.Encoding]::UTF8');
    buffer.writeln(
      'Write-Host "[i] Đang khôi phục ${activeEntries.length} Symbolic Links..." -ForegroundColor Cyan',
    );
    buffer.writeln('');

    for (final entry in activeEntries) {
      final link = entry.linkPath.replaceAll("'", "''");
      final target = entry.targetPath.replaceAll("'", "''");

      buffer.writeln("if (Test-Path -LiteralPath '$target') {");
      buffer.writeln("    if (-not (Test-Path -LiteralPath '$link')) {");
      buffer.writeln(
        "        New-Item -ItemType SymbolicLink -Path '$link' -Target '$target' | Out-Null",
      );
      buffer.writeln(
        "        Write-Host '[+] Đã tạo: $link -> $target' -ForegroundColor Green",
      );
      buffer.writeln('    } else {');
      buffer.writeln(
        "        Write-Host '[~] Đã tồn tại: $link' -ForegroundColor Yellow",
      );
      buffer.writeln('    }');
      buffer.writeln('} else {');
      buffer.writeln(
        "    Write-Host '[!] Không tìm thấy đích: $target' -ForegroundColor Red",
      );
      buffer.writeln('}');
    }

    buffer.writeln('');
    buffer.writeln(
      'Write-Host "[OK] Hoàn tất khôi phục!" -ForegroundColor Green',
    );
    buffer.writeln('Read-Host "Nhấn Enter để thoát..."');

    return buffer.toString();
  }

  /// Export JSON snapshot with rich metadata
  static Future<void> exportSnapshotFile({
    required List<SymlinkEntry> entries,
    required String filePath,
  }) async {
    final active = entries.where(_isRecoverable).toList();
    final data = {
      'schemaVersion': 2,
      'exportedAt': formatTimestamp(),
      'machineName': Platform.localHostname,
      'osVersion': Platform.operatingSystemVersion,
      'totalCount': active.length,
      'entries': active.map((e) => e.toJson()).toList(),
    };

    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    _logger.info(
      'Exported snapshot to $filePath with ${active.length} entries',
    );
  }

  /// Import snapshot and recreate symlinks using SymlinkLogic
  static Future<SnapshotRestoreResult> restoreFromSnapshot({
    required String filePath,
    required SymlinkLogic logic,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return const SnapshotRestoreResult(
        total: 0,
        restored: 0,
        skipped: 0,
        failed: 1,
        errors: ['Tệp snapshot không tồn tại'],
      );
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final rawEntries = (json['entries'] as List<dynamic>? ?? []);

      int restored = 0;
      int skipped = 0;
      int failed = 0;
      final errors = <String>[];

      for (final raw in rawEntries) {
        final entry = SymlinkEntry.fromJson(raw as Map<String, dynamic>);
        final link = entry.linkPath;
        final target = entry.targetPath;

        // Check if target directory exists on disk
        if (!Directory(target).existsSync()) {
          failed++;
          errors.add('Thư mục đích không tồn tại: $target');
          continue;
        }

        // Check if link already exists
        if (Directory(link).existsSync() || Link(link).existsSync()) {
          skipped++;
          continue;
        }

        // Create symlink without moving data (data already exists in target)
        final result = await logic.createSymlink(
          sourcePath: link,
          targetPath: target,
          moveData: false,
          killProcesses: false,
        );

        if (result.success) {
          restored++;
        } else {
          failed++;
          errors.add('${result.message} ($link)');
        }
      }

      return SnapshotRestoreResult(
        total: rawEntries.length,
        restored: restored,
        skipped: skipped,
        failed: failed,
        errors: errors,
      );
    } catch (e) {
      return SnapshotRestoreResult(
        total: 0,
        restored: 0,
        skipped: 0,
        failed: 1,
        errors: ['Lỗi đọc snapshot: $e'],
      );
    }
  }
}
