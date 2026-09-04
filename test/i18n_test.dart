import 'package:flutter_test/flutter_test.dart';
import 'package:ja_symlink/modules/i18n.dart';

void main() {
  test('navigation labels follow the selected language', () {
    final en = AppStrings(AppLanguage.en);
    final zh = AppStrings(AppLanguage.zh);
    final vi = AppStrings(AppLanguage.vi);

    expect(en.navOverview, 'Overview');
    expect(en.navSymlinks, 'Symlinks');
    expect(en.navTools, 'Tools');
    expect(en.navGuide, 'User Guide');

    expect(zh.navOverview, '概览');
    expect(zh.navSymlinks, '符号链接');
    expect(zh.navTools, '工具');
    expect(zh.navGuide, '用户指南');

    expect(vi.navOverview, 'Tổng quan');
    expect(vi.navSymlinks, 'Danh sách');
    expect(vi.navTools, 'Công cụ');
    expect(vi.navGuide, 'Hướng dẫn');
  });
}
