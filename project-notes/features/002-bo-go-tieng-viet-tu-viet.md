# task-002 — Bộ gõ tiếng Việt tự viết cho MacUtils

**Status:** In Review · **Date:** 2026-11-06 · **Nguồn:** chat với owner

Owner thử bộ gõ xkey trong task-001: gõ được nhưng trong Ghostty / Claude Code bị đảo và nuốt chữ ("taij" → "atij",
"lại" → "l"), "source" thành "sỏuce". Owner: "tôi thấy mấy app này clone thẳng vào không đủ tốt, viết lại hết thì hơn";
chuyển giấy phép cũng được.

Owner duyệt plan trong chat ngày 2026-11-06: "duyệt làm liên tục hết cho tôi đi" (làm một mạch 7 task, nghiệm thu cuối).

## Mục tiêu

Một bộ gõ do MacUtils tự viết (engine + lớp chèn ký tự), thay engine xkey, chạy ổn trong mọi app owner dùng, nhất là
terminal (Ghostty, Claude Code), trình duyệt, Slack, Notes. Không chép code của bộ gõ khác; được đọc tài liệu và cách
làm của chúng để tham khảo, ghi nguồn chỗ nào lấy ý tưởng.

## Vì sao lỗi hiện tại không phải do engine

- Engine xkey ra đúng "quá, quốc, quyền, giá, giữa, để, tại, lại, hiện tại" trong unit test.
- Lỗi đảo / nuốt chữ nằm ở lớp chèn: gửi dồn backspace + chữ vào terminal, phím gõ tiếp chen vào giữa.
- Riêng "source" → "sỏuce" là thiếu luật khôi phục tiếng Anh của engine.

Vì vậy bộ gõ mới cần cả hai: engine có luật âm tiết chặt + khôi phục tiếng Anh, và lớp chèn theo từng loại app.

## Thiết kế

- **Engine (Swift thuần, không phụ thuộc AppKit):** mô hình âm tiết (phụ âm đầu / vần / dấu), Telex, VNI, Simple Telex;
  đặt dấu kiểu cũ / mới; bỏ dấu ở bất kỳ vị trí nào trong từ; gõ lặp để huỷ (`ss` → `s`); đồng bộ backspace; kiểm tra âm
  tiết hợp lệ trước khi biến đổi; khôi phục tiếng Anh khi nhấn Space, ESC để trả nguyên phím đã gõ.
- **Lớp chèn:** event tap tầng HID; một semaphore giữ phím gõ tiếp cho tới khi lần chèn trước xong; hồ sơ theo app:
  - thường: backspace + chuỗi Unicode;
  - terminal: gửi chậm có nhịp, ngoài luồng event tap;
  - thanh địa chỉ trình duyệt / Spotlight: xử lý gợi ý tự hoàn thành;
  - chỉnh độ trễ cho từng app trong cài đặt.
- **Tính năng quanh bộ gõ:** phím chuyển Việt / Anh (`⌃⇧` mặc định, đổi được), nhớ Việt / Anh theo từng app, danh sách
  app loại trừ, gõ tắt (macro), chữ V / E trên thanh menu.

## Task

| Task | Nội dung | Kiểm tra | Ngày công | Status |
| --- | --- | --- | --- | --- |
| task-002a | Engine: âm tiết, Telex / VNI / Simple Telex, dấu cũ / mới, huỷ dấu, backspace; xuất Unicode, TCVN3, VNI-Windows | Bộ test sinh từ toàn bộ âm tiết hợp lệ × 6 thanh × nhiều thứ tự gõ: 100% đúng; bảng mã khớp bảng chuẩn | 2 | Done |
| task-002b | Khôi phục tiếng Anh (Space) + ESC | Danh sách ~300 từ tiếng Anh / lập trình hay gõ: ≥ 95% giữ nguyên; từ mơ hồ (mix, box) ghi rõ | 1 | Done |
| task-002c | Lớp chèn: tap HID, semaphore, hồ sơ app, độ trễ theo app | Owner gõ đoạn mẫu 3 lần nhanh trong Ghostty, Claude Code, Chrome (thanh địa chỉ + trang), Notes: 0 lỗi | 1,5 | In Review — chờ owner gõ thật |
| task-002d | Phím chuyển đổi được, nhớ theo app, loại trừ app, gõ tắt | Unit test + owner thử | 1 | Done |
| task-002e | Trang cài đặt Tiếng Việt + menu V / E theo tính năng mới; gỡ engine xkey | Ảnh `UISnapshotTests` trước / sau | 0,5 | Done |
| task-002f | Input source macOS (InputMethodKit) dùng chung engine: bundle cài vào `~/Library/Input Methods`, chọn trong menu bàn phím | Owner chọn input source, gõ đoạn mẫu trong Ghostty / Chrome / Notes: 0 lỗi | 1,5 | Done — owner xác nhận 2026-11-07 |
| task-002g | Codex review, cài bản Release, ghi kết quả | Review clean, owner nghiệm thu | 0,5 | Done |

