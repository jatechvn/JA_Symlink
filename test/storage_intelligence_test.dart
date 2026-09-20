// test/storage_intelligence_test.dart
// Unit tests for Storage Intelligence models, DriveSpaceInfo, and StorageSavingsSummary

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/storage/storage_model.dart';
import 'package:ja_symlink/modules/storage/storage_intelligence_service.dart';
import 'package:ja_symlink/modules/symlink_service.dart';

void main() {
  group('DriveSpaceInfo Model', () {
    test('calculates used bytes and percentages correctly', () {
      const drive = DriveSpaceInfo(
        letter: 'C:',
        label: 'Windows',
        driveKind: DriveKind.localFixed,
        totalBytes: 1000,
        freeBytes: 300,
      );

      expect(drive.usedBytes, 700);
      expect(drive.usedPercent, 0.70);
      expect(drive.freePercent, 0.30);
      expect(drive.isSystemDrive, isTrue);
      expect(drive.urgency, DriveUrgency.normal);
      expect(drive.displayTitle, 'C: (Windows)');
    });

    test('detects warning and critical urgency thresholds', () {
      const normalDrive = DriveSpaceInfo(
        letter: 'D:',
        label: 'Data',
        driveKind: DriveKind.localFixed,
        totalBytes: 100,
        freeBytes: 25, // 75% used
      );
      expect(normalDrive.urgency, DriveUrgency.normal);

      const warningDrive = DriveSpaceInfo(
        letter: 'E:',
        label: 'Backup',
        driveKind: DriveKind.localFixed,
        totalBytes: 100,
        freeBytes: 15, // 85% used
      );
      expect(warningDrive.urgency, DriveUrgency.warning);

      const criticalDrive = DriveSpaceInfo(
        letter: 'F:',
        label: 'Full',
        driveKind: DriveKind.localFixed,
        totalBytes: 100,
        freeBytes: 5, // 95% used
      );
      expect(criticalDrive.urgency, DriveUrgency.critical);
    });

    test('handles zero total bytes safely without divide-by-zero', () {
      const drive = DriveSpaceInfo(
        letter: 'Z:',
        label: '',
        driveKind: DriveKind.unknown,
        totalBytes: 0,
        freeBytes: 0,
      );

      expect(drive.usedPercent, 0.0);
      expect(drive.freePercent, 0.0);
      expect(drive.urgency, DriveUrgency.normal);
      expect(drive.displayTitle, 'Z:');
    });
  });

  group('StorageSavingsSummary Model', () {
    test('formats GB values and totals accurately', () {
      const summary = StorageSavingsSummary(
        totalSavedBytes: 10737418240, // 10 GB
        totalSavedOnCBytes: 5368709120, // 5 GB
        activeLinkCount: 2,
        totalFileCount: 450,
        perDriveSavings: {'D:': 5368709120, 'E:': 5368709120},
      );

      expect(summary.totalSavedGigabytes, closeTo(10.0, 0.01));
      expect(summary.savedOnCGigabytes, closeTo(5.0, 0.01));
      expect(summary.activeLinkCount, 2);
      expect(summary.totalFileCount, 450);
      expect(summary.formattedTotalSaved, contains('10.00 GB'));
      expect(summary.formattedSavedOnC, contains('5.00 GB'));
    });

    test('empty summary has zero counters', () {
      const empty = StorageSavingsSummary.empty;
      expect(empty.totalSavedBytes, 0);
      expect(empty.totalSavedOnCBytes, 0);
      expect(empty.activeLinkCount, 0);
      expect(empty.perDriveSavings, isEmpty);
    });
  });

  group('computeDirectorySizeWorker', () {
    test('returns (0, 0) for non-existent path', () {
      final (bytes, files) = computeDirectorySizeWorker(
        r'C:\NonExistent_Dir_Ja_Test_123',
      );
      expect(bytes, 0);
      expect(files, 0);
    });

    test('counts files accurately in temporary directory', () {
      final tempDir = Directory.systemTemp.createTempSync('ja_storage_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final f1 = File('${tempDir.path}\\file1.txt');
      f1.writeAsStringSync('Hello World'); // 11 bytes

      final f2 = File('${tempDir.path}\\file2.txt');
      f2.writeAsStringSync('Antigravity'); // 11 bytes

      final (bytes, files) = computeDirectorySizeWorker(tempDir.path);
      expect(files, 2);
      expect(bytes, 22);
    });
  });

  group('StorageIntelligenceService', () {
    test('calculateSavings returns empty summary for empty list', () async {
      final service = StorageIntelligenceService();
      addTearDown(service.dispose);

      final result = await service.calculateSavings([]);
      expect(result.totalSavedBytes, 0);
      expect(result.activeLinkCount, 0);
    });

    test('calculateSavings ignores non-active symlink entries', () async {
      final service = StorageIntelligenceService();
      addTearDown(service.dispose);

      final entries = [
        SymlinkEntry(
          timestamp: '2026-09-20',
          linkPath: r'C:\Users\App\Cache',
          targetPath: r'D:\Cache',
          backupPath: '',
          status: 'REMOVED',
        ),
      ];

      final result = await service.calculateSavings(entries);
      expect(result.totalSavedBytes, 0);
      expect(result.activeLinkCount, 0);
    });
  });
}
