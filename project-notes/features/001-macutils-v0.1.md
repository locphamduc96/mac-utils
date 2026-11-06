# task-001 — MacUtils v0.1, gộp chuột + cửa sổ + gõ tiếng Việt

**Status:** In Review · **Date:** 2026-11-06 · **Nguồn:** chat với owner

Owner duyệt plan trong chat ngày 2026-11-06: "duyệt, bắt đầu làm hết đi, làm liên tục, tôi nghiệm thu cuối thôi".

## Plan đã duyệt

Một app trên thanh menu, fork LinearMouse làm nền (giữ remote `upstream`), một quyền Accessibility cho cả 3 module:

1. Chuột / touchpad: giữ nguyên LinearMouse (tốc độ, tăng tốc, đảo chiều cuộn theo từng thiết bị), thay luôn Scroll Reverser.
2. Cửa sổ: tự viết, tham khảo phép tính Rectangle (MIT, ghi công):
   - `⌃⌥C` Almost Maximize: 90% vùng làm việc, ở giữa.
   - `⌃⌥X` Center Two Thirds: rộng 2/3, ở giữa.
3. Gõ tiếng Việt: engine xkey (MIT) + chế độ CGEvent; Telex, VNI, Unicode; phím chuyển Việt / Anh; chữ V / E trên thanh menu.
   Không làm đợt này: macro, kiểm tra chính tả bằng từ điển, XKeyIM, Smart Switch.

Các bước: khởi tạo (clone, đổi tên `MacUtils`, bundle id riêng, license, ký tự ký, build); module cửa sổ + unit test;
module tiếng Việt + test engine; kiểm tra (test, smoke trên máy owner, Codex review).

Quyết định owner / chọn thay owner (owner chưa phản đối):
- Phím chuyển Việt / Anh: `⌃⇧` (mặc định Unikey).
- Phím tắt cửa sổ cố định ở bản đầu.
- Ghi chú ở `mac-utils/project-notes/`.
- Ký app bằng chứng chỉ tự ký miễn phí (owner: "tạm làm cách free trước"); không dùng chứng chỉ của team công ty.

Owner chốt khi xem "PO cần xem" (2026-11-06):
- `⌃⌥X` trên màn hình dọc: giữ như Rectangle (chia 2/3 theo chiều cao).
- Kiểu bỏ dấu mặc định: kiểu cũ (hòa, thủy).
- Phím chuyển Việt / Anh: `⌃⇧`, giống cách owner đang dùng ở GoTiengViet.
- Đồng ý: cấu hình chuột ở `~/.config/mac-utils/mouse.json` kèm chép một lần; thêm backspace ở thanh địa chỉ dựa trên AX;
  thay AGENTS.md gốc và bỏ quy tắc ghi tên agent của upstream.

Yêu cầu thêm giữa chừng (2026-11-06):
- Icon mới "kiểu Unikey hoặc gen icon khác đẹp hơn".
- "Có thể thiết kế lại UI/UX của app": đợt này chỉ làm vòng UX gọn (một biểu tượng thanh menu, giao diện tiếng Việt);
  thiết kế lại toàn bộ để đề xuất riêng kèm demo.

## Đã làm

- Đổi tên sản phẩm `MacUtils.app`, bundle id `com.rhodo.MacUtils`, version 0.1.0; module Swift giữ tên `LinearMouse`.
- Tắt Sparkle (không tự cập nhật về bản LinearMouse), bỏ mục "Check for updates".
- Cấu hình chuột chuyển sang `~/.config/mac-utils/mouse.json`; lần đầu chép từ cấu hình LinearMouse nếu có.
- `LinearMouse/MacUtils/Window/`: `WindowLayout` (toán thuần), `WindowMover` (AX, tắt `AXEnhancedUserInterface` khi đặt khung),
  `GlobalHotKeys` (Carbon), `WindowShortcuts` (bật / tắt theo cài đặt).
- `LinearMouse/MacUtils/Vietnamese/`: engine xkey chép nguyên ở `Engine/` (commit `398e78e`), stub `XKeyShims.swift`,
  `VietnameseInput` (event tap phiên, `⌃⇧` nhấn rồi thả), `VietnameseInjector` (backspace + chuỗi Unicode; ở trình duyệt / Spotlight
  thêm 1 backspace khi AX báo đang có gợi ý được chọn), `VietnameseStatusItem` (V / E).