Mỗi task: code → test → owner nói go task kế. Tổng khoảng 8 ngày công. Sau task-002a có bảng demo gõ thử (phím → chữ ra) để owner xem trước.

## Câu hỏi PO

| # | Câu | a | b | c | Khuyến nghị |
| --- | --- | --- | --- | --- | --- |
| 1 | Cách hoạt động | Event tap như GoTiengViet / Unikey: dùng bàn phím U.S. của macOS, gõ ở đâu cũng được | Input source của macOS (InputMethodKit): chọn trong menu bàn phím, chữ đang gõ có gạch chân | Cả hai | a: giống cảm giác GoTiengViet owner đang quen |
| 2 | Bảng mã | Chỉ Unicode | Thêm TCVN3, VNI-Windows | Thêm Unicode tổ hợp | a |
| 3 | Tham khảo | Chỉ tài liệu ngôn ngữ + hành vi GoTiengViet | Được đọc code OpenKey / Gõ Nhanh / xkey để lấy ý tưởng (không chép), ghi nguồn | — | b |
| 4 | Giấy phép repo | Giữ MIT (code tự viết) | Chuyển GPL-3.0 | — | a |

## Quyết định PO (2026-11-06)

| # | Chọn | Nghĩa là |
| --- | --- | --- |
| 1 | c | Làm cả event tap (chính) và input source macOS (task-002f) |
| 2 | b | Unicode + TCVN3 + VNI-Windows |
| 3 | b | Được đọc code OpenKey / Gõ Nhanh / xkey để lấy ý tưởng, tự viết lại, ghi nguồn |
| 4 | a | Giữ MIT (owner chấp nhận đổi giấy phép nếu cần, nhưng code tự viết nên không cần) |

## Đã làm

- Engine tự viết ở `LinearMouse/MacUtils/Vietnamese/Typing/` (chỉ Foundation, dùng chung cho app và input source):
  - `VietSyllable`: phụ âm đầu (kể cả "qu", "gi"), bảng vần (mở / cần âm cuối / không có âm cuối), âm cuối,
    luật c/k/g/gh/ng/ngh, âm cuối tắc c/ch/p/t chỉ đi với sắc / nặng, vị trí dấu kiểu cũ / mới.
  - `VietWord`: Telex, VNI, Simple Telex; dấu chỉ nhận khi từ còn có thể là tiếng Việt; gõ lặp để huỷ; bỏ dấu sau cả từ
    (`tienges`, `thuongw`, `huuw`); "uơ" khi chưa có chữ sau, tự thành "ươ" khi gõ tiếp; `dd` chỉ ngay sau d đầu từ.
  - `VietTypingEngine`: dựng lại từ theo phím, so với chữ đang hiện để ra số backspace + chữ mới; từ không còn là
    tiếng Việt thì hiện lại đúng phím đã gõ; Space / dấu câu / Return kết thúc từ (trả tiếng Anh, gõ tắt); ESC trả phím
    gốc; backspace dựng lại từ từ chữ trên màn hình.
  - `VietCodeTable`: Unicode, TCVN3, VNI-Windows (đối chiếu bảng của xkey, khớp 100%).
- Trả tiếng Anh: từ không hợp lệ tự trả; thêm danh sách 27 từ tiếng Anh hay gõ nhưng trùng âm tiết hiếm (`is`, `if`,
  `was`, `data`, `list`, `test`…); gõ lặp nguyên âm không liền nhau chỉ thành dấu mũ khi chưa có dấu thanh và sau nó
  chỉ còn phụ âm cuối ("these", "there", "queue" giữ tiếng Anh).
- Lớp chèn (`VietnameseInput`, `VietnameseInjector`): tap tầng HID (dự phòng session); phím gõ tiếp chờ lần chèn trước
  xong; terminal (Ghostty, Terminal, iTerm, Warp, kitty…) gửi chậm có nhịp ngoài luồng tap; Return / Tab được gửi lại sau
  khi trả chữ; tự nghỉ khi input source đang chọn là input method (input source MacUtils, bộ gõ Nhật / Hàn…).
- Cài đặt (`VietnameseSettingsModel`): kiểu gõ, bảng mã, phím chuyển (`⌃⇧` / `⌥Z` / `⌃Space`), kiểu dấu, trả tiếng Anh,
  nhớ Việt / Anh theo app, luật theo app (luôn tiếng Anh, chèn Tự động / Nhanh / Chậm), gõ tắt.
