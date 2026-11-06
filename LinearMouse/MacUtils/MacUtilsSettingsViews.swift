// MIT License
// Copyright (c) 2026 MacUtils

import Defaults
import SwiftUI

struct WindowSettings: View {
    @Default(.windowShortcutsEnabled) var enabled
    @ObservedObject var shortcuts = WindowShortcuts.shared

    var body: some View {
        DetailView(schemeSpecific: false) {
            Form {
                Section {
                    Toggle(isOn: $enabled) {
                        withDescription {
                            Text(verbatim: "Phím tắt sắp xếp cửa sổ")
                            Text(verbatim: "Áp dụng cho cửa sổ đang được chọn, trên màn hình chứa phần lớn cửa sổ đó.")
                        }
                    }
                }
                .modifier(SectionViewModifier())

                Section {
                    ForEach(WindowShortcuts.bindings, id: \.action) { binding in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: binding.action.title)
                                Text(verbatim: binding.action.detail)
                                    .settingsDescriptionStyle()
                            }
                            Spacer()
                            Text(verbatim: binding.combo.display)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(enabled ? .primary : .secondary)
                        }
                    }
                }
                .modifier(SectionViewModifier())

                if !shortcuts.failedCombos.isEmpty {
                    Section {
                        Text(
                            verbatim: "Không đăng ký được \(shortcuts.failedCombos.joined(separator: ", ")). "
                                + "Có thể app khác (ví dụ Rectangle) đang giữ phím này — thoát app đó rồi tắt/bật lại công tắc ở trên."
                        )
                        .foregroundColor(.red)
                    }
                    .modifier(SectionViewModifier())
                }
            }
            .modifier(FormViewModifier())
        }
    }
}

struct VietnameseSettings: View {
    @Default(.vietnameseModuleEnabled) var moduleEnabled
    @Default(.vietnameseTypingOn) var typingOn
    @Default(.vietnameseInputMethod) var inputMethod
    @Default(.vietnameseModernStyle) var modernStyle
    @Default(.vietnameseSpellCheck) var spellCheck
    @Default(.vietnameseQuickTelex) var quickTelex

    var body: some View {
        DetailView(schemeSpecific: false) {
            Form {
                Section {
                    Toggle(isOn: $moduleEnabled.animation()) {
                        withDescription {
                            Text(verbatim: "Bộ gõ tiếng Việt")
                            Text(
                                verbatim: "Tắt hẳn nếu bạn dùng bộ gõ khác (GoTiengViet, Unikey…), tránh hai bộ gõ cùng xử lý một phím."
                            )
                        }
                    }
                }
                .modifier(SectionViewModifier())

                if moduleEnabled {
                    Section {
                        Toggle(isOn: $typingOn) {
                            withDescription {
                                Text(verbatim: "Đang gõ tiếng Việt")
                                Text(
                                    verbatim: "Bấm rồi thả ⌃⇧ (Control + Shift) để chuyển Việt / Anh. Chữ V / E trên thanh menu cho biết trạng thái."
                                )
                            }
                        }

                        Picker(selection: $inputMethod) {
                            ForEach(VietnameseInputMethod.allCases, id: \.self) { method in
                                Text(verbatim: method.title).tag(method)
                            }
                        } label: {
                            Text(verbatim: "Kiểu gõ")
                        }
                        .modifier(PickerViewModifier())
                    }
                    .modifier(SectionViewModifier())

                    Section {
                        Toggle(isOn: $modernStyle) {
                            withDescription {
                                Text(verbatim: "Đặt dấu kiểu mới")
                                Text(verbatim: modernStyle ? "Đang dùng: hoà, thuỷ" : "Đang dùng: hòa, thủy")
                            }
                        }

                        Toggle(isOn: $spellCheck) {
                            withDescription {
                                Text(verbatim: "Kiểm tra chính tả, tự khôi phục từ sai")
                                Text(verbatim: "Gõ \"return\" giữ nguyên chữ tiếng Anh thay vì thành \"retủn\".")
                            }
                        }

                        Toggle(isOn: $quickTelex) {
                            withDescription {
                                Text(verbatim: "Gõ tắt phụ âm (Quick Telex)")
                                Text(verbatim: "cc → ch, gg → gi, kk → kh, nn → ng, pp → ph, qq → qu, tt → th")
                            }
                        }
                    }
                    .modifier(SectionViewModifier())
                }
            }
            .modifier(FormViewModifier())
        }
    }
}
