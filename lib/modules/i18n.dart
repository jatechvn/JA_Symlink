// lib/modules/i18n.dart
// Multi-language support for JA_Symlink (English / 中文 / Tiếng Việt)
// Uses InheritedNotifier for context-based access from anywhere in the tree

import 'package:flutter/material.dart';
import 'app_config.dart';

// ─────────────────────────────────────────────
//  Language enum
// ─────────────────────────────────────────────

enum AppLanguage { en, zh, vi }

extension AppLanguageExt on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.en: return 'en';
      case AppLanguage.zh: return 'zh';
      case AppLanguage.vi: return 'vi';
    }
  }

  /// Short label displayed on the Globe button
  String get shortLabel {
    switch (this) {
      case AppLanguage.en: return 'EN';
      case AppLanguage.zh: return '中';
      case AppLanguage.vi: return 'VN';
    }
  }

  String get fullLabel {
    switch (this) {
      case AppLanguage.en: return 'English';
      case AppLanguage.zh: return '中文';
      case AppLanguage.vi: return 'Tiếng Việt';
    }
  }

  static AppLanguage fromCode(String code) {
    switch (code) {
      case 'zh': return AppLanguage.zh;
      case 'vi': return AppLanguage.vi;
      default:   return AppLanguage.en;
    }
  }

  AppLanguage get next {
    final values = AppLanguage.values;
    return values[(index + 1) % values.length];
  }
}

