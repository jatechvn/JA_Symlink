// test/ui_visualizations_test.dart
// Unit and widget tests for Nhóm 4 UI/UX components: QuickCopyButton, EmptyStateCard, StorageDistributionChart, SystemHealthGauge

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_symlink/modules/i18n.dart';
import 'package:ja_symlink/modules/storage/storage_model.dart';
import 'package:ja_symlink/theme/theme_provider.dart';
import 'package:ja_symlink/widgets/empty_state_card.dart';
import 'package:ja_symlink/widgets/quick_copy_button.dart';
import 'package:ja_symlink/widgets/storage_distribution_chart.dart';
import 'package:ja_symlink/widgets/system_health_gauge.dart';
import 'package:ja_symlink/views/overview_view.dart';
import 'package:ja_symlink/modules/symlink_service.dart';

Widget _buildTestApp(Widget child, [AppLanguage language = AppLanguage.vi]) {
  final langNotifier = LanguageNotifier(language);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider(initialMode: 'dark')),
      ChangeNotifierProvider.value(value: langNotifier),
    ],
    child: LanguageProvider(
      notifier: langNotifier,
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  testWidgets('overview excludes removed history from health denominator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _buildTestApp(
        OverviewView(
          entries: [
            for (final status in [
              'ACTIVE',
              'ACTIVE',
              'ACTIVE',
              'DANGLING',
              'DANGLING',
              'REMOVED',
            ])
              SymlinkEntry(
                timestamp: '',
                linkPath: 'C:\\link',
                targetPath: 'D:\\target',
                backupPath: '-',
                status: status,
              ),
          ],
          isAdmin: true,
          onCreate: () {},
          onScan: () {},
          onVerify: () {},
          onSelectTab: (_) {},
        ),
      ),
    );
    final gauge = tester.widget<SystemHealthGauge>(
      find.byType(SystemHealthGauge),
    );
    expect(gauge.totalLinks, 5);
    expect(gauge.activeLinks, 3);
    expect(gauge.brokenCount, 2);
    expect(find.text('60%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final language in [AppLanguage.en, AppLanguage.zh]) {
    testWidgets('visualization messages localized in ${language.name}', (
      tester,
    ) async {
      final theme = ThemeProvider(initialMode: 'dark');
      final s = AppStrings(language);
      await tester.pumpWidget(
        _buildTestApp(
          StorageDistributionChart(
            savings: StorageSavingsSummary.empty,
            colors: theme.colors,
          ),
          language,
        ),
      );
      expect(find.text(s.distributionEmpty), findsOneWidget);
      expect(find.textContaining('Chưa có'), findsNothing);
      await tester.pumpWidget(
        _buildTestApp(
          SystemHealthGauge(
            totalLinks: 5,
            activeLinks: 3,
            brokenCount: 2,
            onVerify: () {},
            colors: theme.colors,
          ),
          language,
        ),
      );
      expect(find.text(s.healthBrokenDetails(2)), findsOneWidget);
      expect(find.textContaining('liên kết bị ngắt'), findsNothing);
    });
  }
  testWidgets('clipboard waits for success and handles failure', (
    tester,
  ) async {
    final result = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') await result.future;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final theme = ThemeProvider(initialMode: 'dark');
    await tester.pumpWidget(
      _buildTestApp(QuickCopyButton(textToCopy: 'test', colors: theme.colors)),
    );
    await tester.tap(find.byType(QuickCopyButton));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    result.completeError(PlatformException(code: 'clipboard_busy'));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('donut repaints redistribution with unchanged total', (
    tester,
  ) async {
    final theme = ThemeProvider(initialMode: 'dark');
    Widget chart(Map<String, int> drives) => _buildTestApp(
      StorageDistributionChart(
        colors: theme.colors,
        savings: StorageSavingsSummary(
          totalSavedBytes: 100,
          totalSavedOnCBytes: 100,
          activeLinkCount: 2,
          totalFileCount: 2,
          perDriveSavings: drives,
        ),
      ),
    );
    CustomPainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<CustomPainter>()
        .firstWhere((p) => p.runtimeType.toString() == '_DonutPainter');
    await tester.pumpWidget(chart({'D:': 75, 'E:': 25}));
    await tester.pump(const Duration(seconds: 1));
    final before = painter();
    await tester.pumpWidget(chart({'D:': 25, 'E:': 75}));
    expect(painter().shouldRepaint(before), isTrue);
  });

  group('QuickCopyButton Widget', () {
    testWidgets(
      'displays copy icon initially, checkmark on tap, and resets after delay',
      (tester) async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final theme = ThemeProvider(initialMode: 'dark');

        await tester.pumpWidget(
          _buildTestApp(
            QuickCopyButton(
              textToCopy: r'C:\Source\Path',
              colors: theme.colors,
            ),
          ),
        );

        // Initially copy icon
        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);

        // Tap to copy
        await tester.tap(find.byType(QuickCopyButton));
        await tester.pump(const Duration(milliseconds: 300));

        // Checkmark icon appears
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);

        // Advance past reset timer
        await tester.pump(const Duration(milliseconds: 1700));
        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
      },
    );
  });

  group('EmptyStateCard Widget', () {
    testWidgets('renders title, description, and triggers CTA on tap', (
      tester,
    ) async {
      final theme = ThemeProvider(initialMode: 'dark');
      bool actionTriggered = false;

      await tester.pumpWidget(
        _buildTestApp(
          EmptyStateCard(
            icon: Icons.search_off_rounded,
            title: 'Không tìm thấy kết quả',
            description: 'Thử đổi từ khóa tìm kiếm',
            buttonLabel: 'Đặt lại',
            onAction: () => actionTriggered = true,
            colors: theme.colors,
          ),
        ),
      );

      expect(find.text('Không tìm thấy kết quả'), findsOneWidget);
      expect(find.text('Thử đổi từ khóa tìm kiếm'), findsOneWidget);
      expect(find.text('Đặt lại'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);

      await tester.tap(find.text('Đặt lại'));
      expect(actionTriggered, isTrue);
    });
  });

  group('StorageDistributionChart Widget', () {
    testWidgets('renders empty notice when no savings data available', (
      tester,
    ) async {
      final theme = ThemeProvider(initialMode: 'dark');

      await tester.pumpWidget(
        _buildTestApp(
          StorageDistributionChart(
            savings: StorageSavingsSummary.empty,
            colors: theme.colors,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Chưa có dữ liệu phân bổ'), findsOneWidget);
    });

    testWidgets('renders donut and legend items when data is populated', (
      tester,
    ) async {
      final theme = ThemeProvider(initialMode: 'dark');
      const savings = StorageSavingsSummary(
        totalSavedBytes: 10737418240, // 10 GB
        totalSavedOnCBytes: 10737418240,
        activeLinkCount: 4,
        totalFileCount: 500,
        perDriveSavings: {
          'D:': 8053063680, // 75%
          'E:': 2684354560, // 25%
        },
      );

      await tester.pumpWidget(
        _buildTestApp(
          StorageDistributionChart(savings: savings, colors: theme.colors),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('D:'), findsOneWidget);
      expect(find.text('E:'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // 4 links in center
    });
  });

  group('SystemHealthGauge Widget', () {
    testWidgets('calculates 100% score for all healthy links', (tester) async {
      final theme = ThemeProvider(initialMode: 'dark');
      bool verifyCalled = false;

      await tester.pumpWidget(
        _buildTestApp(
          SystemHealthGauge(
            totalLinks: 5,
            activeLinks: 5,
            brokenCount: 0,
            onVerify: () => verifyCalled = true,
            colors: theme.colors,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('100%'), findsOneWidget);
      expect(find.byIcon(Icons.gpp_good_rounded), findsOneWidget);

      await tester.tap(find.text('Kiểm tra liên kết'));
      expect(verifyCalled, isTrue);
    });

    testWidgets('shows warning status when broken links exist', (tester) async {
      final theme = ThemeProvider(initialMode: 'dark');

      await tester.pumpWidget(
        _buildTestApp(
          SystemHealthGauge(
            totalLinks: 5,
            activeLinks: 3,
            brokenCount: 2,
            onVerify: () {},
            colors: theme.colors,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('60%'), findsOneWidget);
      expect(find.byIcon(Icons.gpp_maybe_rounded), findsOneWidget);
      expect(find.textContaining('2 liên kết bị ngắt'), findsOneWidget);
    });
  });
}
