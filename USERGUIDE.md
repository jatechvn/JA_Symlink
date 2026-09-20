# 📖 Hướng dẫn sử dụng JA Symlink Manager v1.1.0

Ứng dụng Windows Desktop chuyên nghiệp quản lý Symbolic Link & Junction, khảo sát ổ đĩa phân cấp siêu tốc bằng động cơ Native Rust Win32 và di chuyển thư mục an toàn.

---

## 🚀 1. Khởi chạy ứng dụng

- **Quyền Administrator:** Ứng dụng tự động yêu cầu quyền Quản trị viên (UAC Admin) khi khởi động để có toàn quyền thao tác Symbolic Link hệ thống.
- **Hỗ trợ Developer Mode:** Trên Windows 10/11, nếu hệ thống đã kích hoạt *Developer Mode*, ứng dụng hỗ trợ cờ `SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE` giúp tạo symlink an toàn mà không bị giới hạn.
- **Bản Portable sẵn sàng chạy:** Gói phát hành `JA_Symlink_v1.1.0_Windows_x64.zip` được bung sẵn, chỉ cần giải nén và chạy `ja_symlink.exe`.

---

## ⚡ 2. Quản lý Symbolic Link (Native Rust Win32 CRUD)

1. **Tạo mới Symlink (`Create`):**
   - Chọn đường dẫn nguồn (`Link Path`) và đường dẫn đích (`Target Path`).
   - Tùy chọn sao chép dữ liệu trước khi liên kết (`Copy-before-delete`).
   - Động cơ Win32 tự động tạo liên kết symbolic link cấp hệ điều hành trong vài mili-giây.
2. **Xóa Symlink an toàn (`Remove`):**
   - Động cơ Win32 kiểm tra nghiêm ngặt cờ `FILE_ATTRIBUTE_REPARSE_POINT` trước khi thực hiện xóa.
   - **Chỉ gỡ liên kết**, tuyệt đối **không bao giờ đụng chạm hoặc xóa dữ liệu** trong thư mục đích.
3. **Kiểm tra tính hợp lệ (`Verify`):**
   - Kiểm tra reparse point trực tiếp qua Win32 API trong **0.01 mili-giây** (nhanh hơn 1.000x so với `fsutil.exe`).
   - Phân biệt rõ liên kết hợp lệ (`ACTIVE`), liên kết đứt gãy (`DANGLING`), hoặc thư mục đã bị thay đổi thành thư mục thường.

---

## 🌲 3. Khảo Sát Dung Lượng Ổ Đĩa Siêu Tốc (Fast Disk Analyzer)

- Chuyển sang tab **Khảo Sát Ổ Đĩa (Disk Analyzer)**.
- Chọn ổ đĩa (`C:`, `D:`, `E:`...) và bấm **Bắt Đầu Quét Siêu Tốc**.
- **Cây Thư Mục Phân Cấp (Hierarchical Folder Tree):**
  - Mở rộng từng cấp thư mục (`▶` / `▼`) để xem các thư mục con được sắp xếp từ **nặng nhất đến nhẹ nhất**.
  - Thanh phần trăm (% Usage Bar) trực quan giúp định vị ngay thư mục nào đang chiếm nhiều dung lượng nhất.
  - Dung lượng Cascadia Code tô màu theo kích cỡ (>10GB cyan, >1GB vàng hổ phách, <1GB lục ngọc).
  - Bấm nút **"Symlink"** trên bất kỳ thư mục nào để chuyển ngay sang ổ đĩa khác.

---

## 🧠 4. Di Chuyển Thư Mục Sang Ổ Khác (Relocator Wizard)

- Khi ổ C: bị đầy (ví dụ thư mục `AppData\Local`, game, hoặc thư viện lưu trữ lớn):
  1. Sử dụng tính năng **Folder Relocator**.
  2. Chọn thư mục cần di chuyển và ổ đĩa đích còn nhiều dung lượng.
  3. Hệ thống sẽ:
     - Tự động kiểm tra tiến trình đang khóa thư mục qua **Smart Process Locker**.
     - Sao chép toàn bộ dữ liệu sang ổ đích với thanh tiến trình mượt mà.
     - Tạo Symbolic Link thay thế thư mục gốc.
     - Xác thực liên kết trước khi dọn dẹp thư mục tạm, bảo đảm an toàn dữ liệu 100%.

---

## 🛡️ 5. Khóa Tiến Trình Thông Minh (Smart Process Locker)

- Khi di chuyển hoặc xóa thư mục, nếu có ứng dụng đang mở file (ví dụ Chrome, VS Code, Game):
  - Ứng dụng kích hoạt **Windows Restart Manager API** để phát hiện danh sách tiến trình đang khóa thư mục.
  - Hiển thị hộp thoại cảnh báo với tên tiến trình và PID.
  - Cho phép người dùng xác nhận đóng tiến trình an toàn chỉ với 1 click.

---

## 🖱️ 6. Menu Chuột Phải Windows Explorer (Shell Context Menu)

- Bật tùy chọn **Shell Context Menu** trong phần Cài đặt.
- Từ Windows File Explorer, click chuột phải vào bất kỳ thư mục nào:
  - Chọn **"Tạo Symbolic Link với JA Symlink"** để mở nhanh hộp thoại liên kết.

---

## 🔍 7. Giám Sát Sức Khỏe & Khôi Phục (Health Watcher & Recovery)

- **Đồng hồ Sức Khỏe (Health Gauge):** Theo dõi tổng số link hoạt động và cảnh báo ngay lập tức nếu phát hiện link bị ngắt kết nối.
- **Tự động khôi phục sau sự cố (Crash Recovery):** Nếu mất điện hoặc tắt máy đột ngột trong khi đang sao chép, ứng dụng sẽ tự động phát hiện giao dịch dang dở và đề xuất khôi phục nguyên trạng khi mở lại.

---

## 📦 Gói Phát Hành

- File nén: `JA_Symlink_v1.1.0_Windows_x64.zip`
- Mã băm kiểm tra: `SHA256SUMS.txt`
- Toàn bộ ứng dụng đã được đóng gói sẵn sàng chạy độc lập (Portable), không cần cài đặt thêm runtime.
