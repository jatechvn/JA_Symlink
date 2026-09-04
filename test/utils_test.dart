import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/utils.dart';

void main() {
  test(
    'normalizes empty input without turning it into the current directory',
    () {
      expect(normalizePath('   '), isEmpty);
    },
  );

  test('compares Windows paths case-insensitively and safely', () {
    expect(pathsEqual(r'C:\Data', r'c:/data/'), isTrue);
    expect(pathsEqual(r'C:\Data', r'C:\Database'), isFalse);
    expect(isSameOrChildPath(r'C:\Data', r'C:\Data\Nested'), isTrue);
    expect(isSameOrChildPath(r'C:\Data', r'C:\Database'), isFalse);
  });

  test('copy preserves empty directories', () async {
    final root = await Directory.systemTemp.createTemp('ja_symlink_utils_');
    final source = Directory('${root.path}${Platform.pathSeparator}source');
    final destination = Directory(
      '${root.path}${Platform.pathSeparator}destination',
    );
    addTearDown(() => root.delete(recursive: true));

    await Directory(
      '${source.path}${Platform.pathSeparator}empty${Platform.pathSeparator}nested',
    ).create(recursive: true);

    await copyDirectoryWithProgress(
      source.path,
      destination.path,
      onProgress: (_, __, ___) {},
    );

    expect(
      Directory(
        '${destination.path}${Platform.pathSeparator}empty${Platform.pathSeparator}nested',
      ).existsSync(),
      isTrue,
    );
  });

  test('copy rejects a destination inside the source', () async {
    final root = await Directory.systemTemp.createTemp('ja_symlink_utils_');
    final source = Directory('${root.path}${Platform.pathSeparator}source');
    addTearDown(() => root.delete(recursive: true));
    await source.create(recursive: true);

    await expectLater(
      copyDirectoryWithProgress(
        source.path,
        '${source.path}${Platform.pathSeparator}nested',
        onProgress: (_, __, ___) {},
      ),
      throwsArgumentError,
    );
  });
}