- Trang cài đặt "Cửa sổ" và "Tiếng Việt" trong sidebar; toolbar chọn thiết bị chỉ hiện ở trang Con trỏ / Cuộn / Nút.
- UX: khi bộ gõ bật, chỉ còn một biểu tượng V / E trên thanh menu, menu có kiểu gõ, cài đặt, mở lúc khởi động, thoát;
  tắt bộ gõ thì biểu tượng LinearMouse cũ hiện lại. `install-macutils` đặt `AppleLanguages = vi` cho app.
- Icon mới: gen 2 phương án bằng Codex (`gpt-image-2`), chọn B (cửa sổ chia 2/3 + chữ Đ + chuột, đỏ cam), cắt squircle macOS.
  Ảnh: `project-notes/06-reports/assets/2026-11-06-app-icon/`.
- `Scripts/create-local-signing-cert`, `Scripts/install-macutils`.
- Ghi công: `ThirdPartyNotices/xkey.txt`, `Rectangle.txt`, bảng trong `ThirdPartyNotices/README.md`.

## Kiểm tra

| Số | Đích | Đo | Nguồn |
| --- | --- | --- | --- |
| Build Debug + Release | thành công | `** BUILD SUCCEEDED **` cả hai (ký ad-hoc) | xcodebuild 2026-11-06 |
| Unit test toàn bộ | 0 lỗi | 1215 test, 0 lỗi (1212 upstream + 3 mới sau review; MacUtils: 11 + 6 + 1) | xcodebuild test |
| Engine Telex / VNI | đúng như Unikey | `tieengs vieetj` → "tiếng việt", `tie61ng` → "tiếng", `return` giữ nguyên khi bật chính tả | `VietnameseInputTests` |
| Khung cửa sổ | 90% giữa / 2/3 giữa, đúng màn hình | khớp số Rectangle trên 1512×945, màn phụ lệch gốc, màn dọc | `WindowLayoutTests` |
| Lint | sạch | swiftformat 0 file cần sửa; swiftlint không cảnh báo ở file mới | swiftformat / swiftlint |
| App khởi động | không crash | chạy bản Debug, thoát sạch, không có crash report | `open` + `log show` |
| Smoke thật (gõ, phím cửa sổ, touchpad) | chạy trên máy owner | **chưa đo**: cần cấp quyền Accessibility cho MacUtils | owner nghiệm thu |

Output test:

```
Test Suite 'VietnameseInputTests' passed — Executed 11 tests, with 0 failures
Test Suite 'WindowLayoutTests' passed — Executed 6 tests, with 0 failures
Executed 1215 tests, with 0 failures (0 unexpected) in 19.710 (20.021) seconds
** TEST SUCCEEDED **
```

Review: Codex, 2 vòng (`~/agent-tasks/mac-utils/task-001/review-task-001.md`, `review-r2-task-001.md`).

| # | P | Phát hiện | Xử lý |
| --- | --- | --- | --- |
| 1 | P1 | Center Two Thirds màn dọc chia theo chiều cao, khác plan | Bỏ: cố ý giống Rectangle owner đang dùng; owner chốt giữ như Rectangle (2026-11-06) |
| 2 | P1 | `NSImage(systemSymbolName:)` cần macOS 11 | Sửa: `#available` |
| 3 | P2 | Nhập cấu hình cũ chép cả symlink | Sửa: chép nội dung, test `ConfigurationImportTests` |
| 4 | P2 | ⌃⇧ có thể bật nhầm khi nhả ⌘ trước | Sửa: giữ trạng thái huỷ tới khi nhả hết, thêm 2 test |
| 5 | P2 | U+202F làm xoá thừa ở ô đã đầy | Sửa: bỏ ký tự đệm, chỉ thêm 1 backspace khi AX báo đang có vùng chọn (gợi ý) |
| 6 | P2 | Bật lại tap không reset bộ đệm | Sửa: reset session + detector |

Vòng 2: clean, 0 phát hiện.

## Chưa làm / để lại

- Smoke thật trên máy owner (cần chứng chỉ tự ký + quyền Accessibility).
- Chứng chỉ tự ký: auto mode chặn agent ghi Keychain, owner chạy `./Scripts/create-local-signing-cert`.
- Chưa commit: thay đổi đang nằm ở working tree trên `main` (các file mới đánh dấu `git add -N`).
- Thiết kế lại toàn bộ UI/UX: chưa làm, đề xuất riêng kèm demo.
- Bộ gõ: chưa có macro, từ điển chính tả, loại trừ theo app, đổi phím chuyển, bảng mã TCVN3 / VNI-Win; chèn ký tự chưa có
  chế độ riêng cho Terminal / Office như xkey.
- Phím tắt cửa sổ chưa đổi được trong app; chưa có "bấm lần nữa để trả về kích thước cũ".
