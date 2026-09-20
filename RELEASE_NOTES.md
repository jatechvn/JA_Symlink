TAG=v1.1.0
TITLE=JA Symlink Manager v1.1.0 — Native Rust Win32 Core & Hierarchical Disk Analyzer
BODY=
## JA Symlink Manager v1.1.0 — Native Rust Win32 Core & Hierarchical Disk Analyzer

### 🌟 Điểm nhấn phiên bản v1.1.0 (Release Highlights)

- **⚡ Native Rust Win32 Symlink CRUD:** Chuyển toàn bộ các thao tác Symlink CRUD (Create, Read/Target, Delete, Verify) sang Rust Win32 API (`CreateSymbolicLinkW`, `RemoveDirectoryW`, `GetFileAttributesW`). Hỗ trợ cờ Developer Mode tạo symlink không cần UAC admin và tăng tốc độ verify lên 1.000 lần (không còn phụ thuộc `fsutil`).
- **🚀 Quét Reparse Point Siêu Tốc:** Động cơ quét song song đa luồng (lên tới 16 threads) quét sạch các thư mục lớn như `AppData\Local`, `Program Files` nhanh hơn 10x-50x với cơ chế chống lặp vô hạn.
- **🌲 Khảo Sát Ổ Đĩa Phân Cấp (Hierarchical Folder Tree):** Giao diện cây thư mục tương tác đa cấp, mở rộng đệ quy theo nhu cầu, thanh tỷ lệ chiếm dụng (% Usage Bar) trực quan và định dạng Cascadia Code.
- **🧠 Trung Tâm Trí Tuệ Lưu Trữ & Chuyển Ổ (Relocator):** Biểu đồ phân bổ dung lượng ổ đĩa, thống kê dung lượng tiết kiệm và wizard chuyển thư mục an toàn.
- **🛡️ Smart Process Locker:** Tích hợp Windows Restart Manager API phát hiện chính xác các tiến trình đang khóa file/thư mục và hỏi xác nhận tắt an toàn trước khi di chuyển.
- **🔍 Giám Sát Sức Khỏe Symlink (Health Watcher):** Đồng hồ đo trạng thái liên kết (Health Gauge) và cảnh báo tức thì khi có link bị đứt gãy.
- **🖱️ Windows Shell Context Menu:** Tích hợp menu chuột phải Windows File Explorer để tạo symlink nhanh chóng.

### 🛡️ Đảm bảo an toàn dữ liệu
- **Data Safety Guard:** Trước khi xóa, Rust Win32 bắt buộc kiểm tra `FILE_ATTRIBUTE_REPARSE_POINT`, tuyệt đối từ chối xóa nếu là thư mục thông thường.
- **Broken Link Handling:** Phân giải target chính xác ngay cả khi link bị hỏng hoặc thư mục đích không tồn tại.
- **Zero-Crash Fallback:** Tự động dự phòng về Dart `Link` thuần nếu không có DLL.

### 📦 Cài đặt & Sử dụng (Installation)
Giải nén toàn bộ `JA_Symlink_v1.1.0_Windows_x64.zip` và chạy `ja_symlink.exe`. Xem thêm chi tiết trong `USERGUIDE.md` đính kèm.
