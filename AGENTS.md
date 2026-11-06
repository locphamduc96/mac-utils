# MacUtils: hướng dẫn cho agent

Fork của LinearMouse, chạy riêng trên máy owner. Remote `upstream` = `linearmouse/linearmouse`; `origin` = `locphamduc96/mac-utils` (public, GitHub Actions đã tắt vì workflow upstream cần secret ký của LinearMouse). Repo này commit bằng tài khoản cá nhân `locphamduc96 <locphamduc96@gmail.com>` (`git config` riêng repo).
Không mở PR / issue lên upstream; quy tắc PR, issue, crowdin của LinearMouse không áp dụng ở đây.

## Bố cục

- `LinearMouse/`: code app (Xcode synchronized folder, file mới tự vào target). Module Swift vẫn tên `LinearMouse`
  (`PRODUCT_MODULE_NAME`) để test và merge upstream ít xung đột; sản phẩm là `MacUtils.app`, bundle id `com.rhodo.MacUtils`.
- `LinearMouse/MacUtils/`: code riêng của MacUtils.
  - `Window/`: phím tắt cửa sổ (`WindowLayout` thuần toán, `WindowMover` qua AX, `GlobalHotKeys` qua Carbon).
  - `Vietnamese/`: bộ gõ (`VietnameseInput` event tap, `VietnameseInjector`, `VietnameseStatusItem`,
    `VietnameseSettingsModel` cài đặt).
  - `Vietnamese/Typing/`: engine gõ tự viết, chỉ dùng Foundation (âm tiết `VietSyllable`, phím `VietWord`, điều phối
    `VietTypingEngine`, bảng mã `VietCodeTable`). Dùng chung cho app và input source; không import AppKit / Defaults ở đây.
- `InputMethod/`: input source "MacUtils Tiếng Việt" (InputMethodKit), ngoài synchronized folder nên không vào target
  app; build bằng `Scripts/install-input-method` (swiftc + engine ở `Vietnamese/Typing`).
- `LinearMouseUnitTests/MacUtils/`: test của phần MacUtils. `VietTypingEngineTests` có bộ test sinh mọi âm tiết hợp lệ
  × 6 thanh × nhiều thứ tự phím (~92 nghìn chuỗi); sửa luật âm tiết thì chạy lại.
- `project-notes/`: plan, task, kết quả (tiếng Việt).

Sửa code upstream ở mức tối thiểu và có lý do (đổi tên, tắt Sparkle, đường dẫn cấu hình, gắn trang cài đặt, gọi
start / stop trong `AppDelegate`) để `git merge --no-ff upstream/main` dễ.

## Lệnh

```bash
# Build Debug (ký ad-hoc)
xcodebuild -project LinearMouse.xcodeproj -scheme LinearMouse -configuration Debug \
  -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build

# Test (thêm -only-testing:LinearMouseUnitTests/WindowLayoutTests để chạy riêng)
xcodebuild test -project LinearMouse.xcodeproj -scheme LinearMouse -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= -only-testing:LinearMouseUnitTests

# Cài bản Release vào /Applications (kèm input source)
./Scripts/install-macutils

# Chỉ build + cài lại input source
./Scripts/install-input-method

# Chụp ảnh các trang cài đặt (so trước / sau khi đổi UI)
TEST_RUNNER_MACUTILS_SNAPSHOT_DIR="$PWD/project-notes/06-reports/assets/<ngày>-<tên>" xcodebuild test \
  -project LinearMouse.xcodeproj -scheme LinearMouse -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= -only-testing:LinearMouseUnitTests/UISnapshotTests
```

Lần chạy test đầu sau khi build sạch đôi khi báo "test runner hung", chạy lại là qua.

## Cập nhật từ upstream

- LinearMouse: `git fetch upstream && git merge --no-ff upstream/main`, rồi build + test.
- Rectangle / xkey: không theo dõi. Engine gõ là code tự viết, không đồng bộ với xkey.

## Quy tắc

- Giữ deployment target hiện có (`LM_DEPLOYMENT_TARGET`).
- Sau khi sửa `Documentation/Configuration.d.ts`: `npm run generate:json-schema` (legacy npm của upstream).
- Commit message chỉ mô tả thay đổi code, không ghi attribution AI.