- Trang cài đặt Tiếng Việt và menu V / E làm lại theo tính năng mới (thêm bảng mã). Ảnh:
  `project-notes/06-reports/assets/2026-11-06-bo-go-moi/05-tieng-viet.png`.
- Input source "MacUtils Tiếng Việt" (`InputMethod/`, InputMethodKit): chữ đang gõ là marked text, hết từ mới chèn; đọc
  chung cài đặt của app; `Scripts/install-input-method` build bằng swiftc, ký, cài vào `~/Library/Input Methods` và đăng ký.
  `install-macutils` gọi luôn script này.
- Gỡ engine xkey (`Vietnamese/Engine`, `XKeyShims.swift`).

## Kiểm tra

| Số | Đích | Đo | Nguồn |
| --- | --- | --- | --- |
| Mọi âm tiết × 6 thanh × nhiều thứ tự phím (Telex + VNI) | 100% đúng | 92.182 / 92.182 chuỗi phím | `VietTypingEngineTests.testEverySyllableInSeveralKeyOrders` |
| Danh sách viết tay (từ thường, qu / gi, ươ, hoa, VNI, Simple Telex, backspace, ESC, Return, bảng mã, gõ tắt) | 0 lỗi | 17 test, 0 lỗi | `VietTypingEngineTests` |
| Từ tiếng Anh / lập trình hay gõ giữ nguyên sau Space | ≥ 95% | 364 / 368 = 98,9%; còn lại `been → bên`, `its → ít`, `last → lát`, `this → thí` (cố ý giữ tiếng Việt) | `VietEnglishRestoreTests` |
| Phím → lệnh engine, cài đặt / gõ tắt / luật app lưu đúng dạng input source đọc | 0 lỗi | 7 test, 0 lỗi | `VietnameseInputTests` |
| Unit test toàn bộ | 0 lỗi | 1230 test, 0 lỗi, 1 bỏ qua (`UISnapshotTests`) | xcodebuild test |
| Lint | sạch | swiftformat 0 file; swiftlint 0 cảnh báo ở phần MacUtils | swiftformat / swiftlint |
| Cài bản Release + input source | chạy được | `MacUtils is running.` · `Registered input source.` · ký `MacUtils Local Signing` | `install-macutils` |
| Gõ thật — input source macOS | ổn | Owner 2026-11-07: "đổi sang dạng mac thì nó ổn áp hẳn rồi" | owner |
| Gõ thật — bắt phím (event tap) | 0 lỗi | chưa xác nhận sau bản gửi đồng bộ theo Mkey | owner |

Output test:

```
VietTypingEngine: 92182 key sequences checked
English restore: 364/368 = 98.9% kept
Executed 1230 tests, with 1 test skipped and 0 failures (0 unexpected) in 31.981 (32.244) seconds
** TEST SUCCEEDED **
```

Review: Codex, 2 vòng (`~/agent-tasks/mac-utils/task-002/review-task-002.md`, `review-r2-task-002.md`).

| # | P | Phát hiện | Xử lý |
| --- | --- | --- | --- |
| 1 | P1 | `ass` ra `ass` thay vì `as` (huỷ dấu bị trả tiếng Anh đè) | Bỏ: cố ý để pass / less / miss / boss giữ tiếng Anh; owner xem lại |
| 2 | P1 | Dấu mũ gõ sau dấu thanh bị chặn (`tiengse`) | Sửa: cho phép khi sau nguyên âm còn phụ âm cuối; these / there vẫn tiếng Anh |
| 3 | P1 | Chưa chỉnh được độ trễ theo app | Sửa: mức Chậm / Rất chậm / Cực chậm (×1 / ×2 / ×4) |
| 4 | P1 | Enum Codable lưu chuỗi JSON có ngoặc, input source đọc sai | Sửa: bỏ Codable, lưu chuỗi thường; test định dạng lưu |
| 5 | P1 | Input source bỏ qua E / app luôn tiếng Anh | Sửa: đọc `typingOn` và luật app mỗi phím |
| 6 | P2 | Chế độ chậm bỏ sót backspace cho gợi ý tự hoàn thành | Sửa: tính trước khi chọn cách chèn |
| 7 | P2 | Không lưu trạng thái app đang rời | Sửa: lưu trước khi đổi app |
| 8 | P2 | Xoá chữ gõ nhầm không quay lại gõ tiếng Việt | Sửa: dựng lại từ nếu phím còn lại hiện đúng như trên màn hình (trừ sau ESC) |
| 9 | P2 | Tap dự phòng tầng session cùng tầng với phím chèn | Sửa: phím chèn chậm gửi ở annotated session |
| 10 | P2 | Chờ chèn chặn tap không giới hạn | Sửa: chờ tối đa 700 ms |
| r2-1 | P2 | Lần chèn chậm kế tiếp vẫn chờ semaphore vô hạn | Sửa: `DispatchGroup` + hàng đợi tuần tự, không còn chờ vô hạn trên luồng tap |

