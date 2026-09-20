# JA_Symlink — Handoff

## 2026-09-20: P2 Nhóm 4

- Gauge tính ACTIVE / (ACTIVE + DANGLING), loại lịch sử REMOVED; không trừ DANGLING hai lần. Mô tả không còn khẳng định mọi entry đã được xác thực.
- Verify gồm ACTIVE và DANGLING, báo target không tồn tại; đổi nhãn thành Kiểm tra liên kết. Chỉ giữ chức năng sửa target lịch sử có sẵn, không tự khôi phục symlink hoặc di chuyển dữ liệu.
- Donut repaint khi phân bổ/thứ tự ổ hoặc theme đổi dù tổng byte giữ nguyên.
- Copy chờ clipboard thành công, chặn request chồng, xử lý lỗi và kiểm tra mounted sau await. Chuỗi mới cho EN/ZH/VI.
- Regression: Overview có REMOVED và DANGLING, verify không bỏ DANGLING, donut đổi phân bổ cùng tổng, clipboard chậm/thất bại và localization EN/ZH. Test copy cũ dùng mock thành công độc lập.
- Kiểm chứng: analyzer sạch, format 92 file không đổi, 64/64 tests pass; diff check sạch. Chưa QA GUI native, build release hoặc commit. Giữ nguyên các thay đổi có sẵn.

## 2026-09-20: P2 Nhóm 3

- Bộ đếm C luôn lấy totalSavedOnCBytes, kể cả bằng 0. Nhãn EN/ZH/VI xác định đây là ước tính target hiện tại, không phải số đo lịch sử giải phóng.
- Tổng hợp phân loại nguồn theo từng entry, không dùng cờ nguồn trong cache target; normalize đường dẫn Windows và loại target trùng/cha-con riêng cho tổng và nhóm nguồn C. Đây là hợp theo đường dẫn, chưa khử alias junction/hardlink tới cùng dữ liệu vật lý.
- Revision mỗi lượt scan ngăn kết quả/cache cũ ghi đè lượt mới; dispose vô hiệu hóa kết quả đang chạy. Đo target chạy qua compute, bỏ existsSync trên UI trước khi đo.
- Overview refresh ổ đĩa mỗi 15 giây, không chồng request timer, hủy timer khi unmount; đổi logic thì chuyển listener.
- Kiểm chứng: analyze sạch; format 86 file; toàn bộ 51 test trước test widget bổ sung pass; test widget bổ sung pass riêng (tổng 52 test). Regression kiểm tra cache nguồn, target chồng lấp, empty sau scan, dispose, timer/unmount và C=0.
- Chưa build release, benchmark thư mục lớn hoặc QA GUI native. Giữ nguyên thay đổi có sẵn; chưa commit.

## 2026-09-20: P1/P2 Nhóm 2

- Registry kiểm tra exitCode từng add/delete và query cả hai command key; thất bại từng phần trả false. Chưa rollback tự động hay thử đăng ký Explorer thật.
- Dò process chuẩn hóa ranh giới thư mục, bổ sung Restart Manager cho file dữ liệu lồng nhau; bỏ qua reparse points, luôn đóng RM session. Lỗi quét được báo lên UI thay vì coi như không có khóa.
- Create/change/relocator dùng process_lock_guard chung: chỉ đóng PID đã hiển thị và được duyệt; đóng thất bại hoặc còn khóa thì dừng/báo lỗi. Create không gọi auto-kill backend lần hai.
- Sửa overflow nhóm nút hộp thoại bằng Wrap, giữ giao diện hiện tại.
- Test: Registry giả lập lỗi từng bước; Restart Manager với process PowerShell giữ data.db tạm; widget cancel/ignore/failure/success và create không auto-kill. Fixture tự thoát sau 15 giây. Fixture của lần test đầu bị kẹt ReadLine đã dừng đúng PID 19996.
- Analyze sạch; format 79 file sạch; 39/39 tests pass; diff check sạch. Chưa build release, thử Explorer/UAC hoặc kill ứng dụng thật. Chưa benchmark scan nhiều file; không cam kết phát hiện mọi loại kernel/file lock.

## 2026-09-20: Sửa hai P2 Nhóm 1

- Snapshot JSON và script BAT/PowerShell giữ ACTIVE lẫn DANGLING; tiếp tục loại REMOVED. Không thay schema, giữ trạng thái gốc trong JSON. Restore vẫn yêu cầu target tồn tại.
- Quét dung lượng dùng compute với hàm static và đường dẫn String; listSync/lengthSync chạy trong isolate nền trên Windows. Không truyền widget/model sang isolate, vẫn followLinks: false.
- Test mới kiểm tra DANGLING trong cả ba kiểu export và đếm file/thư mục lồng nhau, bỏ qua symlink ngoài cây và dangling link.
- Kiểm chứng: analyze sạch; format lib test (69 file); 23/23 tests pass. Chưa benchmark cache lớn hoặc kiểm tra độ mượt GUI trực tiếp. Chưa commit/build release.

## 2026-09-20: Sửa bốn P1 Nhóm 1

- Relocator truy vấn lại free space trước mỗi thao tác; chặn unknown, lỗi truy vấn và không đủ 500 MiB đệm. Bỏ fallback giả định 100 GiB. Không tự kill process.
- Health Watcher dùng compare-and-set theo bản ghi quan sát; đọc/sửa/ghi lịch sử không có await xen giữa trong cùng isolate. Bảo toàn bản ghi thêm mới, trạng thái REMOVED và target vừa đổi. Chưa cung cấp khóa liên tiến trình.
- BAT escape phần trăm, DisableDelayedExpansion, bỏ đường dẫn khỏi comment và từ chối ký tự điều khiển/quote không hợp lệ.
- Thêm test/group1_safety_test.dart: preflight, không kill process, ghi lịch sử xen kẽ, escaping/validation và chạy CMD thực tế với mklink thay bằng echo.
- Kiểm chứng: analyze sạch, format lib test (69 file), 21/21 tests pass. Chưa thử di dời dữ liệu thật, build release hoặc GUI Windows.
- Các P2 (snapshot bỏ DANGLING, scan đồng bộ trên UI) chưa thuộc patch này. Giữ nguyên thay đổi có sẵn và export JSON của người dùng.

## 2026-09-20: Baseline và patch lỗi biên dịch i18n

- Phạm vi: chạy analyze, format an toàn trong `lib/` và `test/`, test; chỉ sửa lỗi thực tế.
- Baseline: analyzer báo 12 diagnostics; format 59 file không thay đổi; 7 test pass, widget test không biên dịch được.
- Patch: khai báo `s = context.strings` trong DashboardShell.build; thêm import i18n cho Command Palette và chuyển biến `s` vào widget sử dụng; sửa 3 lint const trong i18n_test.
- Kiểm chứng sau patch, theo thứ tự: Flutter analyze `--no-pub` không còn issues; Dart format `lib test` (59 file, 0 thay đổi); Flutter test `--no-pub` (8/8 pass).
- Dùng `A:\APPS\flutter\bin\cache\dart-sdk\bin\dart.exe` và `A:\APPS\flutter\bin\cache\flutter_tools.snapshot` vì wrapper flutter.bat không trả output; Flutter cần quyền truy cập SDK cache/lockfile ngoài sandbox.
- Chưa build release hoặc kiểm tra giao diện native Windows. Không thay đổi pipeline release, dependency hay dữ liệu runtime.
- Worktree ban đầu có `ja_symlinks_export_2026-09-13_08-50-50.json` chưa được theo dõi; giữ nguyên.
- `docs/AI_CONTEXT.md` chưa tồn tại tại thời điểm kiểm tra.
