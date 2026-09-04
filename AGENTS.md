# AGENTS.md — Luật nền cho dự án JA_Symlink

File này được Antigravity, Claude Code và các agent tương thích (Cursor, Windsurf...) tự động đọc mỗi khi mở project. Khác với các skill trong `.agents/skills/`, `.claude/skills/` (chỉ kích hoạt khi mô tả khớp yêu cầu của bạn), nội dung dưới đây **luôn áp dụng cho mọi thay đổi mã nguồn**, không cần bạn nhắc lại.

Ngoài ra agent cũng nên tham chiếu luật chung toàn workspace (áp dụng mọi project, mọi ngôn ngữ) tại:
- `~/.claude/rules/security.md`
- `~/.claude/rules/coding-style.md`
- `~/.claude/rules/git-workflow.md`

Luật riêng của project này (bên dưới) ưu tiên cao hơn nếu có xung đột với luật chung ở trên.

## Bối cảnh dự án
- JA Symlink Manager — Flutter Desktop app (Windows only hiện tại) để quản lý symbolic link thư mục, chạy quyền admin, UI Bento Glassmorphism với Acrylic/Mica blur (`flutter_acrylic`) + Win10/Win11-aware color tokens (`lib/theme/styles_win10.dart` / `styles_win11.dart`).
- Kiến trúc & cấu trúc thư mục chuẩn tham chiếu tại skill `flutter-app-blueprint` (`.claude/skills/flutter-app-blueprint/SKILL.md`). Lưu ý: project này tổ chức UI thành `lib/layout/`, `lib/views/`, `lib/widgets/`, `lib/dialogs/`, `lib/theme/` thay vì gộp vào `lib/modules/ui/` như blueprint mô tả — đây là lựa chọn kiến trúc có chủ đích (tách nhỏ theo domain), KHÔNG tự ý gộp lại trừ khi được yêu cầu rõ ràng.
- Xem `.claude/skills/` để biết danh sách skill có sẵn (đồng bộ từ `PROJECT_DART/dart_sample/skills/`).

## Quy tắc bắt buộc (Constraints)

### 1. Hiệu năng UI
- Luôn dùng `const` constructor cho Widget khi có thể, để tránh rebuild không cần thiết.
- Không lồng Widget quá 4 cấp trong một `build()`. Nếu sâu hơn, extract ra `StatelessWidget`/`ConsumerWidget` riêng.

### 2. Kiến trúc & luồng dữ liệu
- Không viết Business Logic trực tiếp trong hàm `build()`.
- Giữ nguyên kiến trúc state-management hiện tại (Provider) — không tự ý đổi sang pattern khác trừ khi được yêu cầu rõ ràng.
- Business logic sống trong `lib/modules/logic/*` (theo domain: `create_operation.dart`, `remove_operation.dart`, `verify_operation.dart`...), điều phối qua `lib/modules/logic.dart`.

### 3. Glassmorphism / Legibility floor (skill `flutter-project-rules` rule 7)
- Khi opacity < 1.0, BẮT BUỘC ép `effectiveBlur = max(blur, 6.0)` bất kể slider blur người dùng để ở mức nào (đã áp dụng tại `BentoCard`/`GlassDialog` — không bỏ khi thêm bề mặt kính mới).
- Tái dùng token màu translucent đã có trong `ThemeProvider`/`styles_win10.dart`/`styles_win11.dart` trước khi bịa giá trị alpha mới.

### 4. An toàn
- Xử lý Null Safety cẩn thận — không lạm dụng toán tử `!` để ép kiểu mù quáng.
- KHÔNG BAO GIỜ tự ý chạy `flutter clean`, xóa file, hoặc các lệnh phá hủy dữ liệu mà chưa được người dùng xác nhận rõ ràng.
- App tự yêu cầu quyền admin khi khởi động (`symlinkLogic.elevateAdmin()`) — cẩn trọng khi sửa luồng này vì ảnh hưởng trực tiếp tới trải nghiệm mở app.
- Trước khi thêm package mới vào `pubspec.yaml`: xác nhận package có null-safety và đang ở bản ổn định (stable) mới nhất.

### 5. Vòng kiểm chứng bắt buộc trước khi báo "xong"
Sau bất kỳ thay đổi code nào, PHẢI chạy tuần tự và sửa hết lỗi phát sinh trước khi báo cáo hoàn thành:
1. `dart analyze` (hoặc `flutter analyze`)
2. `dart format .`
3. Nếu có test: `flutter test`

Không được tự nhận "đã xong" nếu các lệnh trên còn báo lỗi/cảnh báo chưa xử lý.

### 6. Định dạng phản hồi
- Cuối mỗi câu trả lời, LUÔN LUÔN tự động đưa ra danh sách các gợi ý bước tiếp theo (Prompt mẫu) cùng với tên các **Skill** tương ứng sẽ kích hoạt.

## Khi nào gọi skill cụ thể
Với các tác vụ chuyên biệt (build/release Windows, đa ngôn ngữ, debug theo giả thuyết...), tham chiếu skill tương ứng trong `.claude/skills/` — xem `skills_guide.md` gốc tại `PROJECT_DART/dart_sample/` để biết mô tả đầy đủ. Các luật ở trên vẫn áp dụng song song khi thực hiện skill.

⚠️ Project này hiện chỉ target Windows Desktop — bỏ qua các phần Android/iOS/macOS/Linux/FVM/License Key của `flutter-app-blueprint` trừ khi được yêu cầu mở rộng platform.
