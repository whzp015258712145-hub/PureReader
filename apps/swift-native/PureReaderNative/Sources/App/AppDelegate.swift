//
//  AppDelegate.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    // 处理 Finder 双击文件打开（对应 Flutter _initNativeFileListener）
    // SwiftUI 的 .onOpenURL 已能处理大多数情况，
    // 此方法作为补充，覆盖应用已运行时从 Finder 再次打开文件的场景
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        NotificationCenter.default.post(
            name: .openFileURL,
            object: url
        )
    }
}

extension Notification.Name {
    static let openFileURL = Notification.Name("openFileURL")
}


