//
//  LocalizationManager.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-24.
//

import Foundation
import AppKit
import Combine

/// 应用支持的语言枚举
public enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "中文"
        }
    }

    public static func from(localeString: String) -> AppLanguage {
        if localeString.hasPrefix("zh") {
            return .simplifiedChinese
        }
        return .english
    }
}

/// 解耦的语言管理与系统菜单联动服务 (LocalizationManager)
@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    @Published public private(set) var currentLanguage: AppLanguage = .english

    private init() {}

    /// 切换应用语言
    public func setLanguage(_ language: AppLanguage) {
        currentLanguage = language

        // 同步设置进程级 AppleLanguages 语言环境变量
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        updateSystemMenuLanguage()
    }

    /// 切换应用语言（根据 locale 字符串如 "en" 或 "zh"）
    public func setLanguage(localeString: String) {
        let lang = AppLanguage.from(localeString: localeString)
        setLanguage(lang)
    }

    /// 根据 Key 获取对应语言的本地化字符串
    public func string(for key: String) -> String {
        let langCode = currentLanguage.rawValue
        let candidates = [langCode, langCode.lowercased(), langCode.replacingOccurrences(of: "-", with: "_"), String(langCode.prefix(2))]

        for code in candidates {
            if let path = Bundle.module.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                let localized = bundle.localizedString(forKey: key, value: key, table: nil as String?)
                if localized != key {
                    return localized
                }
            }
        }
        return Bundle.module.localizedString(forKey: key, value: key, table: nil as String?)
    }

    /// 动态刷新 AppKit NSApp.mainMenu 系统菜单栏标题
    public func updateSystemMenuLanguage() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }

        // 包含所有顶层系统菜单与子选项的双向标题映射表
        let keyMapping: [String: String] = [
            // Top Level System Menus
            "File": "file",
            "文件": "file",
            "Edit": "edit",
            "编辑": "edit",
            "View": "view",
            "显示": "view",
            "视图": "view",
            "Window": "window",
            "窗口": "window",
            "Help": "help",
            "帮助": "help",

            // Custom Top Level & Submenus
            "Encoding": "encoding",
            "编码": "encoding",
            "Theme": "theme",
            "外观主题": "theme",
            "主题": "theme",
            "Language": "language",
            "语言": "language",

            // Submenu Items
            "Open...": "open_file",
            "打开...": "open_file",
            "Zoom In": "zoom_in",
            "放大": "zoom_in",
            "Zoom Out": "zoom_out",
            "缩小": "zoom_out",
            "Actual Size": "actual_size",
            "实际大小": "actual_size",
            "Toggle Sidebar": "toggle_sidebar",
            "切换侧边栏": "toggle_sidebar",

            // Themes
            "Day": "theme_day",
            "日光": "theme_day",
            "Night": "theme_night",
            "夜间": "theme_night",
            "Muji": "theme_muji",
            "纸感": "theme_muji",
            "Forest": "theme_forest",
            "护眼": "theme_forest"
        ]

        func updateMenu(_ menu: NSMenu) {
            for item in menu.items {
                if let key = keyMapping[item.title] {
                    let newTitle = string(for: key)
                    item.title = newTitle
                }
                if let submenu = item.submenu {
                    if let key = keyMapping[submenu.title] {
                        let newTitle = string(for: key)
                        submenu.title = newTitle
                        item.title = newTitle
                    }
                    updateMenu(submenu)
                }
            }
        }

        updateMenu(mainMenu)
    }
}