// ─────────────────────────────────────────────
//  AppStrings — all UI strings in 3 languages
// ─────────────────────────────────────────────

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  // ── Action bar ─────────────────────────────
  String get filterAll => _s('ALL', '全部', 'Tất cả');
  String get filterActive => _s('ACTIVE', '活动', 'Hoạt động');
  String get filterChanged => _s('CHANGED', '已变更', 'Đã thay đổi');
  String get filterRemoved => _s('REMOVED', '已移除', 'Đã xóa');

  String get btnCreate => _s('Create', '创建', 'Tạo');
  String get btnChange => _s('Change', '更改', 'Đổi');
  String get btnRemove => _s('Remove', '移除', 'Xóa');

  String get tooltipVerify => _s(
    'Verify symlinks & auto-fix CSV if targets changed',
    '验证符号链接并自动修复CSV',
    'Xác minh symlink & tự sửa CSV nếu target thay đổi',
  );
  String get tooltipScan    => _s('Scan system for existing symlinks', '扫描系统现有符号链接', 'Quét hệ thống tìm symlink hiện có');
  String get tooltipRefresh => _s('Refresh', '刷新', 'Làm mới');
  String get tooltipLanguage => _s('Language', '语言', 'Ngôn ngữ');

  String tooltipTheme(String modeName) =>
      _s('Theme: $modeName', '主题: $modeName', 'Giao diện: $modeName');

  String get themeDark  => _s('Dark',  '深色', 'Tối');
  String get themeLight => _s('Light', '浅色', 'Sáng');
  String get themeAuto  => _s('Auto',  '自动', 'Tự động');

  // ── Table headers ───────────────────────────
  String get colNum       => '#';
  String get colLinkPath  => _s('LINK PATH',   '链接路径',  'ĐƯỜNG LINK');
  String get colTarget    => _s('TARGET PATH',  '目标路径',  'ĐƯỜNG ĐÍCH');
  String get colBackup    => _s('BACKUP',       '备份',     'SAO LƯU');
  String get colStatus    => _s('STATUS',       '状态',     'TRẠNG THÁI');
  String get colTimestamp => _s('TIMESTAMP',    '时间戳',    'THỜI GIAN');

  // ── Empty state ─────────────────────────────
  String get emptyTitle    => _s('No symlinks found',             '未找到符号链接',         'Không tìm thấy symlink');
  String get emptySubtitle => _s('Click "Create" to add one',     '点击"创建"添加符号链接',  'Nhấn "Tạo" để thêm symlink mới');

  // ── Status bar ──────────────────────────────
  String get labelAdmin    => _s('Admin',    '管理员', 'Quản trị');
  String get labelStandard => _s('Standard', '标准',   'Thường');

  String activeCount(int n)  => _s('$n active symlinks', '$n 个活动链接', '$n symlink đang hoạt động');
  String totalSummary(int total, int active) =>
      _s('Total: $total | Active: $active', '总计: $total | 活动: $active', 'Tổng: $total | Đang hoạt động: $active');
  String scanFound(int n)    => _s('Found $n system symlinks', '找到 $n 个系统符号链接', 'Tìm thấy $n symlink hệ thống');
  String verifiedSummary(int ok, int fixed, int broken) =>
      _s('Verified: $ok OK, $fixed fixed, $broken issues',
         '已验证: $ok 正常, $fixed 已修复, $broken 问题',
         'Đã xác minh: $ok OK, $fixed đã sửa, $broken lỗi');

  // ── Loading / status messages ────────────────
  String get msgLoading    => _s('Loading...',                   '加载中...',     'Đang tải...');
  String get msgProcessing => _s('Processing...',                '处理中...',     'Đang xử lý...');
  String get msgCreating   => _s('Creating symlink...',          '正在创建...',   'Đang tạo symlink...');
  String get msgChanging   => _s('Changing symlink target...',   '正在更改...',   'Đang thay đổi target...');
  String get msgRemoving   => _s('Removing symlink...',          '正在移除...',   'Đang xóa symlink...');
  String get msgScanning   => _s('Scanning system...',           '正在扫描...',   'Đang quét hệ thống...');
  String get msgVerifying  => _s('Verifying symlinks...',        '正在验证...',   'Đang xác minh symlink...');

  // ── Error / warning messages ─────────────────
  String get errSelectActive => _s(
    'Select an active symlink first',
    '请先选择一个活动符号链接',
    'Hãy chọn một symlink đang hoạt động trước',
  );
  String get errOnlyChange => _s(
    'Can only change active symlinks',
    '只能更改活动符号链接',
    'Chỉ có thể thay đổi symlink đang hoạt động',
  );
  String get errOnlyRemove => _s(
    'Can only remove active symlinks',
    '只能移除活动符号链接',
    'Chỉ có thể xóa symlink đang hoạt động',
  );

  // ── Success messages ─────────────────────────
  String get msgCreateSuccess => _s('Symlink created successfully', '符号链接创建成功', 'Tạo symlink thành công');
  String get msgChangeSuccess => _s('Symlink target changed successfully', '符号链接目标更改成功', 'Thay đổi target symlink thành công');
  String get msgRemoveSuccess => _s('Symlink removed successfully', '符号链接已成功移除', 'Xóa symlink thành công');

  // ── Error Localizer Helper ───────────────────
  String localizeError(String englishMsg) {
    if (englishMsg.contains('Failed to move source directory')) {
      return _s('Failed to move source directory', '移动源目录失败', 'Di chuyển thư mục nguồn thất bại');
    }
    if (englishMsg.contains('Failed to backup source directory')) {
      return _s('Failed to backup source directory', '备份源目录失败', 'Sao lưu thư mục nguồn thất bại');
    }
    if (englishMsg.contains('Failed to create new symlink, rolled back')) {
      return _s('Failed to create new symlink, rolled back', '创建新符号链接失败，已回滚', 'Tạo symlink mới thất bại, đã khôi phục');
    }
    if (englishMsg.contains('Path is not a symlink')) {
      return _s('Path is not a symlink', '路径不是符号链接', 'Đường dẫn không phải là symlink');
    }
    if (englishMsg.contains('Failed to remove old symlink')) {
      return _s('Failed to remove old symlink', '删除旧符号链接失败', 'Xóa symlink cũ thất bại');
    }
    if (englishMsg.contains('Cannot read current symlink target')) {
      return _s('Cannot read current symlink target', '无法读取当前符号链接目标', 'Không thể đọc target symlink hiện tại');
    }
    if (englishMsg.contains('Failed to move data to new target')) {
      return _s('Failed to move data to new target', '移动数据到新目标失败', 'Di chuyển dữ liệu đến target mới thất bại');
    }
    if (englishMsg.contains('Unexpected error')) {
      return _s('Unexpected error', '意外错误', 'Lỗi không xác định');
    }
    return englishMsg; // fallback
  }

  // ── Browse button ────────────────────────────
  String get btnBrowse => _s('Browse', '浏览', 'Duyệt');
  String get btnCancel => _s('Cancel', '取消',  'Hủy');
  String get btnClose  => _s('Close',  '关闭',  'Đóng');

  // ── Create Dialog ────────────────────────────
  String get dlgCreateTitle => _s('Create Symlink',  '创建符号链接',  'Tạo Symlink');
  String get dlgCreateDesc  => _s(
    'Create a directory symbolic link. The source folder will be moved/backed up and replaced with a link to the target.',
    '创建目录符号链接。源文件夹将被移动/备份，并替换为指向目标的链接。',
    'Tạo symbolic link thư mục. Thư mục nguồn sẽ được di chuyển/sao lưu và thay bằng link trỏ đến đích.',
  );
  String get labelSourcePath  => _s('Source Path (Link Location)',  '源路径（链接位置）',  'Đường dẫn nguồn (vị trí link)');
  String get hintSourcePath   => 'e.g. C:\\Users\\V\\AppData\\Roaming\\AppName';
  String get labelTargetFolder => _s('Target Parent Folder',        '目标父文件夹',       'Thư mục đích cha');
  String get hintTargetFolder  => _s(
    'e.g. A:\\DATA (app name auto-appended)',
    '例如 A:\\DATA（自动追加应用名）',
    'vd. A:\\DATA (tự động thêm tên app)',
  );
  String get labelFinal       => _s('Final: ', '最终路径: ', 'Đường dẫn cuối: ');
  String get labelOptions     => _s('Options',  '选项',      'Tùy chọn');
  String get optMoveData      => _s('Move data to target',       '移动数据到目标',   'Di chuyển dữ liệu đến đích');
  String get optMoveDataSub   => _s(
    'Move source folder contents to target location',
    '将源文件夹内容移动到目标位置',
    'Di chuyển nội dung thư mục nguồn đến đích',
  );
  String get optKillProc      => _s('Kill locking processes',         '结束锁定进程',           'Kết thúc tiến trình khóa');
  String get optKillProcSub   => _s(
    'Terminate processes using the source folder',
    '终止正在使用源文件夹的进程',
    'Kết thúc tiến trình đang dùng thư mục nguồn',
  );
  String get btnCreateSymlink => _s('Create Symlink', '创建符号链接', 'Tạo Symlink');
  String get errFillPaths     => _s(
    'Please fill in both paths',
    '请填写两个路径',
    'Vui lòng điền đầy đủ cả hai đường dẫn',
  );

  // ── Change Dialog ────────────────────────────
  String get dlgChangeTitle   => _s('Change Symlink Target', '更改符号链接目标', 'Thay Đổi Target Symlink');
  String get labelCurrSymlink => _s('Current Symlink',         '当前符号链接',   'Symlink hiện tại');
  String get labelNewTarget   => _s('New Target Parent Folder', '新目标父文件夹', 'Thư mục đích mới');
  String hintNewTarget(String appName) => _s(
    'e.g. D:\\Data ("$appName" auto-appended)',
    '例如 D:\\Data（自动追加"$appName"）',
    'vd. D:\\Data (tự động thêm "$appName")',
  );
  String get optMoveDataNew    => _s('Move data to new target',        '将数据移动到新目标',          'Di chuyển dữ liệu đến đích mới');
  String get optMoveDataNewSub => _s(
    'Use robocopy /MOVE to transfer data from old target',
    '使用 robocopy /MOVE 从旧目标传输数据',
    'Dùng robocopy /MOVE để chuyển dữ liệu từ đích cũ',
  );
  String get btnChangeTarget  => _s('Change Target', '更改目标', 'Thay Đổi Đích');
  String get errEnterTarget   => _s(
    'Please enter the new target path',
    '请输入新目标路径',
    'Vui lòng nhập đường dẫn đích mới',
  );

  // ── Remove Dialog ────────────────────────────
  String get dlgRemoveTitle   => _s('Remove Symlink',  '移除符号链接', 'Xóa Symlink');
  String get warnRemove => _s(
    'This will remove the symbolic link. Data at the target will NOT be deleted.',
    '此操作将移除符号链接。目标处的数据不会被删除。',
    'Thao tác này sẽ xóa symbolic link. Dữ liệu tại đích sẽ KHÔNG bị xóa.',
  );
  String get optRestoreBackup    => _s('Restore original backup',             '恢复原始备份',       'Khôi phục bản sao lưu gốc');
  String get optRestoreBackupSub => _s(
    'Move backup data back to the original location',
    '将备份数据移回原始位置',
    'Di chuyển dữ liệu sao lưu về vị trí ban đầu',
  );
  String get btnRemoveConfirm => _s('Remove', '移除', 'Xóa');

  // ── Scan Dialog ──────────────────────────────
  String scanTitle(int n) => _s('System Symlinks Found ($n)', '找到系统符号链接 ($n)', 'Tìm Thấy Symlink Hệ Thống ($n)');
  String get scanEmpty    => _s('No symlinks found',          '未找到符号链接',         'Không tìm thấy symlink');
  String get badgeUntracked => _s('System / External', '系统 / 未跟踪', 'Hệ thống / Ngoài danh sách');
  String get badgeTracked   => _s('Tracked', '已跟踪', 'Đã theo dõi');

  // ── Verify Dialog ────────────────────────────
  String get dlgVerifyTitle  => _s('Verify Results',             '验证结果',             'Kết Quả Xác Minh');
  String get verifyEmpty     => _s('No active symlinks to verify','没有活动符号链接可验证', 'Không có symlink nào để xác minh');
  String verifyFixedMsg(int n) => _s('$n entries auto-fixed ✓',  '$n 条目已自动修复 ✓',  '$n mục đã tự sửa ✓');
  String get labelCsvTarget => _s('CSV: ', 'CSV: ', 'CSV: ');
  String get labelActualTarget => _s('NOW: ', '当前: ', 'HIỆN TẠI: ');

  // ── Import/Export ────────────────────────────
  String get tooltipImport => _s('Import symlinks configuration', '导入符号链接配置', 'Nhập cấu hình symlinks');
  String get tooltipExport => _s('Export symlinks configuration', '导出符号链接配置', 'Xuất cấu hình symlinks');
  String get msgExportSuccess => _s('Symlinks exported successfully', '符号链接配置已成功导出', 'Xuất cấu hình symlinks thành công');
  String get errImportFailed => _s('Failed to import symlinks', '导入符号链接失败', 'Nhập cấu hình symlinks thất bại');
  String get dlgImportTitle => _s('Import Results', '导入结果', 'Kết Quả Nhập Cấu Hình');
  String importSummaryMsg(int success, int skipped, int failed) =>
      _s('Import completed:\n- $success restored successfully\n- $skipped skipped\n- $failed failed',
         '导入完成:\n- $success 成功恢复\n- $skipped 已跳过\n- $failed 失败',
         'Nhập hoàn tất:\n- $success khôi phục thành công\n- $skipped bỏ qua\n- $failed thất bại');

  String get menuVerify => _s('Verify Symlinks', '验证符号链接', 'Xác minh Symlink');
  String get menuScan => _s('Scan System', '扫描系统', 'Quét hệ thống');
  String get menuImport => _s('Import Config', '导入配置', 'Nhập cấu hình');
  String get menuExport => _s('Export Config', '导出配置', 'Xuất cấu hình');
  String get menuGuide => _s('User Guide', '用户指南', 'Hướng dẫn sử dụng');
  String get btnMore => _s('Advanced', '高级', 'Nâng cao');

  String get dlgGuideTitle => _s('JA Symlink - User Guide', 'JA Symlink - 用户指南', 'JA Symlink - Hướng Dẫn Sử Dụng');

  String get guideTabGeneral => _s('General', '简介', 'Giới thiệu chung');
  String get guideTabOps => _s('Operations', '基础操作', 'Thao tác cơ bản');
  String get guideTabAdv => _s('Advanced', '高级功能', 'Tính năng nâng cao');
  String get guideTabSafety => _s('Safety', '安全性', 'An toàn & Phục hồi');

  String get guideGenTitle => _s('Introduction', '简介', 'Giới thiệu chung');
  String get guideGenContent => _s(
    'JA Symlink Manager helps you relocate disk space by moving directories from your primary drive (e.g. SSD C:) to other drives (e.g. HDD D:, A:) and creating symbolic links (Symlinks) in their original places. Windows programs will still think the files are in their original location.\n\nIMPORTANT: Since creating symbolic links is a system-level operation, this app automatically requests Administrator privileges on startup.',
    'JA Symlink Manager 帮助您将目录从主驱动器（例如 SSD C:）移动到其他驱动器（例如 HDD D:、A:）并在其原始位置创建符号链接（Symlinks），从而重新分配磁盘空间。Windows 程序仍会认为文件位于其原始位置。\n\n重要提示：由于创建符号链接是系统级操作，此应用在启动时会自动请求管理员权限。',
    'JA Symlink Manager giúp bạn giải phóng dung lượng ổ đĩa bằng cách di chuyển các thư mục từ ổ đĩa chính (ví dụ: SSD C:) sang các ổ đĩa khác (ví dụ: HDD D:, A:) và tạo các symbolic link (Symlink) tại vị trí ban đầu. Các chương trình Windows vẫn sẽ nhận diện dữ liệu đang nằm ở thư mục gốc.\n\nQUAN TRỌNG: Vì tạo symbolic link là một thao tác can thiệp hệ thống, ứng dụng này sẽ tự động yêu cầu quyền Administrator khi khởi chạy.'
  );

  String get guideOpsTitle => _s('Basic Operations', '基础操作', 'Thao tác cơ bản');
  String get guideOpsContent => _s(
    '• CREATE SYMLINK: Moves a directory to the target drive and replaces the original with a link.\n\n• CHANGE TARGET: Safely redirects an existing link to a new target drive.\n\n• REMOVE SYMLINK: Deletes the link without deleting your target data. You can restore the original folder from backup if needed.',
    '• 创建符号链接：将目录移动到目标驱动器，并将原始目录替换为链接。\n\n• 更改目标：将现有链接安全地重定向到新的目标驱动器。\n\n• 移除符号链接：删除链接而不删除您的目标数据。如果需要，您可以从备份恢复原始文件夹。',
    '• TẠO SYMLINK: Di chuyển một thư mục đến ổ đĩa đích và thay thế thư mục gốc bằng một liên kết.\n\n• THAY ĐỔI ĐÍCH: Chuyển hướng một liên kết đang hoạt động sang một ổ đĩa đích mới một cách an toàn.\n\n• XÓA SYMLINK: Xóa liên kết symlink mà KHÔNG xóa dữ liệu đích. Bạn có thể khôi phục lại thư mục gốc từ bản sao lưu nếu muốn.'
  );

  String get guideAdvTitle => _s('Advanced Features', '高级功能', 'Tính năng nâng cao');
  String get guideAdvContent => _s(
    '• VERIFY SYMLINKS: Checks the status of all active links and automatically fixes them in the history if changed externally.\n\n• SCAN SYSTEM: Scans common paths for existing symlinks, highlighting system-created or external links in orange.\n\n• IMPORT & EXPORT: Backs up your symlink configuration to a JSON file to easily restore them on a new Windows installation.',
    '• 验证符号链接：检查所有活动链接的状态，如果外部发生更改，则自动在历史记录中修复它们。\n\n• 扫描系统：扫描常见路径以查找现有符号链接，用橙色突出显示系统创建或外部链接。\n\n• 导入和导出：将您的符号链接配置备份到 JSON 文件，以便在新 Windows 安装上轻松恢复它们。',
    '• XÁC MINH SYMLINK: Kiểm tra trạng thái của tất cả liên kết đang hoạt động và tự động sửa lịch sử nếu đích đã thay đổi bên ngoài.\n\n• QUÉT HỆ THỐNG: Quét đệ quy các đường dẫn phổ biến để tìm symlink hiện có, làm nổi bật các liên kết hệ thống/ngoài danh sách bằng màu cam.\n\n• NHẬP & XUẤT CẤU HÌNH: Sao lưu danh sách symlink sang một file JSON để dễ dàng khôi phục lại khi cài đặt lại Windows.'
  );

  String get guideSafetyTitle => _s('Safety & Recovery', '安全性', 'An toàn & Phục hồi');
  String get guideSafetyContent => _s(
    '• SAFE COPY: Uses a robust Copy-Before-Delete copy stream with real-time percentage progress. If the copy fails (disk full/no permissions), it automatically rolls back, leaving your original data intact.\n\n• CRASH RECOVERY: If a copy is interrupted due to a system crash, opening the app again will automatically detect the transaction and clean up or recover files safely.',
    '• 安全复制：使用健壮的 Copy-Before-Delete 复制流，具有实时百分比进度。如果复制失败（磁盘已满/无权限）， it会自动回滚，保持您的原始数据完整。\n\n• 崩溃恢复：如果复制由于系统崩溃而中断，再次打开应用将自动检测该事务并安全地清理或恢复文件。',
    '• SAO CHÉP AN TOÀN: Sử dụng luồng sao chép (Copy-Before-Delete) có hiển thị phần trăm dung lượng. Nếu sao chép thất bại (ổ đầy/không đủ quyền), ứng dụng sẽ tự động hoàn tác (rollback) giữ nguyên thư mục gốc.\n\n• TỰ PHỤC HỒI SỰ CỐ: Nếu quá trình sao chép bị ngắt giữa chừng do mất điện/crash, khi mở lại ứng dụng sẽ tự động phát hiện và khôi phục hoặc dọn dẹp các tệp tin lỗi một cách an toàn.'
  );

  // ── Internal helper ──────────────────────────
  String _s(String en, String zh, String vi) {
    switch (lang) {
      case AppLanguage.en: return en;
      case AppLanguage.zh: return zh;
      case AppLanguage.vi: return vi;
    }
  }
}

