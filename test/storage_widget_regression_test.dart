import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_symlink/modules/i18n.dart';
import 'package:ja_symlink/modules/storage/storage_model.dart';
import 'package:ja_symlink/theme/theme_provider.dart';
import 'package:ja_symlink/views/overview_view.dart';
import 'package:ja_symlink/widgets/storage_savings_card.dart';
import 'widget_test.dart' show FakeSymlinkLogic;

class DriveRefreshLogic extends FakeSymlinkLogic {
  int refreshes = 0;
  @override
  Future<List<DriveSpaceInfo>> getDriveSpaces({
    bool forceRefresh = false,
  }) async {
    refreshes++;
    return [];
  }
}

void main() {
  testWidgets(
    'drive timer refreshes every 15s and stops on unmount; C counter stays zero',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final language = LanguageNotifier(AppLanguage.en);
      final theme = ThemeProvider(initialMode: 'dark');
      addTearDown(language.dispose);
      addTearDown(theme.dispose);
      final logic = DriveRefreshLogic();
      Widget wrap(Widget child) => ChangeNotifierProvider.value(
        value: theme,
        child: LanguageProvider(
          notifier: language,
          child: MaterialApp(home: Scaffold(body: child)),
        ),
      );
      await tester.pumpWidget(
        wrap(
          OverviewView(
            entries: const [],
            isAdmin: true,
            onCreate: () {},
            onScan: () {},
            onVerify: () {},
            onSelectTab: (_) {},
            logic: logic,
          ),
        ),
      );
      await tester.pump();
      expect(logic.refreshes, 1);
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(logic.refreshes, 2);
      await tester.pumpWidget(
        wrap(
          StorageSavingsCard(
            savings: const StorageSavingsSummary(
              totalSavedBytes: 1073741824,
              totalSavedOnCBytes: 0,
              activeLinkCount: 1,
              totalFileCount: 1,
              perDriveSavings: {},
            ),
            isScanning: false,
            onRelocateMore: () {},
            onRecalculate: () {},
            colors: theme.colors,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 30));
      expect(logic.refreshes, 2);
      expect(find.text('0.00'), findsOneWidget);
      expect(find.text('GB'), findsNothing);
    },
  );
}
