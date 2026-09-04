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
      case AppLanguage.en:
        return 'en';
      case AppLanguage.zh:
        return 'zh';
      case AppLanguage.vi:
        return 'vi';
    }
  }

  /// Short label displayed on the Globe button
  String get shortLabel {
    switch (this) {
      case AppLanguage.en:
        return 'EN';
      case AppLanguage.zh:
        return '中';
      case AppLanguage.vi:
        return 'VN';
    }
  }

  String get fullLabel {
    switch (this) {
      case AppLanguage.en:
        return 'English';
      case AppLanguage.zh:
        return '中文';
      case AppLanguage.vi:
        return 'Tiếng Việt';
    }
  }

  static AppLanguage fromCode(String code) {
    switch (code) {
      case 'zh':
        return AppLanguage.zh;
      case 'vi':
        return AppLanguage.vi;
      default:
        return AppLanguage.en;
    }
  }

  AppLanguage get next {
    const values = AppLanguage.values;
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
  String get tooltipScan => _s(
    'Scan system for existing symlinks',
    '扫描系统现有符号链接',
    'Quét hệ thống tìm symlink hiện có',
  );
  String get tooltipRefresh => _s('Refresh', '刷新', 'Làm mới');
  String get tooltipLanguage => _s('Language', '语言', 'Ngôn ngữ');

  String tooltipTheme(String modeName) =>
      _s('Theme: $modeName', '主题: $modeName', 'Giao diện: $modeName');

  String get themeDark => _s('Dark', '深色', 'Tối');
  String get themeLight => _s('Light', '浅色', 'Sáng');
  String get themeAuto => _s('Auto', '自动', 'Tự động');

  // ── Table headers ───────────────────────────
  String get colNum => '#';
  String get colLinkPath => _s('LINK PATH', '链接路径', 'ĐƯỜNG LINK');
  String get colTarget => _s('TARGET PATH', '目标路径', 'ĐƯỜNG ĐÍCH');
  String get colBackup => _s('BACKUP', '备份', 'SAO LƯU');
  String get colStatus => _s('STATUS', '状态', 'TRẠNG THÁI');
  String get colTimestamp => _s('TIMESTAMP', '时间戳', 'THỜI GIAN');

  // ── Empty state ─────────────────────────────
  String get emptyTitle =>
      _s('No symlinks found', '未找到符号链接', 'Không tìm thấy symlink');
  String get emptySubtitle => _s(
    'Click "Create" to add one',
    '点击"创建"添加符号链接',
    'Nhấn "Tạo" để thêm symlink mới',
  );

  // ── Status bar ──────────────────────────────
  String get labelAdmin => _s('Admin', '管理员', 'Quản trị');
  String get labelStandard => _s('Standard', '标准', 'Thường');

  String activeCount(int n) =>
      _s('$n active symlinks', '$n 个活动链接', '$n symlink đang hoạt động');
  String totalSummary(int total, int active) => _s(
    'Total: $total | Active: $active',
    '总计: $total | 活动: $active',
    'Tổng: $total | Đang hoạt động: $active',
  );
  String scanFound(int n) => _s(
    'Found $n system symlinks',
    '找到 $n 个系统符号链接',
    'Tìm thấy $n symlink hệ thống',
  );
  String verifiedSummary(int ok, int fixed, int broken) => _s(
    'Verified: $ok OK, $fixed fixed, $broken issues',
    '已验证: $ok 正常, $fixed 已修复, $broken 问题',
    'Đã xác minh: $ok OK, $fixed đã sửa, $broken lỗi',
  );

  // ── Loading / status messages ────────────────
  String get msgLoading => _s('Loading...', '加载中...', 'Đang tải...');
  String get msgProcessing => _s('Processing...', '处理中...', 'Đang xử lý...');
  String get msgCreating =>
      _s('Creating symlink...', '正在创建...', 'Đang tạo symlink...');
  String get msgChanging =>
      _s('Changing symlink target...', '正在更改...', 'Đang thay đổi target...');
  String get msgRemoving =>
      _s('Removing symlink...', '正在移除...', 'Đang xóa symlink...');
  String get msgScanning =>
      _s('Scanning system...', '正在扫描...', 'Đang quét hệ thống...');
  String get msgVerifying =>
      _s('Verifying symlinks...', '正在验证...', 'Đang xác minh symlink...');

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
  String get msgCreateSuccess =>
      _s('Symlink created successfully', '符号链接创建成功', 'Tạo symlink thành công');
  String get msgChangeSuccess => _s(
    'Symlink target changed successfully',
    '符号链接目标更改成功',
    'Thay đổi target symlink thành công',
  );
  String get msgRemoveSuccess =>
      _s('Symlink removed successfully', '符号链接已成功移除', 'Xóa symlink thành công');

  // ── Error Localizer Helper ───────────────────
  String localizeError(String englishMsg) {
    if (englishMsg.contains('Failed to move source directory')) {
      return _s(
        'Failed to move source directory',
        '移动源目录失败',
        'Di chuyển thư mục nguồn thất bại',
      );
    }
    if (englishMsg.contains('Failed to backup source directory')) {
      return _s(
        'Failed to backup source directory',
        '备份源目录失败',
        'Sao lưu thư mục nguồn thất bại',
      );
    }
    if (englishMsg.contains('Failed to create new symlink, rolled back')) {
      return _s(
        'Failed to create new symlink, rolled back',
        '创建新符号链接失败，已回滚',
        'Tạo symlink mới thất bại, đã khôi phục',
      );
    }
    if (englishMsg.contains('Path is not a symlink')) {
      return _s(
        'Path is not a symlink',
        '路径不是符号链接',
        'Đường dẫn không phải là symlink',
      );
    }
    if (englishMsg.contains('Failed to remove old symlink')) {
      return _s(
        'Failed to remove old symlink',
        '删除旧符号链接失败',
        'Xóa symlink cũ thất bại',
      );
    }
    if (englishMsg.contains('Cannot read current symlink target')) {
      return _s(
        'Cannot read current symlink target',
        '无法读取当前符号链接目标',
        'Không thể đọc target symlink hiện tại',
      );
    }
    if (englishMsg.contains('Failed to move data to new target')) {
      return _s(
        'Failed to move data to new target',
        '移动数据到新目标失败',
        'Di chuyển dữ liệu đến target mới thất bại',
      );
    }
    if (englishMsg.contains('Source and target paths are required')) {
      return _s(
        'Source and target paths are required',
        '源路径和目标路径不能为空',
        'Cần có đường dẫn nguồn và đường dẫn đích',
      );
    }
    if (englishMsg.contains('Link and target paths are required')) {
      return _s(
        'Link and target paths are required',
        '链接路径和目标路径不能为空',
        'Cần có đường dẫn link và đường dẫn đích',
      );
    }
    if (englishMsg.contains('Target path cannot be the source folder')) {
      return _s(
        'Target path cannot be the source folder or a child folder',
        '目标路径不能是源文件夹或其子文件夹',
        'Đường dẫn đích không thể là thư mục nguồn hoặc thư mục con',
      );
    }
    if (englishMsg.contains('Destination cannot be the source folder')) {
      return _s(
        'Destination cannot be the source folder or its child',
        '目标不能是源文件夹或其子文件夹',
        'Đích không thể là thư mục nguồn hoặc thư mục con',
      );
    }
    if (englishMsg.contains('Path is already a symlink')) {
      return _s(
        'Path is already a symlink',
        '路径已经是符号链接',
        'Đường dẫn đã là symlink',
      );
    }
    if (englishMsg.contains('New target must be different')) {
      return _s(
        'New target must be different from the current target',
        '新目标必须不同于当前目标',
        'Đích mới phải khác đích hiện tại',
      );
    }
    if (englishMsg.contains('New target cannot be inside')) {
      return _s(
        'New target cannot be inside the current target folder',
        '新目标不能位于当前目标文件夹内',
        'Đích mới không thể nằm trong thư mục đích hiện tại',
      );
    }
    if (englishMsg.contains('Failed to copy source files')) {
      return _s(
        'Failed to copy source files',
        '复制源文件失败',
        'Sao chép tệp nguồn thất bại',
      );
    }
    if (englishMsg.contains('Failed to copy files to new target')) {
      return _s(
        'Failed to copy files to new target',
        '复制文件到新目标失败',
        'Sao chép tệp đến đích mới thất bại',
      );
    }
    if (englishMsg.contains('Failed to backup source folder')) {
      return _s(
        'Failed to backup source folder',
        '备份源文件夹失败',
        'Sao lưu thư mục nguồn thất bại',
      );
    }
    if (englishMsg.contains('Symlink verification failed')) {
      return _s(
        'Symlink verification failed',
        '符号链接验证失败',
        'Xác minh symlink thất bại',
      );
    }
    if (englishMsg.contains('Failed to export symlinks')) {
      return _s(
        'Failed to export symlinks',
        '导出符号链接失败',
        'Xuất cấu hình symlink thất bại',
      );
    }
    if (englishMsg.contains('Symlink removed, but backup restore failed')) {
      return _s(
        'Symlink removed, but backup restore failed',
        '符号链接已移除，但备份恢复失败',
        'Đã xóa symlink nhưng khôi phục bản sao lưu thất bại',
      );
    }
    if (englishMsg.contains('history logging failed')) {
      return _s(
        englishMsg,
        '操作已完成，但历史记录写入失败',
        'Đã hoàn tất thao tác nhưng ghi lịch sử thất bại',
      );
    }
    if (englishMsg.startsWith('Error:')) {
      return '${_s('Error:', '错误：', 'Lỗi:')}${englishMsg.substring('Error:'.length)}';
    }
    if (englishMsg.startsWith('Move error:')) {
      return '${_s('Move error:', '移动错误：', 'Lỗi di chuyển:')}${englishMsg.substring('Move error:'.length)}';
    }
    if (englishMsg.contains('Unexpected error')) {
      return _s('Unexpected error', '意外错误', 'Lỗi không xác định');
    }
    return englishMsg; // fallback
  }

  // ── Browse button ────────────────────────────
  String get btnBrowse => _s('Browse', '浏览', 'Duyệt');
  String get btnCancel => _s('Cancel', '取消', 'Hủy');
  String get btnClose => _s('Close', '关闭', 'Đóng');

  // ── Create Dialog ────────────────────────────
  String get dlgCreateTitle => _s('Create Symlink', '创建符号链接', 'Tạo Symlink');
  String get dlgCreateDesc => _s(
    'Create a directory symbolic link. The source folder will be moved/backed up and replaced with a link to the target.',
    '创建目录符号链接。源文件夹将被移动/备份，并替换为指向目标的链接。',
    'Tạo symbolic link thư mục. Thư mục nguồn sẽ được di chuyển/sao lưu và thay bằng link trỏ đến đích.',
  );
  String get labelSourcePath => _s(
    'Source Path (Link Location)',
    '源路径（链接位置）',
    'Đường dẫn nguồn (vị trí link)',
  );
  String get hintSourcePath => 'e.g. C:\\Users\\V\\AppData\\Roaming\\AppName';
  String get labelTargetFolder =>
      _s('Target Parent Folder', '目标父文件夹', 'Thư mục đích cha');
  String get hintTargetFolder => _s(
    'e.g. A:\\DATA (app name auto-appended)',
    '例如 A:\\DATA（自动追加应用名）',
    'vd. A:\\DATA (tự động thêm tên app)',
  );
  String get labelFinal => _s('Final: ', '最终路径: ', 'Đường dẫn cuối: ');
  String get labelOptions => _s('Options', '选项', 'Tùy chọn');
  String get optMoveData =>
      _s('Move data to target', '移动数据到目标', 'Di chuyển dữ liệu đến đích');
  String get optMoveDataSub => _s(
    'Move source folder contents to target location',
    '将源文件夹内容移动到目标位置',
    'Di chuyển nội dung thư mục nguồn đến đích',
  );
  String get optKillProc =>
      _s('Kill locking processes', '结束锁定进程', 'Kết thúc tiến trình khóa');
  String get optKillProcSub => _s(
    'Terminate processes using the source folder',
    '终止正在使用源文件夹的进程',
    'Kết thúc tiến trình đang dùng thư mục nguồn',
  );
  String get btnCreateSymlink => _s('Create Symlink', '创建符号链接', 'Tạo Symlink');
  String get errFillPaths => _s(
    'Please fill in both paths',
    '请填写两个路径',
    'Vui lòng điền đầy đủ cả hai đường dẫn',
  );

  // ── Change Dialog ────────────────────────────
  String get dlgChangeTitle =>
      _s('Change Symlink Target', '更改符号链接目标', 'Thay Đổi Target Symlink');
  String get labelCurrSymlink =>
      _s('Current Symlink', '当前符号链接', 'Symlink hiện tại');
  String get labelNewTarget =>
      _s('New Target Parent Folder', '新目标父文件夹', 'Thư mục đích mới');
  String hintNewTarget(String appName) => _s(
    'e.g. D:\\Data ("$appName" auto-appended)',
    '例如 D:\\Data（自动追加"$appName"）',
    'vd. D:\\Data (tự động thêm "$appName")',
  );
  String get optMoveDataNew => _s(
    'Move data to new target',
    '将数据移动到新目标',
    'Di chuyển dữ liệu đến đích mới',
  );
  String get optMoveDataNewSub => _s(
    'Use robocopy /MOVE to transfer data from old target',
    '使用 robocopy /MOVE 从旧目标传输数据',
    'Dùng robocopy /MOVE để chuyển dữ liệu từ đích cũ',
  );
  String get btnChangeTarget => _s('Change Target', '更改目标', 'Thay Đổi Đích');
  String get errEnterTarget => _s(
    'Please enter the new target path',
    '请输入新目标路径',
    'Vui lòng nhập đường dẫn đích mới',
  );

  // ── Remove Dialog ────────────────────────────
  String get dlgRemoveTitle => _s('Remove Symlink', '移除符号链接', 'Xóa Symlink');
  String get warnRemove => _s(
    'This will remove the symbolic link. Data at the target will NOT be deleted.',
    '此操作将移除符号链接。目标处的数据不会被删除。',
    'Thao tác này sẽ xóa symbolic link. Dữ liệu tại đích sẽ KHÔNG bị xóa.',
  );
  String get optRestoreBackup =>
      _s('Restore original backup', '恢复原始备份', 'Khôi phục bản sao lưu gốc');
  String get optRestoreBackupSub => _s(
    'Move backup data back to the original location',
    '将备份数据移回原始位置',
    'Di chuyển dữ liệu sao lưu về vị trí ban đầu',
  );
  String get btnRemoveConfirm => _s('Remove', '移除', 'Xóa');

  // ── Scan Dialog ──────────────────────────────
  String scanTitle(int n) => _s(
    'System Symlinks Found ($n)',
    '找到系统符号链接 ($n)',
    'Tìm Thấy Symlink Hệ Thống ($n)',
  );
  String get scanEmpty =>
      _s('No symlinks found', '未找到符号链接', 'Không tìm thấy symlink');
  String get badgeUntracked =>
      _s('System / External', '系统 / 未跟踪', 'Hệ thống / Ngoài danh sách');
  String get badgeTracked => _s('Tracked', '已跟踪', 'Đã theo dõi');

  // ── Verify Dialog ────────────────────────────
  String get dlgVerifyTitle => _s('Verify Results', '验证结果', 'Kết Quả Xác Minh');
  String get verifyEmpty => _s(
    'No active symlinks to verify',
    '没有活动符号链接可验证',
    'Không có symlink nào để xác minh',
  );
  String verifyFixedMsg(int n) =>
      _s('$n entries auto-fixed ✓', '$n 条目已自动修复 ✓', '$n mục đã tự sửa ✓');
  String get labelCsvTarget => _s('CSV: ', 'CSV: ', 'CSV: ');
  String get labelActualTarget => _s('NOW: ', '当前: ', 'HIỆN TẠI: ');

  // ── Import/Export ────────────────────────────
  String get tooltipImport =>
      _s('Import symlinks configuration', '导入符号链接配置', 'Nhập cấu hình symlinks');
  String get tooltipExport =>
      _s('Export symlinks configuration', '导出符号链接配置', 'Xuất cấu hình symlinks');
  String get msgExportSuccess => _s(
    'Symlinks exported successfully',
    '符号链接配置已成功导出',
    'Xuất cấu hình symlinks thành công',
  );
  String get errImportFailed => _s(
    'Failed to import symlinks',
    '导入符号链接失败',
    'Nhập cấu hình symlinks thất bại',
  );
  String get dlgImportTitle =>
      _s('Import Results', '导入结果', 'Kết Quả Nhập Cấu Hình');
  String importSummaryMsg(int success, int skipped, int failed) => _s(
    'Import completed:\n- $success restored successfully\n- $skipped skipped\n- $failed failed',
    '导入完成:\n- $success 成功恢复\n- $skipped 已跳过\n- $failed 失败',
    'Nhập hoàn tất:\n- $success khôi phục thành công\n- $skipped bỏ qua\n- $failed thất bại',
  );

  String get menuVerify => _s('Verify Symlinks', '验证符号链接', 'Xác minh Symlink');
  String get menuScan => _s('Scan System', '扫描系统', 'Quét hệ thống');
  String get menuImport => _s('Import Config', '导入配置', 'Nhập cấu hình');
  String get menuExport => _s('Export Config', '导出配置', 'Xuất cấu hình');
  String get menuGuide => _s('User Guide', '用户指南', 'Hướng dẫn sử dụng');
  String get btnMore => _s('Advanced', '高级', 'Nâng cao');

  // ── Shared navigation and UI labels ──────────
  String get navOverview => _s('Overview', '概览', 'Tổng quan');
  String get navSymlinks => _s('Symlinks', '符号链接', 'Danh sách');
  String get navTools => _s('Tools', '工具', 'Công cụ');
  String get navGuide => _s('User Guide', '用户指南', 'Hướng dẫn');
  String activeBadge(int n) => _s('$n ACTIVE', '$n 活动', '$n HOẠT ĐỘNG');
  String get standardShort => _s('STD', '标准', 'THƯỜNG');
  String get spotlightTooltip => _s(
    'Spotlight Search (Ctrl+K)',
    '聚光灯搜索 (Ctrl+K)',
    'Tìm kiếm nhanh (Ctrl+K)',
  );
  String get paletteTitle => _s('Command Palette', '命令面板', 'Bảng lệnh');
  String get paletteSearchHint =>
      _s('Type a command or search…', '输入命令或搜索…', 'Nhập lệnh hoặc tìm kiếm…');
  String get noPaletteResults => _s('No results', '无结果', 'Không có kết quả');
  String languageChanged(String language) =>
      _s('Language: $language', '语言：$language', 'Ngôn ngữ: $language');
  String performanceChanged(String tier, int cores) => _s(
    '⚡ Graphic Tier: $tier (Optimized for $cores CPU Cores)',
    '⚡ 硬件档位：$tier (针对 $cores 核处理器优化)',
    '⚡ Cấu hình máy: $tier (Tự động nhận diện CPU $cores lõi)',
  );
  String get errorLoadingData =>
      _s('Failed to load data', '加载数据失败', 'Lỗi nạp dữ liệu');
  String get errorScan =>
      _s('Failed to scan symlinks', '扫描符号链接失败', 'Lỗi quét symlink');
  String get errorVerify =>
      _s('Failed to verify symlinks', '验证符号链接失败', 'Lỗi kiểm tra symlink');
  String get pickerExportTitle =>
      _s('Export Symlinks JSON', '导出符号链接 JSON', 'Xuất JSON Symlink');
  String get pickerImportTitle =>
      _s('Import Symlinks JSON', '导入符号链接 JSON', 'Nhập JSON Symlink');
  String get pickerSelectFolder => _s('Select Folder', '选择文件夹', 'Chọn thư mục');
  String get pickerSelectNewTarget => _s(
    'Select New Target Parent Folder',
    '选择新的目标父文件夹',
    'Chọn thư mục đích mới',
  );
  String get paletteTheme => _s(
    'Toggle Light / Dark Theme',
    '切换浅色 / 深色主题',
    'Đổi giao diện Sáng / Tối',
  );
  String get paletteThemeDesc =>
      _s('Switch color theme', '切换颜色主题', 'Chuyển đổi chủ đề màu sắc');
  String get paletteGlassSettings =>
      _s('Glassmorphism Settings', '玻璃特效设置', 'Cài đặt Glassmorphism');
  String get paletteGlassSettingsDesc => _s(
    'Adjust glass blur and opacity',
    '调整玻璃模糊度和不透明度',
    'Điều chỉnh độ mờ và độ đục của kính',
  );
  String languageCommand(String language) => _s(
    'Change language (Language: $language)',
    '切换语言（语言：$language）',
    'Đổi ngôn ngữ (Hiện tại: $language)',
  );
  String get languageCommandDesc => _s(
    'Switch between EN / 中文 / Tiếng Việt',
    '在 EN / 中文 / Tiếng Việt 之间切换',
    'Chuyển đổi EN / 中文 / Tiếng Việt',
  );
  String openTab(String tab) => _s('Open $tab tab', '打开$tab选项卡', 'Mở tab $tab');

  // ── Overview and system tools ────────────────
  String get overviewController =>
      _s('CORE CONTROLLER', '核心控制器', 'BỘ ĐIỀU KHIỂN');
  String get overviewDescription => _s(
    'Professional Windows symbolic link management with Copy-Before-Delete safety.',
    '专业的 Windows 符号链接管理工具，采用先复制后删除的安全机制。',
    'Hệ thống quản lý Symbolic Link chuyên nghiệp trên Windows với cơ chế Copy-Before-Delete an toàn.',
  );
  String get storageTelemetry =>
      _s('STORAGE TELEMETRY', '存储遥测', 'GIÁM SÁT LƯU TRỮ');
  String get noTargetDrives =>
      _s('NO TARGET DRIVES', '无目标磁盘', 'CHƯA CÓ Ổ ĐÍCH');
  String drivesLabel(String drives) =>
      _s('DRIVES: $drives', '磁盘：$drives', 'Ổ ĐĨA: $drives');
  String get totalSymlinks => _s('TOTAL SYMLINKS', '符号链接总数', 'TỔNG SYMLINK');
  String get trackedEntries =>
      _s('TRACKED ENTRIES', '已跟踪条目', 'MỤC ĐANG THEO DÕI');
  String get activeLinks => _s('ACTIVE LINKS', '活动链接', 'LINK ĐANG HOẠT ĐỘNG');
  String get onlineLinked =>
      _s('ONLINE & LINKED', '在线与已链接', 'ĐANG HOẠT ĐỘNG & ĐÃ LINK');
  String get integrityVerify =>
      _s('INTEGRITY VERIFY', '完整性验证', 'XÁC MINH TOÀN VẸN');
  String get check => _s('CHECK', '检查', 'KIỂM TRA');
  String get autoFixCsv => _s('AUTO-FIX CSV', '自动修复 CSV', 'TỰ SỬA CSV');
  String get recentSymlinks =>
      _s('Recent Symlinks', '最近的符号链接', 'Symlink gần đây');
  String get viewAll => _s('View all', '查看全部', 'Xem tất cả');
  String get copyPath => _s('Copy path', '复制路径', 'Sao chép đường dẫn');

  String get toolsTitle => _s(
    'Administrative & System Tools',
    '管理与系统工具',
    'Công cụ Quản trị & Hệ thống',
  );
  String get scannerTitle =>
      _s('Scan System Symlinks', '扫描系统符号链接', 'Quét Symlink Hệ thống');
  String get scannerDesc => _s(
    'Recursively scan user folders (%USERPROFILE%, AppData) for existing symbolic links.',
    '递归扫描用户文件夹（%USERPROFILE%、AppData）以查找现有符号链接。',
    'Quét đệ quy thư mục người dùng (%USERPROFILE%, AppData) để phát hiện Symbolic Link hiện có.',
  );
  String get integrityTitle =>
      _s('Verify & Auto-Fix', '验证与自动修复', 'Xác minh & Tự sửa lỗi');
  String get integrityDesc => _s(
    'Check all active links and update history when a target changed externally.',
    '检查所有活动链接，并在目标被外部更改时更新历史记录。',
    'Kiểm tra các liên kết đang hoạt động và cập nhật lịch sử nếu đích bị thay đổi.',
  );
  String get exportTitle =>
      _s('Export Configuration (JSON)', '导出配置（JSON）', 'Xuất cấu hình (JSON)');
  String get exportDesc => _s(
    'Back up the complete symlink list to JSON for storage or migration.',
    '将完整的符号链接列表备份为 JSON，便于存储或迁移。',
    'Sao lưu toàn bộ danh sách Symlink sang JSON để lưu trữ hoặc chuyển máy.',
  );
  String get importTitle =>
      _s('Import Configuration (JSON)', '导入配置（JSON）', 'Nhập cấu hình (JSON)');
  String get importDesc => _s(
    'Read a JSON file and recreate symlinks after reinstalling Windows or moving drives.',
    '读取 JSON 文件，在重装 Windows 或更换磁盘后重新创建符号链接。',
    'Đọc file JSON và tái tạo symbolic link sau khi cài lại Windows hoặc đổi ổ đĩa.',
  );
  String get recoveryTitle => _s(
    'Data Protection & Crash Recovery',
    '数据保护与崩溃恢复',
    'Bảo vệ dữ liệu & Tự phục hồi',
  );
  String get recoveryDesc => _s(
    'Data moves use Copy-Before-Delete. If interrupted, the system rolls back to protect the source folder.',
    '数据移动采用先复制后删除。如果中断，系统会回滚以保护源文件夹。',
    'Di chuyển dữ liệu dùng Copy-Before-Delete. Nếu gián đoạn, hệ thống hoàn tác để bảo vệ thư mục nguồn.',
  );
  String get scannerBadge => _s('SCANNER', '扫描', 'QUÉT');
  String get integrityBadge => _s('INTEGRITY', '完整性', 'TOÀN VẸN');
  String get backupBadge => _s('BACKUP', '备份', 'SAO LƯU');
  String get restoreBadge => _s('RESTORE', '恢复', 'KHÔI PHỤC');
  String statusLabel(String status) {
    switch (status) {
      case 'OK':
        return _s('OK', '正常', 'OK');
      case 'FIXED':
        return _s('FIXED', '已修复', 'ĐÃ SỬA');
      case 'BROKEN':
        return _s('BROKEN', '损坏', 'HỎNG');
      case 'MISSING':
        return _s('MISSING', '缺失', 'THIẾU');
      case 'ERROR':
        return _s('ERROR', '错误', 'LỖI');
      default:
        return status;
    }
  }

  // ── Symlink list and shared controls ─────────
  String get detailTitle => _s('Symlink Details', '符号链接详情', 'Chi tiết Symlink');
  String get hasBackup => _s('HAS BACKUP', '有备份', 'CÓ SAO LƯU');
  String get timestampLabel => _s('TIMESTAMP', '时间戳', 'THỜI GIAN');
  String get sourceLabel => _s('Source', '源路径', 'Nguồn');
  String get targetLabel => _s('Target', '目标路径', 'Đích');
  String get backupLabel => _s('Backup', '备份', 'Sao lưu');
  String get detailDescription => _s(
    'The source folder has been redirected to the target drive with data integrity preserved.',
    '源文件夹已重定向到目标磁盘，并保留数据完整性。',
    'Thư mục nguồn đã được chuyển hướng sang ổ đĩa đích với tính toàn vẹn dữ liệu.',
  );
  String get searchPathsHint => _s(
    'Search source paths, targets, or app names…',
    '搜索源路径、目标路径或应用名称…',
    'Tìm kiếm đường dẫn nguồn, đích hoặc tên ứng dụng…',
  );
  String get dropdownHint => _s('Select an item…', '选择项目…', 'Chọn một mục…');
  String searchItemsHint(int count) =>
      _s('Search $count items…', '搜索 $count 个项目…', 'Tìm kiếm $count mục…');
  String get noMatchingItems =>
      _s('No matching items', '没有匹配的项目', 'Không tìm thấy mục phù hợp');
  String get importDetails => _s('Log Details:', '日志详情：', 'Chi tiết nhật ký:');
  String localizeImportDetail(String detail) {
    const prefixes = [
      'Restored:',
      'Tracked existing link:',
      'Skipped (already exists and active):',
      'Skipped (link path is not a symlink):',
      'Failed (invalid record data):',
      'Failed (cannot create target folder):',
      'Failed (cannot remove old/broken link):',
      'Failed (symlink creation failed):',
      'Failed (exception processing item):',
    ];
    for (final prefix in prefixes) {
      if (!detail.startsWith(prefix)) continue;
      final translated = switch (prefix) {
        'Restored:' => _s('Restored:', '已恢复：', 'Đã khôi phục:'),
        'Tracked existing link:' => _s(
          'Tracked existing link:',
          '已记录现有链接：',
          'Đã theo dõi link hiện có:',
        ),
        'Skipped (already exists and active):' => _s(
          'Skipped (already exists and active):',
          '已跳过（已存在且处于活动状态）：',
          'Bỏ qua (đã tồn tại và đang hoạt động):',
        ),
        'Skipped (link path is not a symlink):' => _s(
          'Skipped (link path is not a symlink):',
          '已跳过（链接路径不是符号链接）：',
          'Bỏ qua (đường dẫn không phải symlink):',
        ),
        'Failed (invalid record data):' => _s(
          'Failed (invalid record data):',
          '失败（记录数据无效）：',
          'Thất bại (dữ liệu bản ghi không hợp lệ):',
        ),
        'Failed (cannot create target folder):' => _s(
          'Failed (cannot create target folder):',
          '失败（无法创建目标文件夹）：',
          'Thất bại (không thể tạo thư mục đích):',
        ),
        'Failed (cannot remove old/broken link):' => _s(
          'Failed (cannot remove old/broken link):',
          '失败（无法删除旧/损坏链接）：',
          'Thất bại (không thể xóa link cũ/hỏng):',
        ),
        'Failed (symlink creation failed):' => _s(
          'Failed (symlink creation failed):',
          '失败（创建符号链接失败）：',
          'Thất bại (tạo symlink thất bại):',
        ),
        _ => _s(
          'Failed (exception processing item):',
          '失败（处理项目时发生异常）：',
          'Thất bại (lỗi khi xử lý mục):',
        ),
      };
      return '$translated${detail.substring(prefix.length)}';
    }
    return detail;
  }

  // ── About and runtime information ────────────
  String get osLabel => _s('Operating system', '操作系统', 'Hệ điều hành');
  String get cpuCoresLabel => _s('CPU cores', 'CPU 核心数', 'Số nhân CPU');
  String get hardwareScoreLabel =>
      _s('Hardware score', '硬件评分', 'Điểm phần cứng');
  String get graphicsConfigLabel =>
      _s('Graphics configuration', '图形配置', 'Cấu hình đồ họa');
  String get authorLabel => _s('Author', '作者', 'Tác giả');
  String get licenseLabel => _s('License', '许可证', 'Bản quyền');
  String get standardLabel => _s('Standard', '标准', 'Bộ quy chuẩn');
  String get nativeWindowsFfi =>
      _s('Windows Native FFI', 'Windows 原生 FFI', 'Windows Native FFI');
  String get debugLabel => _s('DEBUG', '调试', 'DEBUG');
  String get releaseLabel => _s('RELEASE', '发布', 'RELEASE');

  String get dlgGuideTitle => _s(
    'JA Symlink - User Guide',
    'JA Symlink - 用户指南',
    'JA Symlink - Hướng Dẫn Sử Dụng',
  );

  String get guideTabGeneral => _s('General', '简介', 'Giới thiệu chung');
  String get guideTabOps => _s('Operations', '基础操作', 'Thao tác cơ bản');
  String get guideTabAdv => _s('Advanced', '高级功能', 'Tính năng nâng cao');
  String get guideTabSafety => _s('Safety', '安全性', 'An toàn & Phục hồi');

  String get guideGenTitle => _s('Introduction', '简介', 'Giới thiệu chung');
  String get guideGenContent => _s(
    'JA Symlink Manager helps you relocate disk space by moving directories from your primary drive (e.g. SSD C:) to other drives (e.g. HDD D:, A:) and creating symbolic links (Symlinks) in their original places. Windows programs will still think the files are in their original location.\n\nIMPORTANT: Since creating symbolic links is a system-level operation, this app automatically requests Administrator privileges on startup.',
    'JA Symlink Manager 帮助您将目录从主驱动器（例如 SSD C:）移动到其他驱动器（例如 HDD D:、A:）并在其原始位置创建符号链接（Symlinks），从而重新分配磁盘空间。Windows 程序仍会认为文件位于其原始位置。\n\n重要提示：由于创建符号链接是系统级操作，此应用在启动时会自动请求管理员权限。',
    'JA Symlink Manager giúp bạn giải phóng dung lượng ổ đĩa bằng cách di chuyển các thư mục từ ổ đĩa chính (ví dụ: SSD C:) sang các ổ đĩa khác (ví dụ: HDD D:, A:) và tạo các symbolic link (Symlink) tại vị trí ban đầu. Các chương trình Windows vẫn sẽ nhận diện dữ liệu đang nằm ở thư mục gốc.\n\nQUAN TRỌNG: Vì tạo symbolic link là một thao tác can thiệp hệ thống, ứng dụng này sẽ tự động yêu cầu quyền Administrator khi khởi chạy.',
  );

  String get guideOpsTitle => _s('Basic Operations', '基础操作', 'Thao tác cơ bản');
  String get guideOpsContent => _s(
    '• CREATE SYMLINK: Moves a directory to the target drive and replaces the original with a link.\n\n• CHANGE TARGET: Safely redirects an existing link to a new target drive.\n\n• REMOVE SYMLINK: Deletes the link without deleting your target data. You can restore the original folder from backup if needed.',
    '• 创建符号链接：将目录移动到目标驱动器，并将原始目录替换为链接。\n\n• 更改目标：将现有链接安全地重定向到新的目标驱动器。\n\n• 移除符号链接：删除链接而不删除您的目标数据。如果需要，您可以从备份恢复原始文件夹。',
    '• TẠO SYMLINK: Di chuyển một thư mục đến ổ đĩa đích và thay thế thư mục gốc bằng một liên kết.\n\n• THAY ĐỔI ĐÍCH: Chuyển hướng một liên kết đang hoạt động sang một ổ đĩa đích mới một cách an toàn.\n\n• XÓA SYMLINK: Xóa liên kết symlink mà KHÔNG xóa dữ liệu đích. Bạn có thể khôi phục lại thư mục gốc từ bản sao lưu nếu muốn.',
  );

  String get guideAdvTitle =>
      _s('Advanced Features', '高级功能', 'Tính năng nâng cao');
  String get guideAdvContent => _s(
    '• VERIFY SYMLINKS: Checks the status of all active links and automatically fixes them in the history if changed externally.\n\n• SCAN SYSTEM: Scans common paths for existing symlinks, highlighting system-created or external links in orange.\n\n• IMPORT & EXPORT: Backs up your symlink configuration to a JSON file to easily restore them on a new Windows installation.\n\n• LANGUAGE: Use the globe button to switch the complete interface between English, 中文, and Tiếng Việt.',
    '• 验证符号链接：检查所有活动链接的状态，如果外部发生更改，则自动在历史记录中修复它们。\n\n• 扫描系统：扫描常见路径以查找现有符号链接，用橙色突出显示系统创建或外部链接。\n\n• 导入和导出：将您的符号链接配置备份到 JSON 文件，以便在新 Windows 安装上轻松恢复它们。',
    '• XÁC MINH SYMLINK: Kiểm tra trạng thái của tất cả liên kết đang hoạt động và tự động sửa lịch sử nếu đích đã thay đổi bên ngoài.\n\n• QUÉT HỆ THỐNG: Quét đệ quy các đường dẫn phổ biến để tìm symlink hiện có, làm nổi bật các liên kết hệ thống/ngoài danh sách bằng màu cam.\n\n• NHẬP & XUẤT CẤU HÌNH: Sao lưu danh sách symlink sang một file JSON để dễ dàng khôi phục lại khi cài đặt lại Windows.\n\n• NGÔN NGỮ: Dùng nút hình quả địa cầu để chuyển toàn bộ giao diện giữa English, 中文 và Tiếng Việt.',
  );

  String get guideSafetyTitle =>
      _s('Safety & Recovery', '安全性', 'An toàn & Phục hồi');
  String get guideSafetyContent => _s(
    '• SAFE COPY: Uses a robust Copy-Before-Delete copy stream with real-time percentage progress. If the copy fails (disk full/no permissions), it automatically rolls back, leaving your original data intact.\n\n• CRASH RECOVERY: If a copy is interrupted due to a system crash, opening the app again will automatically detect the transaction and clean up or recover files safely.',
    '• 安全复制：使用健壮的 Copy-Before-Delete 复制流，具有实时百分比进度。如果复制失败（磁盘已满/无权限）， it会自动回滚，保持您的原始数据完整。\n\n• 崩溃恢复：如果复制由于系统崩溃而中断，再次打开应用将自动检测该事务并安全地清理或恢复文件。',
    '• SAO CHÉP AN TOÀN: Sử dụng luồng sao chép (Copy-Before-Delete) có hiển thị phần trăm dung lượng. Nếu sao chép thất bại (ổ đầy/không đủ quyền), ứng dụng sẽ tự động hoàn tác (rollback) giữ nguyên thư mục gốc.\n\n• TỰ PHỤC HỒI SỰ CỐ: Nếu quá trình sao chép bị ngắt giữa chừng do mất điện/crash, khi mở lại ứng dụng sẽ tự động phát hiện và khôi phục hoặc dọn dẹp các tệp tin lỗi một cách an toàn.',
  );

  String t(String key) {
    switch (key) {
      case 'tab_settings_ui':
        return _s('Glassmorphism & UI', '玻璃特效与界面', 'Giao diện & Kính mờ');
      case 'tab_user_guide':
        return _s('User Guide', '使用指南', 'Hướng dẫn sử dụng');
      case 'tab_about':
        return _s('About', '关于应用', 'Thông tin ứng dụng');
      case 'settings_card_header':
        return _s(
          'Liquid Glass & Bento Tuning',
          '调整 Liquid Glass 与 Bento 卡片',
          'Điều chỉnh Liquid Glass & Bento Card',
        );
      case 'settings_default':
        return _s('Default', '默认', 'Mặc định');
      case 'settings_card_blur':
        return _s(
          'Bento Card Blur',
          'Bento 卡片模糊度',
          'Độ mờ khối Bento (Card Blur)',
        );
      case 'settings_card_opacity':
        return _s(
          'Bento Card Opacity',
          'Bento 卡片不透明度',
          'Độ đục khối Bento (Card Opacity)',
        );
      case 'settings_dialog_blur':
        return _s('Dialog Blur', '对话框模糊度', 'Độ mờ Hộp thoại (Dialog Blur)');
      case 'settings_dialog_opacity':
        return _s(
          'Dialog Opacity',
          '对话框不透明度',
          'Độ đục Hộp thoại (Dialog Opacity)',
        );
      case 'settings_dropdown_blur':
        return _s(
          'Dropdown Blur',
          '下拉菜单模糊度',
          'Độ mờ Danh sách (Dropdown Blur)',
        );
      case 'settings_dropdown_opacity':
        return _s(
          'Dropdown Opacity',
          '下拉菜单不透明度',
          'Độ đục Danh sách (Dropdown Opacity)',
        );
      case 'settings_window_effect':
        return _s(
          'Window Backdrop Blur',
          '窗口背景模糊效果',
          'Hiệu ứng nền cửa sổ (Window Blur)',
        );
      case 'settings_window_effect_desc':
        return _s(
          'Select native Windows composition blur material',
          '选择 Windows 原生合成模糊材质',
          'Chọn chất liệu kính mờ DWM của Windows',
        );
      case 'effect_acrylic':
        return _s(
          'Acrylic (Frosted Glass)',
          'Acrylic (磨砂玻璃)',
          'Acrylic (Mờ xuyên thấu)',
        );
      case 'effect_acrylic_desc':
        return _s(
          'True frosted glass seeing through to background apps & desktop',
          '透视背景窗口与桌面的真实磨砂玻璃 (推荐)',
          'Kính mờ xuyên thấu nhìn thấy ứng dụng và desktop phía sau (Khuyên dùng)',
        );
      case 'effect_aero':
        return _s(
          'Aero Glass (0ms Lag)',
          'Aero 玻璃 (0ms 延迟)',
          'Aero Glass (GPU 0ms lag)',
        );
      case 'effect_aero_desc':
        return _s(
          'Hardware-accelerated glass with zero window drag latency',
          'GPU 硬件加速玻璃模糊，拖拽窗口 0 延迟',
          'Kính mờ GPU chống giật lag tuyệt đối khi kéo cửa sổ',
        );
      case 'effect_mica':
        return _s(
          'Mica (Opaque Tint)',
          'Mica (不透明壁纸色)',
          'Mica (Màu đục Windows 11)',
        );
      case 'effect_mica_desc':
        return _s(
          'Windows 11 opaque surface tinted by desktop wallpaper',
          'Windows 11 不透明材质，仅按桌面壁纸微调色调',
          'Bề mặt màu đục của Windows 11 lấy màu theo hình nền desktop',
        );
      case 'effect_tabbed':
        return _s(
          'Tabbed (Mica Alt)',
          'Tabbed (半透明 Mica)',
          'Tabbed (Mica trong suốt)',
        );
      case 'effect_tabbed_desc':
        return _s(
          'Windows 11 Tabbed material with subtle transparency',
          'Windows 11 Tabbed 材质，具有轻微透明度',
          'Vật liệu Tabbed của Windows 11 mờ nhẹ hơn Mica',
        );
      case 'effect_disabled':
        return _s('Disabled (Solid)', '已禁用 (纯色)', 'Tắt hiệu ứng (Nền phẳng)');
      case 'effect_disabled_desc':
        return _s(
          'Standard opaque flat background without blur composition',
          '标准平面纯色背景，不使用 DWM 模糊',
          'Nền phẳng thông thường không dùng kính mờ',
        );
      case 'action_cancel':
        return _s('Cancel', '取消', 'Hủy');
      case 'action_save':
        return _s('Save Settings', '保存设置', 'Lưu Cài Đặt');
      case 'perf_tooltip':
        return _s(
          'Hardware Graphic Performance Tier',
          '硬件图形性能档位',
          'Cấu hình hiệu năng đồ họa',
        );
      case 'lang_tooltip':
        return _s('Change Language', '切换语言', 'Chuyển đổi ngôn ngữ');
      case 'theme_tooltip':
        return _s('Toggle Light/Dark Theme', '切换亮暗主题', 'Chuyển đổi Sáng/Tối');
      case 'settings_tooltip':
        return _s(
          'Settings & System Info',
          '设置与系统信息',
          'Cài đặt giao diện & Hệ thống',
        );
      case 'theme_light':
        return _s('Light', '浅色', 'Sáng');
      case 'theme_dark':
        return _s('Dark', '深色', 'Tối');
      case 'settings_btn_label':
        return _s('Settings', '设置', 'Cài đặt');
      case 'settings_dialog_title':
        return _s(
          'UI & System Settings',
          '界面与系统设置',
          'Cài đặt Giao diện & Hệ thống',
        );
      case 'guide_shortcuts_title':
        return _s('Keyboard Shortcuts', '快捷键', 'Phím tắt Thao tác');
      case 'guide_shortcuts_desc':
        return _s(
          'Press Ctrl+K (or Cmd+K) anywhere to open Spotlight Search. Use ESC to close dialogs instantly.',
          '按 Ctrl+K（或 Cmd+K）随时打开聚光灯搜索。使用 ESC 快速关闭对话框。',
          'Bấm Ctrl+K (hoặc Cmd+K) bất kỳ lúc nào để mở Spotlight Command Palette. Dùng ESC để đóng nhanh hộp thoại.',
        );
      case 'guide_topbar_title':
        return _s(
          'Topbar Interactive Expanding Buttons',
          '顶栏交互式展开按钮',
          'Nút Topbar Tương tác Tự Mở Rộng',
        );
      case 'guide_topbar_desc':
        return _s(
          'Hover your mouse over the topbar icon pills to smoothly expand and reveal labels.',
          '将鼠标悬停在顶栏图标胶囊上，平滑展开并显示完整文本。',
          'Rê chuột lên các viên nang chức năng trên Topbar để mở rộng nhãn chữ chi tiết.',
        );
      case 'guide_tier_title':
        return _s(
          'Hardware Graphic Performance Tuning',
          '硬件图形性能调优',
          'Tối ưu hóa Hiệu năng Đồ họa',
        );
      case 'guide_tier_desc':
        return _s(
          'Click the ⚡ tier button on the Topbar to switch between Ultra (max effects), Balanced, and Lite (zero lag on low-end PCs).',
          '点击顶栏上的 ⚡ 档位按钮，在 Ultra（极致特效）、Balanced 和 Lite（低配电脑零延迟）之间切换。',
          'Bấm nút ⚡ trên Topbar để chuyển đổi giữa Ultra (đầy đủ hiệu ứng), Balanced và Lite (tiết kiệm pin & mượt tuyệt đối cho máy yếu).',
        );
      case 'guide_scroll_title':
        return _s(
          'Smooth Inertia Bouncing Scroll',
          '平滑惯性回弹滚动',
          'Cuộn Nảy Quán Tính Mượt Mà',
        );
      case 'guide_scroll_desc':
        return _s(
          'All lists and dialogs use native BouncingScrollPhysics with GPU-composited glass blur layers.',
          '所有列表与弹窗均采用原生弹性物理滚动与 GPU 硬件加速模糊层。',
          'Mọi danh sách và hộp thoại đều trang bị BouncingScrollPhysics kết hợp lớp cách ly blur phần cứng.',
        );
      case 'about_app_name':
        return 'JA Symlink Manager';
      case 'about_app_desc':
        return _s(
          'Professional Windows symbolic link manager with safe copy-before-delete operations, crash recovery, and multilingual UI.',
          '专业的 Windows 符号链接管理工具，支持安全的先复制后删除、崩溃恢复和多语言界面。',
          'Công cụ quản lý symbolic link chuyên nghiệp trên Windows với thao tác copy-before-delete an toàn, tự phục hồi sự cố và giao diện đa ngôn ngữ.',
        );
      case 'about_sys_title':
        return _s(
          'System & Hardware Environment',
          '系统与硬件运行环境',
          'Môi trường Hệ thống & Phần cứng',
        );
      case 'about_dev_title':
        return _s(
          'Author & Architecture',
          '作者与架构规范',
          'Thông tin Tác giả & Kiến trúc',
        );
      default:
        return key;
    }
  }

  // ── Internal helper ──────────────────────────
  String _s(String en, String zh, String vi) {
    switch (lang) {
      case AppLanguage.en:
        return en;
      case AppLanguage.zh:
        return zh;
      case AppLanguage.vi:
        return vi;
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
  AppStrings get strings => AppStrings(_lang);

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
    final provider = context
        .dependOnInheritedWidgetOfExactType<LanguageProvider>();
    assert(provider != null, 'No LanguageProvider found above this context');
    return provider!.notifier!;
  }
}

// ─────────────────────────────────────────────
//  BuildContext extension
// ─────────────────────────────────────────────

extension BuildContextI18n on BuildContext {
  AppStrings get strings => LanguageProvider.of(this).strings;
  LanguageNotifier get languageNotifier => LanguageProvider.of(this);
}
