import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/shell/shell_context_menu.dart';
import 'package:ja_symlink/modules/process/process_lock_service.dart';

void main() {
  test(
    'registry failures never report success and both menus are checked',
    () async {
      final original = ShellContextMenuService.runRegistry;
      addTearDown(() => ShellContextMenuService.runRegistry = original);
      for (var failure = 0; failure < 8; failure++) {
        var calls = 0;
        ShellContextMenuService.runRegistry = (args) async =>
            ProcessResult(0, calls++ == failure ? 1 : 0, '', 'denied');
        expect(
          await ShellContextMenuService.register(customExePath: r'C:\app.exe'),
          isFalse,
        );
      }
      var queries = 0;
      ShellContextMenuService.runRegistry = (args) async {
        if (args.first == 'query') queries++;
        return ProcessResult(0, 0, '', '');
      };
      expect(
        await ShellContextMenuService.register(customExePath: r'C:\app.exe'),
        isTrue,
      );
      expect(queries, 2);
      expect(
        await ShellContextMenuService.unregister(),
        isFalse,
      ); // keys remain
      var deletes = 0;
      ShellContextMenuService.runRegistry = (args) async {
        if (args.first == 'delete') deletes++;
        return ProcessResult(0, 1, '', 'denied');
      };
      expect(await ShellContextMenuService.unregister(), isFalse);
      expect(deletes, 2);
      ShellContextMenuService.runRegistry = (args) async =>
          ProcessResult(0, args.first == 'delete' ? 0 : 1, '', '');
      expect(await ShellContextMenuService.unregister(), isTrue);
    },
    skip: !Platform.isWindows,
  );

  test(
    'Restart Manager finds a nested data-file owner, excludes sibling prefix',
    () async {
      final root = await Directory.systemTemp.createTemp('ja_lock_probe_');
      final folder = await Directory(
        '${root.path}/App/nested',
      ).create(recursive: true);
      await Directory('${root.path}/Application').create();
      final file = File('${folder.path}/data.db');
      await file.writeAsString('fixture');
      final child = await Process.start(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r"$f = [IO.File]::Open($env:JA_TEST_FILE, 'Open', 'ReadWrite', 'None'); Write-Output 'READY'; try { Start-Sleep -Seconds 15 } finally { $f.Dispose() }",
        ],
        environment: {'JA_TEST_FILE': file.path},
      );
      addTearDown(() async {
        await child.stdin.close();
        await child.exitCode.timeout(const Duration(seconds: 25));
        await root.delete(recursive: true);
      });
      final ready = Completer<void>();
      child.stdout.listen((_) {
        if (!ready.isCompleted) ready.complete();
      });
      child.stderr.listen((_) {});
      await ready.future.timeout(const Duration(seconds: 15));
      final service = ProcessLockService();
      final locks = await service.findLockingProcesses('${root.path}/App');
      expect(locks.map((p) => p.pid), contains(child.pid));
      final unrelated = await service.findLockingProcesses(
        '${root.path}/Application',
      );
      expect(unrelated.map((p) => p.pid), isNot(contains(child.pid)));
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
