import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_symlink/main.dart';
import 'package:ja_symlink/layout/dashboard_shell.dart';
import 'package:ja_symlink/modules/i18n.dart';
import 'package:ja_symlink/modules/logic.dart';
import 'package:ja_symlink/modules/symlink_service.dart';
import 'package:ja_symlink/theme/theme_provider.dart';
import 'package:ja_symlink/modules/process/process_lock_model.dart';
import 'package:ja_symlink/modules/storage/storage_model.dart';

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
  bool? backendKill;
  @override
  Future<List<ProcessLockInfo>> findLockingProcesses(String path) async => [];
  @override
  Future<OperationResult> createSymlink({
    required String sourcePath,
    required String targetPath,
    bool killProcesses = true,
    bool moveData = true,
    void Function(double, String, String)? onProgress,
  }) async {
    backendKill = killProcesses;
    return OperationResult(success: true, message: 'fixture');
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<List<SymlinkEntry>> getActiveSymlinks() async => [];

  @override
  Future<List<SymlinkEntry>> getAllEntries() async => [];

  @override
  Future<bool> isAdmin() async => true;

  @override
  Future<bool> isContextMenuRegistered() async => false;

  @override
  Future<List<DriveSpaceInfo>> getDriveSpaces({
    bool forceRefresh = false,
  }) async => [
    const DriveSpaceInfo(
      letter: 'C:',
      label: 'OS',
      driveKind: DriveKind.localFixed,
      totalBytes: 500 * 1024 * 1024 * 1024,
      freeBytes: 250 * 1024 * 1024 * 1024,
    ),
  ];

  @override
  Future<StorageSavingsSummary> calculateStorageSavings(
    List<SymlinkEntry> entries, {
    bool forceRefresh = false,
  }) async => StorageSavingsSummary.empty;
}

void main() {
  testWidgets('create UI never delegates another automatic process kill', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
        child: JaSymlinkApp(
          logic: logic,
          initialSourcePath: r'C:\fixture',
          initialTargetPath: r'D:\fixture',
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    const strings = AppStrings(AppLanguage.en);
    await tester.tap(find.text(strings.btnCreateSymlink).last);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(logic.backendKill, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
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
