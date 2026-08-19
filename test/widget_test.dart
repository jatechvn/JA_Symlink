import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/main.dart';
import 'package:ja_symlink/modules/i18n.dart';
import 'package:ja_symlink/modules/logic.dart';
import 'package:ja_symlink/modules/ui/main_window.dart';
import 'package:ja_symlink/modules/symlink_service.dart';
import 'package:ja_symlink/modules/ui/styles.dart';

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
  testWidgets('JaSymlinkApp renders MainWindow without crashing', (WidgetTester tester) async {
    // Set screen size to 1920x1080 to accommodate fallback font widths in test environment
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    final logic = FakeSymlinkLogic();
    await tester.pumpWidget(JaSymlinkApp(
      logic: logic,
      initialLanguage: AppLanguage.en,
      initialThemeMode: AppThemeMode.dark,
    ));

    // Verify if MainWindow is rendered
    expect(find.byType(MainWindow), findsOneWidget);

    // Reset view settings after test
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
