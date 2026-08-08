//
//  SettingsView.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: ReaderViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(NSLocalizedString("appearance", comment: ""))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(vm.config.theme.textColorValue)

            Group {
                sectionTitle(NSLocalizedString("font_family", comment: ""))
                Picker("", selection: Binding(
                    get: { vm.config.fontFamily },
                    set: { vm.updateFontFamily($0) }
                )) {
                    Text("-apple-system").tag("-apple-system")
                    Text("Serif").tag("Georgia")
                    Text("Monospace").tag("Courier New")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(fontPickerTextColor)
                .tint(fontPickerTextColor)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(fontPickerBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(fontPickerBorderColor, lineWidth: 1)
                )
            }

            sliderRow(
                label: NSLocalizedString("font_size", comment: ""),
                value: Binding(get: { vm.config.fontSize }, set: { vm.updateFontSize($0) }),
                range: 12...40
            )

            sliderRow(
                label: NSLocalizedString("line_height", comment: ""),
                value: Binding(get: { vm.config.lineHeight }, set: { vm.updateLineHeight($0) }),
                range: 1.0...2.5
            )

            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(NSLocalizedString("theme", comment: ""))

                HStack(spacing: 10) {
                    ForEach(ReaderTheme.allThemes) { theme in
                        let isCurrent = theme.id == vm.config.themeId
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.backgroundColorValue)
                            .frame(width: 42, height: 42)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isCurrent
                                            ? vm.config.theme.accentColorValue
                                            : vm.config.theme.textColorValue.opacity(0.22),
                                        lineWidth: isCurrent ? 3 : 1
                                    )
                            )
                            .overlay(
                                Text("A")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(theme.textColorValue.opacity(0.9))
                            )
                            .onTapGesture { vm.setTheme(theme.id) }
                    }
                }
            }

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                Text(NSLocalizedString("ok", comment: ""))
                    .font(.system(size: 20, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundColor(vm.config.theme.backgroundColorValue)
                    .contentShape(Rectangle())
            }
            .keyboardShortcut(.return)
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(vm.config.theme.accentColorValue)
            )
            .contentShape(Rectangle())
        }
        .padding(24)
        .frame(width: 340, height: 420)
        .background(vm.config.theme.backgroundColorValue)
    }

    private var fontPickerTextColor: Color {
        vm.config.theme.textColorValue
    }

    private var fontPickerBackgroundColor: Color {
        vm.config.theme.uiOverlayColorValue
    }

    private var fontPickerBorderColor: Color {
        vm.config.theme.textColorValue.opacity(vm.config.themeId == "night" ? 0.35 : 0.24)
    }

    private func sliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(label)
            Slider(value: value, in: range)
                .tint(vm.config.theme.accentColorValue)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(vm.config.theme.textColorValue.opacity(0.7))
    }
}
