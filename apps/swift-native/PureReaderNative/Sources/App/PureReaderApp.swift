//
//  PureReaderApp.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import SwiftUI

@main
struct PureReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vm = ReaderViewModel()
    @State private var showSettings = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .frame(minWidth: 900, minHeight: 600)
                .background(vm.config.theme.backgroundColorValue)
                // 响应 SidebarView 的设置按钮通知
                .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
                    showSettings = true
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView().environmentObject(vm)
                }
                // Finder 双击 / 拖入 Dock 图标打开文件（对应 Flutter onOpenURL）
                .onOpenURL { url in
                    Task { await vm.loadBook(path: url.path) }
                }
                // AppDelegate application(_:open:) 的通知转发
                .onReceive(NotificationCenter.default.publisher(for: .openFileURL)) { note in
                    guard let url = note.object as? URL else { return }
                    Task { await vm.loadBook(path: url.path) }
                }
        }
        .defaultSize(width: 1100, height: 800)
        .commands {
            // 替换默认的 New Item，改为 Open（对应 Flutter PlatformMenu('文件')）
            CommandGroup(replacing: .newItem) {
                Button(vm.l("open_file")) {
                    vm.openFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            // 编码菜单（对应 Flutter PlatformMenu('编码')）
            CommandMenu(vm.l("encoding")) {
                Button("Auto (Detect)")            { vm.reloadWithEncoding(nil) }
                Button("UTF-8 (Universal)")         { vm.reloadWithEncoding("utf-8") }
                Button("GBK (Chinese)")             { vm.reloadWithEncoding("gbk") }
                Button("Shift-JIS (Japanese)")      { vm.reloadWithEncoding("shift_jis") }
                Button("Windows-1252 (Western)")    { vm.reloadWithEncoding("windows-1252") }
                Button("Windows-1251 (Cyrillic)")   { vm.reloadWithEncoding("windows-1251") }
            }

            // 视图菜单（对应 Flutter PlatformMenu('视图')）
            CommandGroup(replacing: .toolbar) {
                Button(vm.l("zoom_in")) {
                    vm.updateFontSize(vm.config.fontSize * 1.1)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button(vm.l("zoom_out")) {
                    vm.updateFontSize(vm.config.fontSize * 0.9)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button(vm.l("actual_size")) {
                    vm.updateFontSize(18.0)
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button(vm.l("toggle_sidebar")) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        vm.isSidebarCollapsed.toggle()
                    }
                }
                .keyboardShortcut("`", modifiers: .command)
            }

            // 主题菜单（对应 Flutter PlatformMenu('外观主题')）
            CommandMenu(vm.l("theme")) {
                Button(vm.l("theme_day"))    { vm.setTheme("day") }
                    .keyboardShortcut("1", modifiers: [.command, .shift])
                Button(vm.l("theme_night"))  { vm.setTheme("night") }
                    .keyboardShortcut("2", modifiers: [.command, .shift])
                Button(vm.l("theme_muji"))   { vm.setTheme("muji") }
                    .keyboardShortcut("3", modifiers: [.command, .shift])
                Button(vm.l("theme_forest")) { vm.setTheme("forest") }
                    .keyboardShortcut("4", modifiers: [.command, .shift])
            }

            // 语言菜单（对应 Flutter PlatformMenu('语言')）
            CommandMenu(vm.l("language")) {
                Button("English") { vm.setLocale("en") }
                Button("中文")    { vm.setLocale("zh") }
            }
        }

    }
}

