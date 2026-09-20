// test/fast_scan_test.dart
// Unit and widget tests for Fast Disk Analyzer (Hierarchical Folder Tree)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/app_config.dart';
import 'package:ja_symlink/modules/fast_scan/fast_scan_model.dart';
import 'package:ja_symlink/modules/fast_scan/fast_scan_service.dart';
import 'package:ja_symlink/modules/i18n.dart';
import 'package:ja_symlink/modules/logic.dart';
import 'package:ja_symlink/modules/symlink_service.dart';
import 'package:ja_symlink/theme/theme_provider.dart';
import 'package:ja_symlink/views/fast_analyzer_view.dart';
import 'package:provider/provider.dart';

class FakeSymlinkService extends Fake implements SymlinkService {
  @override
  Future<void> initialize() async {}
  @override
  Future<List<SymlinkEntry>> getActiveEntries() async => [];
  @override
  Future<List<SymlinkEntry>> readAllEntries() async => [];
}

Widget buildTestWidget({required Widget child}) {
  final langNotifier = LanguageNotifier(AppLanguage.vi);
  final themeProvider = ThemeProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
    ],
    child: LanguageProvider(
      notifier: langNotifier,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppConfig.initialize();
  });

  group('FastFolderNode & DriveScanResult Models', () {
    test('FastFolderNode correctly formats sizes', () {
      const nodeKb = FastFolderNode(
        path: r'C:\Test\Small',
        sizeBytes: 2048,
        fileCount: 2,
        driveLetter: 'C:',
      );
      expect(nodeKb.formattedSize, '2.0 KB');
      expect(nodeKb.folderName, 'Small');

      const nodeGb = FastFolderNode(
        path: r'C:\Games\Steam',
        sizeBytes: 32 * 1024 * 1024 * 1024,
        fileCount: 4500,
        folderCount: 120,
        driveLetter: 'C:',
      );
      expect(nodeGb.formattedSize, '32.00 GB');
      expect(nodeGb.folderName, 'Steam');
    });

    test('DriveScanResult parses JSON properly and builds RootTreeNode', () {
      final json = {
        'success': true,
        'duration_ms': 1420,
        'total_files': 150000,
        'total_directories': 25000,
        'total_bytes': 100 * 1024 * 1024 * 1024,
        'is_mft': true,
        'top_folders': [
          {
            'path': r'C:\Users\User\AppData',
            'size_bytes': 45 * 1024 * 1024 * 1024,
            'file_count': 50000,
            'folder_count': 4000,
          },
        ],
        'root_folders': [
          {
            'path': r'C:\Users',
            'size_bytes': 60 * 1024 * 1024 * 1024,
            'file_count': 70000,
            'folder_count': 5000,
          },
          {
            'path': r'C:\Program Files',
            'size_bytes': 30 * 1024 * 1024 * 1024,
            'file_count': 40000,
            'folder_count': 3000,
          },
        ],
      };

      final result = DriveScanResult.fromJson(json, 'C:');
      expect(result.success, isTrue);
      expect(result.durationMs, 1420);
      expect(result.formattedDuration, '1.42 s');
      expect(result.isMftEngine, isTrue);
      expect(result.topHeavyFolders.length, 1);
      expect(result.topHeavyFolders.first.folderName, 'AppData');

      final rootNode = result.buildRootTreeNode();
      expect(rootNode.path, 'C:\\');
      expect(rootNode.depth, 0);
      expect(rootNode.children.length, 2);
      expect(rootNode.children.first.name, 'Users');
      expect(rootNode.children.first.depth, 1);
      expect(rootNode.children.first.formattedSize, '60.00 GB');
    });

    test('FolderTreeNode handles direct files and children correctly', () {
      final node = FolderTreeNode(
        path: r'C:\Users\User\Downloads',
        name: 'Downloads',
        sizeBytes: 15 * 1024 * 1024 * 1024,
        fileCount: 300,
        folderCount: 5,
        driveLetter: 'C:',
        depth: 2,
      );

      expect(node.formattedSize, '15.00 GB');
      expect(node.isExpanded, isFalse);
      expect(node.isLoading, isFalse);
      expect(node.isDirectFiles, isFalse);
    });
  });

  group('i18n strings tests', () {
    test('WizTree is removed from all buttons and engine labels', () {
      const en = AppStrings(AppLanguage.en);
      const vi = AppStrings(AppLanguage.vi);
      const zh = AppStrings(AppLanguage.zh);

      expect(en.fastScanBtnStart.contains('WizTree'), isFalse);
      expect(en.fastScanEngineNative.contains('WizTree'), isFalse);
      expect(vi.fastScanEngineNative.contains('WizTree'), isFalse);
      expect(zh.fastScanEngineNative.contains('WizTree'), isFalse);

      expect(en.fastScanBtnStart, 'Start Fast Scan');
      expect(vi.fastScanBtnStart, 'Bắt Đầu Quét Siêu Tốc');
      expect(zh.fastScanBtnStart, '开始极速扫描');

      expect(en.fastScanViewTree, 'Folder Tree');
      expect(vi.fastScanViewTree, 'Cây Thư Mục');
    });
  });

  group('FastScanService Unit Tests', () {
    test('FastScanService initializes without crashing', () {
      final service = FastScanService();
      expect(service.isScanning, isFalse);
      expect(service.currentResult, isNull);
      service.dispose();
    });
  });

  group('FastAnalyzerView Widget Tests', () {
    testWidgets('Renders FastAnalyzerView with empty state and start button', (
      tester,
    ) async {
      final service = FakeSymlinkService();
      final logic = SymlinkLogic(service);

      await tester.pumpWidget(
        buildTestWidget(
          child: FastAnalyzerView(logic: logic, onRefreshSymlinks: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Check header
      expect(find.byIcon(Icons.bolt_rounded), findsWidgets);
      // Check scan button
      expect(find.byIcon(Icons.flash_on_rounded), findsOneWidget);
      // Check view mode toggle pills
      expect(find.byIcon(Icons.account_tree_rounded), findsOneWidget);
      expect(find.byIcon(Icons.format_list_numbered_rounded), findsOneWidget);
    });
  });
}
