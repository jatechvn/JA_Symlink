import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_symlink/main.dart';
import 'package:ja_symlink/layout/dashboard_shell.dart';
import 'package:ja_symlink/modules/i18n.dart';
import 'package:ja_symlink/modules/logic.dart';
import 'package:ja_symlink/modules/symlink_service.dart';
import 'package:ja_symlink/theme/theme_provider.dart';

class FakeSymlinkService extends SymlinkService {
  @override
  Future<void> initialize() async {}
  @override
  Future<List<SymlinkEntry>> readAllEntries() async => [];
  @override
  Future<List<SymlinkEntry>> getActiveEntries() async => [];
}

class FakeSymlinkLogic extends SymlinkLogic {
  FakeSymlinkLogic() : super(FakeSymlinkService());

  @override
  Future<void> initialize() async {}

  @override
  Future<List<SymlinkEntry>> getActiveSymlinks() async => [];

  @override
  Future<List<SymlinkEntry>> getAllEntries() async => [];

  @override
  Future<bool> isAdmin() async => true;
}

void main() {
  testWidgets('JaSymlinkApp renders DashboardShell without crashing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    final logic = FakeSymlinkLogic();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(initialMode: 'dark'),
          ),
          ChangeNotifierProvider(
            create: (_) => LanguageNotifier(AppLanguage.en),
          ),
        ],
        child: JaSymlinkApp(logic: logic),
      ),
    );

    expect(find.byType(DashboardShell), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
