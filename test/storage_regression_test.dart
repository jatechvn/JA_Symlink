import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/storage/storage_intelligence_service.dart';
import 'package:ja_symlink/modules/symlink_service.dart';

class MeasuredStorage extends StorageIntelligenceService {
  Completer<(int, int)>? pending;
  int calls = 0;
  @override
  Future<(int, int)> measureTarget(String path) async {
    calls++;
    if (pending != null) return pending!.future;
    return path.toLowerCase().contains('child') ? (25, 1) : (100, 4);
  }
}

SymlinkEntry link(String source, String target) => SymlinkEntry(
  timestamp: '',
  linkPath: source,
  targetPath: target,
  backupPath: '',
  status: 'ACTIVE',
);

void main() {
  test(
    'cache never shares source classification and unions overlapping targets',
    () async {
      final service = MeasuredStorage();
      addTearDown(service.dispose);
      final first = await service.calculateSavings([link(r'D:\a', r'E:\data')]);
      expect(first.totalSavedOnCBytes, 0);
      final result = await service.calculateSavings([
        link(r'D:\a', r'E:\data'),
        link(r'C:\b', r'e:/data'),
        link(r'C:\c', r'E:\data\child'),
      ]);
      expect(result.totalSavedBytes, 100);
      expect(result.totalSavedOnCBytes, 100);
      expect(result.totalFileCount, 4);
      expect(result.perDriveSavings, {'E:': 100});
      final mixed = await service.calculateSavings([
        link(r'D:\a', r'E:\data'),
        link(r'C:\c', r'E:\data\child'),
      ]);
      expect(mixed.totalSavedOnCBytes, 25);
      expect(mixed.totalSavedBytes, 100);
    },
  );
  test('older scan cannot restore totals after removing all entries', () async {
    final service = MeasuredStorage()..pending = Completer<(int, int)>();
    addTearDown(service.dispose);
    final old = service.calculateSavings([link(r'C:\a', r'D:\data')]);
    await service.calculateSavings([]);
    service.pending!.complete((100, 4));
    await old;
    expect(service.savings.totalSavedBytes, 0);
    expect(service.isScanning, isFalse);
    expect(service.getStatForTarget(r'D:\data'), isNull);
  });
  test('dispose during scan prevents late notification', () async {
    final service = MeasuredStorage()..pending = Completer<(int, int)>();
    final old = service.calculateSavings([link(r'C:\a', r'D:\data')]);
    service.dispose();
    service.pending!.complete((100, 4));
    await old;
  });
}
