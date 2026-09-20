import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/constants.dart';
import 'package:ja_symlink/modules/health/health_watcher.dart';
import 'package:ja_symlink/modules/symlink_service.dart';
import 'package:ja_symlink/modules/utils.dart';

void main() {
  test('HealthWatcher marks missing targets as broken/DANGLING', () async {
    final originalDirectory = Directory.current;
    final root = await Directory.systemTemp.createTemp(
      'ja_health_watcher_test_',
    );
    Directory.current = root;
    addTearDown(() async {
      Directory.current = originalDirectory;
      if (root.existsSync()) await root.delete(recursive: true);
    });

    final service = SymlinkService();
    await service.initialize();

    // Create an entry pointing to non-existent target
    const nonExistentTarget = r'Z:\MissingDrive\Folder';
    const fakeLink = r'C:\MissingLink\Folder';
    await service.addEntry(
      SymlinkEntry(
        timestamp: formatTimestamp(),
        linkPath: fakeLink,
        targetPath: nonExistentTarget,
        backupPath: csvEmptyPlaceholder,
        status: statusActive,
      ),
    );

    final watcher = HealthWatcher(service);
    addTearDown(() => watcher.dispose());

    expect(watcher.brokenCount, equals(0));
    expect(watcher.hasIssues, isFalse);

    await watcher.checkHealth();

    expect(watcher.brokenCount, equals(1));
    expect(watcher.hasIssues, isTrue);
    expect(watcher.lastCheckTime, isNotNull);

    // Verify entry status was updated in service to DANGLING
    final updatedEntries = await service.readAllEntries();
    expect(updatedEntries.first.status, equals('DANGLING'));
  });
}
