import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/process/process_lock_model.dart';
import 'package:ja_symlink/modules/process/process_lock_service.dart';

void main() {
  group('ProcessLockInfo Model', () {
    test('parses from JSON correctly', () {
      final json = {
        'Id': 1234,
        'ProcessName': 'code',
        'Description': 'Visual Studio Code',
        'MainWindowTitle': 'index.dart - JA_Symlink',
        'Path': r'C:\Users\V\AppData\Local\Programs\Microsoft VS Code\Code.exe',
      };

      final info = ProcessLockInfo.fromJson(json);

      expect(info.pid, equals(1234));
      expect(info.name, equals('code'));
      expect(info.description, equals('Visual Studio Code'));
      expect(info.windowTitle, equals('index.dart - JA_Symlink'));
      expect(info.displayName, equals('Visual Studio Code'));
    });

    test(
      'displayName falls back to process name when description is empty',
      () {
        const info = ProcessLockInfo(
          pid: 5678,
          name: 'ollama_app',
          description: '   ',
        );

        expect(info.displayName, equals('ollama_app'));
      },
    );

    test('serializes to JSON correctly', () {
      const info = ProcessLockInfo(
        pid: 9999,
        name: 'discord',
        description: 'Discord',
        windowTitle: 'Discord',
        executablePath: r'C:\Discord\Discord.exe',
      );

      final json = info.toJson();
      expect(json['pid'], equals(9999));
      expect(json['name'], equals('discord'));
      expect(json['description'], equals('Discord'));
    });
  });

  group('ProcessLockService', () {
    test('returns empty list for non-existent or empty directories', () async {
      final service = ProcessLockService();

      expect(await service.findLockingProcesses(''), isEmpty);
      expect(await service.findLockingProcesses('   '), isEmpty);
      expect(
        await service.findLockingProcesses(
          r'Z:\DefinitelyNonExistentFolder_12345',
        ),
        isEmpty,
      );
    });
  });
}
