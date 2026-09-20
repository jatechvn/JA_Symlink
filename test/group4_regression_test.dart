import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/symlink_service.dart';
import 'package:ja_symlink/modules/logic/verify_operation.dart';

class _History extends SymlinkService {
  @override
  Future<List<SymlinkEntry>> readAllEntries() async => [
    for (final status in ['DANGLING', 'REMOVED'])
      SymlinkEntry(
        timestamp: '',
        linkPath: r'Z:\ja_nonexistent_group4_fixture\link',
        targetPath: r'Z:\ja_nonexistent_group4_fixture\target',
        backupPath: '-',
        status: status,
      ),
  ];
}

void main() {
  test(
    'verify includes dangling records and excludes removed history',
    () async {
      final results = await performVerifyAndFix(_History());
      expect(results, hasLength(1));
      expect(results.single['status'], 'MISSING');
    },
  );
}
