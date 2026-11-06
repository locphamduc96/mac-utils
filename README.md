# MacUtils

Một app trên thanh menu gộp các tiện ích Mac mà owner hay dùng, để không phải cài nhiều app:

| Tiện ích | Thay cho | Nguồn |
| --- | --- | --- |
| Chuột / touchpad: tốc độ, tăng tốc, đảo chiều cuộn, chỉnh riêng từng thiết bị | LinearMouse, Scroll Reverser | Fork [LinearMouse](https://github.com/linearmouse/linearmouse) (MIT) |
| Sắp xếp cửa sổ: `⌃⌥C` gần toàn màn hình (90%), `⌃⌥X` giữa rộng 2/3 | Rectangle | Viết lại theo phép tính của [Rectangle](https://github.com/rxhanson/Rectangle) (MIT) |
| Gõ tiếng Việt: Telex / VNI, `⌃⇧` chuyển Việt / Anh, chữ V / E trên thanh menu | GoTiengViet, Unikey | Engine của [xkey](https://github.com/xmannv/xkey) (MIT) |

Chỉ dùng trên máy owner, không phát hành.

## Cài đặt

```bash
# Một lần: tạo chứng chỉ tự ký để quyền Accessibility không mất sau mỗi lần build lại
./Scripts/create-local-signing-cert

# Build Release và cài vào /Applications/MacUtils.app
./Scripts/install-macutils
```

Lần đầu mở app: cấp quyền **System Settings → Privacy & Security → Accessibility** cho MacUtils.
Thoát LinearMouse, Rectangle, Scroll Reverser và bộ gõ tiếng Việt khác trước khi dùng, tránh hai app cùng xử lý
một phím / một lần cuộn.

Cấu hình chuột nằm ở `~/.config/mac-utils/mouse.json`. Lần chạy đầu, nếu chưa có file này, app chép cấu hình từ
`~/.config/linearmouse/linearmouse.json`.

## Phát triển

Xem [AGENTS.md](AGENTS.md) và [project-notes/](project-notes/).

## Credits

Xem [LinearMouse/ThirdPartyNotices](LinearMouse/ThirdPartyNotices): LinearMouse, Rectangle, xkey và các dự án
LinearMouse dựa vào, kèm license.
