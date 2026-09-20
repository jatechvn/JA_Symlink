// test/symlink_scan_test.dart
// Unit and integration tests for Native Win32 Reparse Point Symlink Scanner

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/app_config.dart';
import 'package:ja_symlink/modules/native/win_core.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppConfig.initialize();
  });

  group('WindowsNativeEngine.scanSymlinks', () {
    test('returns empty list for empty path or whitespace', () async {
      final resEmpty = await WindowsNativeEngine.scanSymlinks('');
      expect(resEmpty, isEmpty);

      final resSpace = await WindowsNativeEngine.scanSymlinks('   ');
      expect(resSpace, isEmpty);
    });

    test('returns empty list for non-existent path', () async {
      final fakePath = p.join(
        Directory.systemTemp.path,
        'non_existent_folder_xyz_123',
      );
      final res = await WindowsNativeEngine.scanSymlinks(fakePath);
      expect(res, isEmpty);
    });

    test('scans real directory without throwing', () async {
      final tempDir = Directory.systemTemp.createTempSync('ja_scan_test_');
      try {
        final subDir = Directory(p.join(tempDir.path, 'normal_dir'))
          ..createSync();
        File(p.join(subDir.path, 'sample.txt')).writeAsStringSync('hello');

        final results = await WindowsNativeEngine.scanSymlinks(
          tempDir.path,
          maxDepth: 3,
        );
        // Normal directory has no symlinks
        expect(results, isEmpty);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'detects Windows system junction (C:\\Users\\All Users)',
      () async {
        if (!Platform.isWindows) return;

        // C:\Users\All Users is a standard junction to C:\ProgramData on Windows
        final results = await WindowsNativeEngine.scanSymlinks(
          r'C:\Users',
          maxDepth: 2,
        );
        expect(results, isNotEmpty);

        final allUsersItem = results.firstWhere(
          (item) =>
              (item['link'] ?? '').toLowerCase().contains('all users') ||
              (item['link'] ?? '').toLowerCase().contains('default user'),
          orElse: () => {},
        );

        expect(
          allUsersItem,
          isNotEmpty,
          reason:
              'Should find at least one standard Windows junction in C:\\Users',
        );
        expect(allUsersItem['target'], isNotEmpty);
      },
      skip: !Platform.isWindows,
    );

    test('can discover directory symlinks created in temp', () async {
      if (!Platform.isWindows) return;

      final tempDir = Directory.systemTemp.createTempSync('ja_symlink_test_');
      try {
        final targetDir = Directory(p.join(tempDir.path, 'target_dir'))
          ..createSync();
        final linkPath = p.join(tempDir.path, 'link_dir');

        bool linkCreated = false;
        try {
          Link(linkPath).createSync(targetDir.path);
          linkCreated = true;
        } catch (e) {
          // May require developer mode or admin privilege in some environments
          // If cannot create symlink in test runner, skip gracefully
        }

        if (linkCreated) {
          final results = await WindowsNativeEngine.scanSymlinks(tempDir.path);
          expect(results, isNotEmpty);
          final found = results.firstWhere(
            (r) => r['link']?.toLowerCase() == linkPath.toLowerCase(),
            orElse: () => {},
          );
          expect(found, isNotEmpty);
          expect(found['target']?.toLowerCase(), targetDir.path.toLowerCase());
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('WindowsNativeEngine Native CRUD Operations', () {
    test(
      'verifySymlink and getSymlinkTarget correctly read system junction',
      () async {
        if (!Platform.isWindows) return;

        final isLink = await WindowsNativeEngine.verifySymlink(
          r'C:\Users\All Users',
        );
        expect(isLink, isTrue);

        final target = await WindowsNativeEngine.getSymlinkTarget(
          r'C:\Users\All Users',
        );
        expect(target, isNotNull);
        expect(target!.toLowerCase(), contains('programdata'));
      },
      skip: !Platform.isWindows,
    );

    test('verifySymlink returns false for normal real directories', () async {
      if (!Platform.isWindows) return;

      final isLink = await WindowsNativeEngine.verifySymlink(r'C:\Windows');
      expect(isLink, isFalse);
    });

    test('verifySymlink returns false for non-existent path', () async {
      final isLink = await WindowsNativeEngine.verifySymlink(
        r'C:\invalid_dummy_path_xyz',
      );
      expect(isLink, isFalse);
    });

    test(
      'removeSymlink safety guard refuses to delete a real directory',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('ja_safety_test_');
        try {
          final res = await WindowsNativeEngine.removeSymlink(tempDir.path);
          expect(res.success, isFalse);
          expect(
            tempDir.existsSync(),
            isTrue,
            reason: 'Real directory must NOT be deleted',
          );
        } finally {
          tempDir.deleteSync();
        }
      },
    );

    test('createSymlink fails if linkPath and targetPath are equal', () async {
      final res = await WindowsNativeEngine.createSymlink(
        r'C:\same',
        r'C:\same',
      );
      expect(res.success, isFalse);
      expect(res.message, contains('must be different'));
    });
  });
}
