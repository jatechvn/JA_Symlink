import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/logic.dart';
import 'package:ja_symlink/modules/relocator/relocator_model.dart';
import 'package:ja_symlink/modules/relocator/relocator_operation.dart';
import 'package:ja_symlink/modules/relocator/relocator_service.dart';
import 'package:ja_symlink/modules/snapshot/snapshot_service.dart';
import 'package:ja_symlink/modules/symlink_service.dart';

class FakeSpace extends RelocatorService {
  int? free;
  int queries = 0;
  bool fail = false;
  @override
  Future<int?> getTargetFreeBytes(String targetPath) async {
    queries++;
    if (fail) throw const FileSystemException('query failed');
    return free;
  }
}

class FakeRelocation extends SymlinkLogic {
  FakeRelocation() : super(SymlinkService());
  final FakeSpace _space = FakeSpace();
  @override
  FakeSpace get relocatorService => _space;
  int calls = 0;
  bool? killed;
  @override
  Future<OperationResult> createSymlink({
    required String sourcePath,
    required String targetPath,
    bool killProcesses = true,
    bool moveData = true,
    void Function(double, String, String)? onProgress,
  }) async {
    calls++;
    killed = killProcesses;
    return OperationResult(success: true, message: 'ok');
  }
}

SymlinkEntry entry(
  String link, {
  String target = r'D:\data',
  String status = 'ACTIVE',
}) => SymlinkEntry(
  timestamp: link,
  linkPath: link,
  targetPath: target,
  backupPath: '-',
  status: status,
);

void main() {
  test(
    'generated BAT preserves literal paths in CMD with delayed expansion on',
    () async {
      final root = await Directory.systemTemp.createTemp('ja_batch_escaping_');
      addTearDown(() => root.delete(recursive: true));
      final target = Directory('${root.path}\\%JA_ESCAPE_TEST%!x&(y)^');
      await target.create();
      final link = '${root.path}\\link%JA_ESCAPE_TEST%!x&(y)^';
      // Exercise the actual generated IF blocks in CMD, but replace mklink with
      // echo so the check neither needs elevation nor changes filesystem links.
      final script =
          SnapshotService.generateBatchScript([
                entry(link, target: target.path),
              ])
              .replaceAll('net session >nul 2>&1', 'ver >nul')
              .replaceAll('        mklink /D ', '        echo VERIFIED ')
              .replaceAll('pause', 'rem pause');
      final file = File('${root.path}\\verify.cmd');
      await file.writeAsString(script);
      final result = await Process.run(
        'cmd.exe',
        ['/d', '/v:on', '/c', file.path],
        environment: {'JA_ESCAPE_TEST': 'EXPANDED_BAD_VALUE'},
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('VERIFIED "$link" "${target.path}"'));
      expect(result.stdout, isNot(contains('EXPANDED_BAD_VALUE')));
    },
    skip: !Platform.isWindows,
  );

  test(
    'preflight fails closed and rechecks each operation; never kills apps',
    () async {
      final logic = FakeRelocation();
      final preset =
          RelocatorPreset(
              id: 'test',
              name: 'test',
              description: '',
              category: RelocatorCategory.dev,
              icon: Icons.folder,
              pathResolver: () => r'C:\source',
            )
            ..actualPath = r'C:\source'
            ..sizeBytes = 1024;
      for (final free in <int?>[null, -1, 0, 500 * 1024 * 1024]) {
        logic.relocatorService.free = free;
        final result = await performRelocation(
          logic: logic,
          preset: preset,
          targetPath: r'D:\target',
        );
        expect(result.success, isFalse);
        expect(logic.calls, 0);
      }
      logic.relocatorService.fail = true;
      expect(
        (await performRelocation(
          logic: logic,
          preset: preset,
          targetPath: r'D:\target',
        )).success,
        isFalse,
      );
      logic.relocatorService.fail = false;
      logic.relocatorService.free = 500 * 1024 * 1024 + 1024;
      expect(
        (await performRelocation(
          logic: logic,
          preset: preset,
          targetPath: r'D:\target',
        )).success,
        isTrue,
      );
      expect(logic.calls, 1);
      expect(logic.killed, isFalse);
      expect(logic.relocatorService.queries, 6);
    },
  );

  test(
    'stale health observations preserve concurrent adds, removals and targets',
    () async {
      final original = Directory.current;
      final root = await Directory.systemTemp.createTemp('ja_history_race_');
      Directory.current = root;
      final service = SymlinkService();
      Directory.current = original;
      addTearDown(() => root.delete(recursive: true));
      await service.initialize();
      await service.addEntry(entry(r'C:\one'));
      await service.addEntry(entry(r'C:\two'));
      final observed = await service.readAllEntries();
      await Future.wait([
        service.addEntry(entry(r'C:\three')),
        service.updateEntryStatus(r'C:\one', 'ACTIVE', 'REMOVED'),
        service.fixEntryTarget(r'C:\two', r'E:\new'),
        service.updateHealthStatus(observed[0], 'DANGLING'),
        service.updateHealthStatus(observed[1], 'DANGLING'),
      ]);
      final saved = await service.readAllEntries();
      expect(saved.length, 3);
      expect(saved[0].status, 'REMOVED');
      expect(saved[1].targetPath, r'E:\new');
      expect(saved[1].status, 'ACTIVE');
      await service.updateHealthStatus(saved[2], 'DANGLING');
      expect((await service.readAllEntries())[2].status, 'DANGLING');
    },
  );

  test(
    'BAT escapes percent, disables expansion and rejects command-breaking paths',
    () {
      final script = SnapshotService.generateBatchScript([
        entry(r'C:\%USERNAME%\a!b&(c)^', target: r'D:\%TEMP%\data!'),
      ]);
      expect(script, contains('setlocal DisableDelayedExpansion'));
      expect(
        script,
        contains(r'mklink /D "C:\%%USERNAME%%\a!b&(c)^" "D:\%%TEMP%%\data!"'),
      );
      for (final bad in [
        'C:\\bad\r\necho injected',
        'C:\\bad"',
        'C:\\bad\x00',
      ]) {
        expect(
          () => SnapshotService.generateBatchScript([entry(bad)]),
          throwsFormatException,
        );
        expect(
          () => SnapshotService.generateBatchScript([
            entry(r'C:\ok', target: bad),
          ]),
          throwsFormatException,
        );
      }
    },
  );
}
