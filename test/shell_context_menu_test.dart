import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/shell/shell_context_menu.dart';

void main() {
  group('CLI Source and Target Argument Parsing', () {
    (String?, String?) parseCliPaths(List<String> args) {
      String? source;
      String? target;
      for (int i = 0; i < args.length; i++) {
        final arg = args[i];
        if ((arg == '--source' || arg == '-s') && i + 1 < args.length) {
          source = args[i + 1];
        } else if ((arg == '--target' || arg == '-t') && i + 1 < args.length) {
          target = args[i + 1];
        }
      }
      return (source, target);
    }

    test('parses --source argument correctly', () {
      final (source, target) = parseCliPaths([
        '--source',
        r'C:\Users\V\AppData\Roaming\TestApp',
      ]);
      expect(source, equals(r'C:\Users\V\AppData\Roaming\TestApp'));
      expect(target, isNull);
    });

    test('parses --target argument correctly', () {
      final (source, target) = parseCliPaths(['--target', r'D:\DATA']);
      expect(source, isNull);
      expect(target, equals(r'D:\DATA'));
    });

    test('parses shorthand -s and -t arguments', () {
      final (source, target) = parseCliPaths([
        '-s',
        r'C:\Source',
        '-t',
        r'E:\Target',
      ]);
      expect(source, equals(r'C:\Source'));
      expect(target, equals(r'E:\Target'));
    });

    test('handles empty or malformed args safely', () {
      final (source, target) = parseCliPaths(['--source']);
      expect(source, isNull);
      expect(target, isNull);
    });
  });

  group('ShellContextMenuService', () {
    test('isRegistered returns boolean without throwing', () async {
      final isReg = await ShellContextMenuService.isRegistered();
      expect(isReg, isA<bool>());
    });
  });
}
