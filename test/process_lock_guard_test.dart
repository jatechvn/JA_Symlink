import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_symlink/dialogs/process_lock_guard.dart';
import 'package:ja_symlink/modules/i18n.dart';
import 'package:ja_symlink/modules/logic.dart';
import 'package:ja_symlink/modules/process/process_lock_model.dart';
import 'package:ja_symlink/modules/symlink_service.dart';
import 'package:ja_symlink/theme/theme_provider.dart';

class GuardLogic extends SymlinkLogic {
  GuardLogic() : super(SymlinkService());
  bool stopped = false;
  int scans = 0;
  List<int> killed = [];
  @override
  Future<List<ProcessLockInfo>> findLockingProcesses(String path) async {
    scans++;
    return scans > 1
        ? []
        : [const ProcessLockInfo(pid: 12345, name: 'fixture')];
  }

  @override
  Future<bool> terminateProcesses(List<int> pids) async {
    killed = pids;
    return stopped;
  }
}

void main() {
  for (final action in ['cancel', 'ignore', 'failure', 'success']) {
    testWidgets('lock guard $action respects approval and termination result', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final logic = GuardLogic()..stopped = action == 'success';
      bool? allowed;
      final language = LanguageNotifier(AppLanguage.en);
      addTearDown(language.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialMode: 'dark'),
          child: LanguageProvider(
            notifier: language,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      allowed = await confirmProcessLocks(
                        context,
                        logic,
                        r'C:\test',
                      );
                    },
                    child: const Text('start'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      const strings = AppStrings(AppLanguage.en);
      await tester.tap(
        find.text(
          action == 'cancel'
              ? strings.btnCancel
              : action == 'ignore'
              ? strings.btnIgnoreAndContinue
              : strings.btnKillAndContinue,
        ),
      );
      await tester.pumpAndSettle();
      if (action == 'failure') {
        expect(find.text('Không thể tiếp tục'), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      expect(allowed, action == 'ignore' || action == 'success');
      expect(
        logic.killed,
        action == 'failure' || action == 'success' ? [12345] : isEmpty,
      );
      expect(logic.scans, action == 'success' ? 2 : 1);
    });
  }
}
