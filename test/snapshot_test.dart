import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/constants.dart';
import 'package:ja_symlink/modules/snapshot/snapshot_service.dart';
import 'package:ja_symlink/modules/symlink_service.dart';

void main() {
  final testEntries = [
    SymlinkEntry(
      timestamp: '2026-09-20 12:00:00',
      linkPath: r'C:\Users\V\.ollama\models',
      targetPath: r'D:\AI_Cache\ollama_models',
      backupPath: csvEmptyPlaceholder,
      status: statusActive,
    ),
    SymlinkEntry(
      timestamp: '2026-09-20 12:00:00',
      linkPath: r'C:\Users\V\.gradle\caches',
      targetPath: r'D:\Dev_Cache\gradle',
      backupPath: csvEmptyPlaceholder,
      status: statusActive,
    ),
    SymlinkEntry(
      timestamp: '2026-09-20 12:00:00',
      linkPath: r'C:\Users\V\.inactive\test',
      targetPath: r'D:\Test\inactive',
      backupPath: csvEmptyPlaceholder,
      status: 'REMOVED',
    ),
  ];

  test(
    'disconnected links survive JSON and both recovery script exports',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ja_dangling_snapshot_',
      );
      addTearDown(() => root.delete(recursive: true));
      final dangling = SymlinkEntry(
        timestamp: 'offline',
        linkPath: r'C:\offline',
        targetPath: r'Z:\offline',
        backupPath: csvEmptyPlaceholder,
        status: 'DANGLING',
      );
      final entries = [...testEntries, dangling];
      final path = '${root.path}/snapshot.json';
      await SnapshotService.exportSnapshotFile(
        entries: entries,
        filePath: path,
      );
      final json =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      expect(json['totalCount'], 3);
      final saved = (json['entries'] as List).cast<Map<String, dynamic>>();
      expect(saved.last, dangling.toJson());
      expect(saved.any((e) => e['status'] == 'REMOVED'), isFalse);
      for (final script in [
        SnapshotService.generateBatchScript(entries),
        SnapshotService.generatePowerShellScript(entries),
      ]) {
        expect(script, contains(dangling.linkPath));
        expect(script, contains(dangling.targetPath));
        expect(script, isNot(contains(testEntries.last.linkPath)));
      }
    },
  );

  group('SnapshotService Script Generation', () {
    test('generateBatchScript includes admin check and mklink /D commands', () {
      final script = SnapshotService.generateBatchScript(testEntries);

      expect(script, contains('@echo off'));
      expect(script, contains('chcp 65001'));
      expect(script, contains('net session >nul 2>&1'));
      expect(
        script,
        contains(
          r'mklink /D "C:\Users\V\.ollama\models" "D:\AI_Cache\ollama_models"',
        ),
      );
      expect(
        script,
        contains(
          r'mklink /D "C:\Users\V\.gradle\caches" "D:\Dev_Cache\gradle"',
        ),
      );
      // Inactive entry should NOT be in the restore script
      expect(script, isNot(contains(r'C:\Users\V\.inactive\test')));
    });

    test(
      'generatePowerShellScript includes admin requirement and New-Item commands',
      () {
        final script = SnapshotService.generatePowerShellScript(testEntries);

        expect(script, contains('#Requires -RunAsAdministrator'));
        expect(
          script,
          contains('[Console]::OutputEncoding = [System.Text.Encoding]::UTF8'),
        );
        expect(
          script,
          contains(
            r"New-Item -ItemType SymbolicLink -Path 'C:\Users\V\.ollama\models' -Target 'D:\AI_Cache\ollama_models'",
          ),
        );
        expect(
          script,
          contains(
            r"New-Item -ItemType SymbolicLink -Path 'C:\Users\V\.gradle\caches' -Target 'D:\Dev_Cache\gradle'",
          ),
        );
        expect(script, isNot(contains(r'C:\Users\V\.inactive\test')));
      },
    );
  });

  group('SnapshotService File Export', () {
    test(
      'exportSnapshotFile exports schema with active entries only',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ja_snapshot_test_',
        );
        final exportPath =
            '${tempDir.path}${Platform.pathSeparator}test_snapshot.json';
        addTearDown(() => tempDir.delete(recursive: true));

        await SnapshotService.exportSnapshotFile(
          entries: testEntries,
          filePath: exportPath,
        );

        final file = File(exportPath);
        expect(file.existsSync(), isTrue);

        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(json['schemaVersion'], equals(2));
        expect(json['totalCount'], equals(2));
        final entries = json['entries'] as List<dynamic>;
        expect(entries.length, equals(2));
        expect(entries[0]['linkPath'], equals(r'C:\Users\V\.ollama\models'));
        expect(entries[1]['linkPath'], equals(r'C:\Users\V\.gradle\caches'));
      },
    );
  });
}