## Sửa sau góp ý owner (2026-11-06)

| Owner báo | Nguyên nhân | Sửa |
| --- | --- | --- |
| Telegram nuốt chữ | Chế độ nhanh gửi backspace + chữ dồn một lúc | Khoảng trễ ngắn như xkey (1 ms / backspace, 3 ms trước chữ, 1,5 ms / đoạn, 5 ms chờ) |
| Chữ nháy lùi rồi nhảy tới | Bản chất cách bắt phím (xoá rồi gõ lại) | Thêm "Cách gõ": Bắt phím / Input source macOS (thay tại chỗ, không nháy), đổi trong cài đặt và menu V / E; MacUtils tự chọn input source hoặc trả về bàn phím ABC; chọn thất bại thì quay về Bắt phím |
| Icon V / E muốn trong suốt, viền trắng | — | Chữ rỗng chỉ có viền, ảnh template theo màu thanh menu (`08-icon-thanh-menu.png`) |
| `doidor` không ra "đổi" | `dd` chỉ nhận ngay sau d đầu từ; dấu mũ gõ sau bị chặn khi sau nó còn nguyên âm | `d` thành đ ở bất kỳ đâu khi từ bắt đầu bằng d; dấu mũ gõ sau lúc nào cũng được |
| `heset` không ra "hết" | Luật giữ "these" chặn dấu mũ gõ sau dấu thanh | Bỏ luật; these / there / here / reset / did / dad / queue vào danh sách tiếng Anh |
| `laf` ra "aà" (terminal) | Vòng sửa review chuyển phím chèn chậm xuống annotated session, backspace vượt phím `a` còn đang qua tap của app khác | Tap ở HID thì gửi vào session tap (giữ thứ tự); chỉ dùng annotated session khi tap dự phòng ở session |

Review phần sửa: Codex 1 vòng (`review-task-002-followup.md`): P2 chọn input source thất bại vẫn ở chế độ input source → sửa (quay về Bắt phím); P2 gõ tắt dài ngủ trên luồng tap → sửa (chữ > 40 ký tự đi đường chèn chậm).

## Học từ Mkey (2026-11-07)

Owner: "nên lấy cái mkey của mantrandev về, xem họ làm gì mà học lại làm". Đọc `Sources/macOS/ModernKey/MKey.mm` và
`Sources/engine/Engine.cpp` (commit `5df97d5`, GPL-3.0, chỉ đọc lấy ý tưởng, không chép code):

| Mkey / OpenKey làm | MacUtils trước đó | Đổi thành |
| --- | --- | --- |
| Tap tầng session, mọi phím thay chữ gửi đồng bộ qua `CGEventTapPostEvent`, không trễ, không luồng riêng | Tap HID + chèn chậm bất đồng bộ + chờ, gây "aà" | Tap session, gửi đồng bộ qua proxy; terminal / Telegram / mức theo app chỉ thêm khoảng nghỉ trên luồng tap (tối đa 250 ms) |
| Gõ lặp phím dấu: bỏ dấu, để lại một chữ (`tesst` → test) | Trả lại phím đã gõ → "tesst" | Như Unikey; cuối từ, nếu từ điển tiếng Anh macOS biết phím gốc ("message", "issue", "pass") thì trả phím gốc; ESC trả phím gốc |
| Chỉ trả phím khi từ sai **và còn dấu** | — | Từ đã huỷ dấu không bị trả nhầm |

Review: Codex 1 vòng (`review-task-002-mkey.md`): P2 xoá chữ sau lần huỷ dấu làm mất lịch sử → sửa (giữ lịch sử với
phím gõ sau lần huỷ cuối); P2 gõ tắt tra theo chuỗi đã gộp → sửa (tra theo phím thật).

Đo: tiếng Anh giữ nguyên 364 / 368 = 98,9% (có từ điển); 1231 test, 0 lỗi.

## Chưa làm / để lại

- Gõ thật chế độ bắt phím sau bản gửi đồng bộ (owner đang dùng input source macOS).
- Quyền Accessibility vẫn mất sau mỗi lần cài lại dù app ký bằng chứng chỉ tự ký (designated requirement cố định
  theo chứng chỉ); log TCC bị ẩn, chưa rõ nguyên nhân.
- Danh sách từ tiếng Anh ưu tiên là cố định trong code, chưa sửa được trong cài đặt.
- Input source chưa có menu riêng (chọn kiểu gõ / bảng mã trong app MacUtils, input source đọc theo).