// ─────────────────────────────────────────────
//  LanguageNotifier — state management
// ─────────────────────────────────────────────

class LanguageNotifier extends ChangeNotifier {
  AppLanguage _lang;

  LanguageNotifier(this._lang);

  AppLanguage get language => _lang;
  AppStrings  get strings  => AppStrings(_lang);

  void setLanguage(AppLanguage lang) {
    if (_lang == lang) return;
    _lang = lang;
    AppConfig.set('language', lang.code); // persist immediately
    notifyListeners();
  }

  void cycleNext() => setLanguage(_lang.next);
}

// ─────────────────────────────────────────────
//  LanguageProvider — InheritedNotifier wrapper
// ─────────────────────────────────────────────

class LanguageProvider extends InheritedNotifier<LanguageNotifier> {
  const LanguageProvider({
    super.key,
    required super.notifier,
    required super.child,
  });

  static LanguageNotifier of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<LanguageProvider>();
    assert(provider != null, 'No LanguageProvider found above this context');
    return provider!.notifier!;
  }
}

// ─────────────────────────────────────────────
//  BuildContext extension
// ─────────────────────────────────────────────

extension BuildContextI18n on BuildContext {
  AppStrings      get strings          => LanguageProvider.of(this).strings;
  LanguageNotifier get languageNotifier => LanguageProvider.of(this);
}
