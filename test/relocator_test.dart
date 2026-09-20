import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/relocator/relocator_model.dart';
import 'package:ja_symlink/modules/relocator/relocator_service.dart';

void main() {
  test(
    'background scan counts nested files without following symlinks',
    () async {
      final root = await Directory.systemTemp.createTemp('ja_background_scan_');
      addTearDown(() => root.delete(recursive: true));
      final source = await Directory(
        '${root.path}/source/nested/empty',
      ).create(recursive: true);
      final sourcePath = '${root.path}/source';
      await File('$sourcePath/a').writeAsBytes([1, 2, 3]);
      await File('${source.parent.path}/b').writeAsBytes([4, 5]);
      final outside = await Directory('${root.path}/outside').create();
      await File('${outside.path}/ignored').writeAsBytes(List.filled(100, 1));
      await Link('$sourcePath/external').create(outside.path);
      await Link('$sourcePath/broken').create('${root.path}/missing');
      final preset = RelocatorPreset(
        id: 'test',
        name: 'test',
        description: '',
        category: RelocatorCategory.dev,
        icon: Icons.folder,
        pathResolver: () => sourcePath,
      );
      await RelocatorService().scanPreset(preset);
      expect(preset.status, RelocatorStatus.detected);
      expect(preset.sizeBytes, 5);
      expect(preset.fileCount, 2);
    },
  );
  group('RelocatorPreset Model', () {
    test('formats byte sizes correctly', () {
      final preset = RelocatorPreset(
        id: 'test',
        name: 'Test',
        description: 'Test',
        category: RelocatorCategory.dev,
        icon: Icons.folder,
        pathResolver: () => r'C:\Test',
      );

      preset.sizeBytes = 0;
      expect(preset.formattedSize, '0 B');

      preset.sizeBytes = 1024;
      expect(preset.formattedSize, '1.00 KB');

      preset.sizeBytes = 500 * 1024 * 1024;
      expect(preset.formattedSize, '500.0 MB');

      preset.sizeBytes = (2.5 * 1024 * 1024 * 1024).round();
      expect(preset.formattedSize, '2.50 GB');
    });

    test(
      'isRelocatable returns true only for detected status with size > 0',
      () {
        final preset = RelocatorPreset(
          id: 'test',
          name: 'Test',
          description: 'Test',
          category: RelocatorCategory.ai,
          icon: Icons.folder,
          pathResolver: () => r'C:\Test',
        );

        expect(preset.isRelocatable, isFalse);

        preset.status = RelocatorStatus.detected;
        preset.sizeBytes = 0;
        expect(preset.isRelocatable, isFalse);

        preset.sizeBytes = 1024;
        expect(preset.isRelocatable, isTrue);

        preset.status = RelocatorStatus.alreadySymlinked;
        expect(preset.isRelocatable, isFalse);
      },
    );
  });

  group('DriveTargetInfo Model', () {
    test('calculates free percent and formatted labels correctly', () {
      const drive = DriveTargetInfo(
        letter: 'D:',
        freeBytes: 50 * 1024 * 1024 * 1024, // 50 GB
        totalBytes: 100 * 1024 * 1024 * 1024, // 100 GB
      );

      expect(drive.percentFree, closeTo(0.5, 0.01));
      expect(drive.formattedFree, '50.0 GB trống');
      expect(drive.formattedTotal, '100 GB');
    });
  });

  group('RelocatorService Presets', () {
    test('contains presets for all primary categories', () {
      final service = RelocatorService();
      final presets = service.presets;

      expect(presets.length, greaterThanOrEqualTo(10));

      final categories = presets.map((p) => p.category).toSet();
      expect(categories, contains(RelocatorCategory.ai));
      expect(categories, contains(RelocatorCategory.dev));
      expect(categories, contains(RelocatorCategory.media));
      expect(categories, contains(RelocatorCategory.game));

      final presetIds = presets.map((p) => p.id).toSet();
      expect(presetIds, contains('huggingface'));
      expect(presetIds, contains('ollama'));
      expect(presetIds, contains('gradle_cache'));
      expect(presetIds, contains('npm_cache'));
    });

    test('builds standard destination folder structure', () {
      final service = RelocatorService();
      final hfPreset = service.presets.firstWhere((p) => p.id == 'huggingface');
      final dest = service.getDefaultDestination('E:', hfPreset);

      expect(dest, equals(r'E:\JA_Relocated\HuggingFace Models'));
    });
  });
}
