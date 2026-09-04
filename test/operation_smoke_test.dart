import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/constants.dart';
import 'package:ja_symlink/modules/logic/change_operation.dart';
import 'package:ja_symlink/modules/logic/create_operation.dart';
import 'package:ja_symlink/modules/logic/import_export.dart';
import 'package:ja_symlink/modules/logic/remove_operation.dart';
import 'package:ja_symlink/modules/symlink_service.dart';
import 'package:ja_symlink/modules/utils.dart';

void main() {
  test(
    'create, change, remove/restore, and import operations work end-to-end',
    () async {
      final originalDirectory = Directory.current;
      final root = await Directory.systemTemp.createTemp('ja_symlink_smoke_');
      Directory.current = root;
      addTearDown(() async {
        Directory.current = originalDirectory;
        if (root.existsSync()) await root.delete(recursive: true);
      });

      final service = SymlinkService();
      await service.initialize();
      final source = Directory('${root.path}\\source');
      final firstTarget = Directory('${root.path}\\target-one');
      final secondTarget = Directory('${root.path}\\target-two');
      await Directory('${source.path}\\nested\\empty').create(recursive: true);
      await File('${source.path}\\hello.txt').writeAsString('smoke-test');

      final createResult = await performCreateSymlink(
        service: service,
        sourcePath: source.path,
        targetPath: firstTarget.path,
        killProcesses: false,
        moveData: true,
      );
      expect(createResult.success, isTrue, reason: createResult.message);
      expect(await isSymlink(source.path), isTrue);
      expect(await getSymlinkTarget(source.path), isNotNull);
      expect(
        File('${firstTarget.path}\\hello.txt').readAsStringSync(),
        'smoke-test',
      );
      expect(
        Directory('${firstTarget.path}\\nested\\empty').existsSync(),
        isTrue,
      );

      final changeResult = await performChangeSymlink(
        service: service,
        linkPath: source.path,
        newTargetPath: secondTarget.path,
        moveData: true,
      );
      expect(changeResult.success, isTrue, reason: changeResult.message);
      expect(await isSymlink(source.path), isTrue);
      expect(
        pathsEqual(
          await getSymlinkTarget(source.path) ?? '',
          secondTarget.path,
        ),
        isTrue,
      );
      expect(
        File('${secondTarget.path}\\hello.txt').readAsStringSync(),
        'smoke-test',
      );
      expect(firstTarget.existsSync(), isFalse);

      final removeResult = await performRemoveSymlink(
        service: service,
        linkPath: source.path,
      );
      expect(removeResult.success, isTrue, reason: removeResult.message);
      expect(await isSymlink(source.path), isFalse);
      expect(secondTarget.existsSync(), isTrue);

      final backupSource = Directory('${root.path}\\backup-source');
      final backupTarget = Directory('${root.path}\\backup-target');
      await backupSource.create(recursive: true);
      await File('${backupSource.path}\\keep.txt').writeAsString('keep-me');
      final backupCreate = await performCreateSymlink(
        service: service,
        sourcePath: backupSource.path,
        targetPath: backupTarget.path,
        killProcesses: false,
        moveData: false,
      );
      expect(backupCreate.success, isTrue, reason: backupCreate.message);
      final backupRemove = await performRemoveSymlink(
        service: service,
        linkPath: backupSource.path,
        restoreBackup: true,
      );
      expect(backupRemove.success, isTrue, reason: backupRemove.message);
      expect(
        File('${backupSource.path}\\keep.txt').readAsStringSync(),
        'keep-me',
      );
      expect(await isSymlink(backupSource.path), isFalse);

      final importedLink = Directory('${root.path}\\imported-link');
      final importedTarget = Directory('${root.path}\\imported-target');
      await importedTarget.create(recursive: true);
      final importFile = File('${root.path}\\import.json');
      await importFile.writeAsString(
        jsonEncode([
          {
            'timestamp': 'smoke',
            'linkPath': importedLink.path,
            'targetPath': importedTarget.path,
            'backupPath': csvEmptyPlaceholder,
            'status': statusActive,
          },
        ]),
      );
      final importResult = await performImport(service, importFile.path);
      expect(importResult.success, 1);
      expect(importResult.failed, 0);
      expect(await isSymlink(importedLink.path), isTrue);
      expect(
        pathsEqual(
          await getSymlinkTarget(importedLink.path) ?? '',
          importedTarget.path,
        ),
        isTrue,
      );
      final persistedEntries = await service.readAllEntries();
      expect(
        persistedEntries.any(
          (entry) =>
              pathsEqual(entry.linkPath, importedLink.path) && entry.isActive,
        ),
        isTrue,
      );
    },
  );
}
