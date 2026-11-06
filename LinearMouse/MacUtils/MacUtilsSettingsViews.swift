// MIT License
// Copyright (c) 2026 MacUtils

import AppKit
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
    @Default(.vietnameseCodeTable) var codeTable
    @Default(.vietnameseToggleHotkey) var toggleHotkey
    @Default(.vietnameseModernStyle) var modernStyle
    @Default(.vietnameseRestoreEnglish) var restoreEnglish
    @Default(.vietnameseRememberPerApp) var rememberPerApp
    @Default(.vietnameseAppRules) var appRules
    @Default(.vietnameseMacrosEnabled) var macrosEnabled
    @Default(.vietnameseMacros) var macros

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
                    typingSection
                    spellingSection
                    appSection
                    macroSection
                }
            }
            .modifier(FormViewModifier())
        }
    }

    private var typingSection: some View {
        Section {
            Toggle(isOn: $typingOn) {
                withDescription {
                    Text(verbatim: "Đang gõ tiếng Việt")
                    Text(
                        verbatim: "Bấm \(toggleHotkey.shortTitle) để chuyển Việt / Anh. Chữ V / E trên thanh menu cho biết trạng thái."
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

            Picker(selection: $codeTable) {
                ForEach(VietCodeTable.allCases, id: \.self) { table in
                    Text(verbatim: table.title).tag(table)
                }
            } label: {
                withDescription {
                    Text(verbatim: "Bảng mã")
                    Text(verbatim: "TCVN3 / VNI-Windows chỉ dùng cho tài liệu cũ với font .VnTime / VNI-Times.")
                }
            }
            .modifier(PickerViewModifier())

            Picker(selection: $toggleHotkey) {
                ForEach(VietnameseToggleHotkey.allCases, id: \.self) { hotkey in
                    Text(verbatim: hotkey.title).tag(hotkey)
                }
            } label: {
                Text(verbatim: "Phím chuyển Việt / Anh")
            }
            .modifier(PickerViewModifier())
        }
        .modifier(SectionViewModifier())
    }

    private var spellingSection: some View {
        Section {
            Toggle(isOn: $modernStyle) {
                withDescription {
                    Text(verbatim: "Đặt dấu kiểu mới")
                    Text(verbatim: modernStyle ? "Đang dùng: hoà, thuỷ, khoẻ" : "Đang dùng: hòa, thủy, khỏe")
                }
            }

            Toggle(isOn: $restoreEnglish) {
                withDescription {
                    Text(verbatim: "Tự trả lại chữ tiếng Anh")
                    Text(
                        verbatim: "Gõ source, text, user, return… giữ nguyên chữ tiếng Anh. Từ nào vẫn bị bỏ dấu (mix → mĩ) thì nhấn ESC để trả lại phím vừa gõ."
                    )
                }
            }
        }
        .modifier(SectionViewModifier())
    }

    private var appSection: some View {
        Section {
            Toggle(isOn: $rememberPerApp) {
                withDescription {
                    Text(verbatim: "Nhớ Việt / Anh cho từng ứng dụng")
                    Text(verbatim: "Ví dụ: Slack luôn tiếng Việt, VS Code luôn tiếng Anh, tự chuyển khi đổi app.")
                }
            }

            ForEach(appRules) { rule in
                AppRuleRow(rule: binding(for: rule)) {
                    appRules.removeAll { $0.id == rule.id }
                }
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Tuỳ chỉnh theo ứng dụng")
                    Text(
                        verbatim: "Luôn tiếng Anh trong app đó, hoặc đổi cách chèn chữ khi app bị nuốt / đảo chữ (Chậm = gửi phím có nhịp như terminal)."
                    )
                    .settingsDescriptionStyle()
                }
                Spacer()
                if #available(macOS 11.0, *) {
                    Menu {
                        ForEach(runningApps, id: \.bundleID) { app in
                            Button(app.name) {
                                appRules.append(VietnameseAppRule(bundleID: app.bundleID, name: app.name))
                            }
                        }
                    } label: {
                        Text(verbatim: "Thêm app…")
                    }
                    .fixedSize()
                }
            }
        }
        .modifier(SectionViewModifier())
    }

    private var macroSection: some View {
        Section {
            Toggle(isOn: $macrosEnabled) {
                withDescription {
                    Text(verbatim: "Gõ tắt")
                    Text(
                        verbatim: "Gõ chữ tắt rồi nhấn Space hoặc dấu câu để thay bằng cụm đầy đủ, ví dụ vn → Việt Nam."
                    )
                }
            }

            if macrosEnabled {
                ForEach(macros) { macro in
                    MacroRow(macro: binding(for: macro)) {
                        macros.removeAll { $0.id == macro.id }
                    }
                }

                Button {
                    macros.append(VietnameseMacro(shortcut: "", expansion: ""))
                } label: {
                    Text(verbatim: "Thêm chữ tắt")
                }
            }
        }
        .modifier(SectionViewModifier())
    }

    private var runningApps: [(bundleID: String, name: String)] {
        let existing = Set(appRules.map(\.bundleID))
        return NSWorkspace.shared
            .runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (bundleID: String, name: String)? in
                guard let bundleID = app.bundleIdentifier, !existing.contains(bundleID),
                      bundleID != Bundle.main.bundleIdentifier
                else {
                    return nil
                }
                return (bundleID, app.localizedName ?? bundleID)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func binding(for rule: VietnameseAppRule) -> Binding<VietnameseAppRule> {
        Binding {
            appRules.first { $0.id == rule.id } ?? rule
        } set: { newValue in
            if let index = appRules.firstIndex(where: { $0.id == rule.id }) {
                appRules[index] = newValue
            }
        }
    }

    private func binding(for macro: VietnameseMacro) -> Binding<VietnameseMacro> {
        Binding {
            macros.first { $0.id == macro.id } ?? macro
        } set: { newValue in
            if let index = macros.firstIndex(where: { $0.id == macro.id }) {
                macros[index] = newValue
            }
        }
    }
}

private struct AppRuleRow: View {
    @Binding var rule: VietnameseAppRule
    var remove: () -> Void

    var body: some View {
        HStack {
            Text(verbatim: rule.name)
            Spacer()
            Toggle(isOn: $rule.excluded) {
                Text(verbatim: "Luôn tiếng Anh")
            }
            .fixedSize()
            Picker(selection: $rule.injection) {
                ForEach(VietnameseInjectionMode.allCases, id: \.self) { mode in
                    Text(verbatim: mode.title).tag(mode)
                }
            } label: {
                Text(verbatim: "Chèn chữ")
            }
            .fixedSize()
            .disabled(rule.excluded)
            Button(action: remove) {
                Text(verbatim: "Xoá")
            }
        }
    }
}

private struct MacroRow: View {
    @Binding var macro: VietnameseMacro
    var remove: () -> Void

    var body: some View {
        HStack {
            TextField(text: $macro.shortcut) {
                Text(verbatim: "chữ tắt")
            }
            .frame(width: 100)
            Text(verbatim: "→")
            TextField(text: $macro.expansion) {
                Text(verbatim: "cụm đầy đủ")
            }
            Button(action: remove) {
                Text(verbatim: "Xoá")
            }
        }
    }
}
