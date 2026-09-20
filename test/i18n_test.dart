import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/i18n.dart';

void main() {
  test('navigation labels follow the selected language', () {
    const en = AppStrings(AppLanguage.en);
    const zh = AppStrings(AppLanguage.zh);
    const vi = AppStrings(AppLanguage.vi);

    expect(en.navOverview, 'Overview');
    expect(en.navRelocator, 'Free Up C:');
    expect(en.navSymlinks, 'Symlinks');
    expect(en.navFastScan, 'Fast Scan');
    expect(en.navTools, 'Tools');
    expect(en.navGuide, 'User Guide');

    expect(zh.navOverview, '概览');
    expect(zh.navRelocator, '释放C盘');
    expect(zh.navSymlinks, '符号链接');
    expect(zh.navFastScan, '极速分析');
    expect(zh.navTools, '工具');
    expect(zh.navGuide, '用户指南');

    expect(vi.navOverview, 'Tổng quan');
    expect(vi.navRelocator, 'Dọn Ổ C');
    expect(vi.navSymlinks, 'Danh sách');
    expect(vi.navFastScan, 'Quét nhanh');
    expect(vi.navTools, 'Công cụ');
    expect(vi.navGuide, 'Hướng dẫn');
  });
}
