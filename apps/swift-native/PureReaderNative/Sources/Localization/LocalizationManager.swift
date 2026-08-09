//
//  LocalizationManager.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-24.
//

import Foundation
import AppKit
import Combine
import os

/// 应用支持的语言枚举
public enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case german = "de"
    case french = "fr"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "中文"
        case .german: return "Deutsch"
        case .french: return "Français"
        }
    }

    public static func from(localeString: String) -> AppLanguage {
        if localeString.hasPrefix("zh") {
            return .simplifiedChinese
        } else if localeString.hasPrefix("de") {
            return .german
        } else if localeString.hasPrefix("fr") {
            return .french
        }
        return .english
    }
}

/// 解耦的语言管理与系统菜单联动服务 (LocalizationManager)
@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    @Published public private(set) var currentLanguage: AppLanguage = .english

    private let logger = Logger(subsystem: "com.purereader.app", category: "LocalizationManager")
    private var isUpdatingMenu = false
    private var pendingUpdateNeeded = false
    private var updateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// 本地化字符串内存缓存 [AppLanguage: [Key: LocalizedString]]
    private var stringCaches: [AppLanguage: [String: String]] = [:]

    private init() {
        setupMenuRebuildObservers()
    }

    /// 监听 AppKit 菜单生命周期、窗口焦点变动与 App 激活通知
    private func setupMenuRebuildObservers() {
        // 1. SwiftUI / AppKit 动态添加菜单项
        NotificationCenter.default.publisher(for: NSMenu.didAddItemNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleMenuUpdate(reason: "NSMenu.didAddItemNotification")
            }
            .store(in: &cancellables)

        // 2. 菜单跟踪结束（用户点击菜单项松开鼠标瞬间）
        NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleMenuUpdate(reason: "NSMenu.didEndTrackingNotification")
            }
            .store(in: &cancellables)

        // 3. 应用获得焦点
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleMenuUpdate(reason: "NSApplication.didBecomeActiveNotification")
            }
            .store(in: &cancellables)

        // 4. 窗口/Sheet 弹窗关闭并重获焦点
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleMenuUpdate(reason: "NSWindow.didBecomeKeyNotification")
            }
            .store(in: &cancellables)
    }

    /// 防抖与队列化菜单更新，确保 SwiftUI 在高频变动 .commands 时绝不遗漏菜单渲染
    public func scheduleMenuUpdate(reason: String = "Manual Call") {
        if isUpdatingMenu {
            pendingUpdateNeeded = true
            logger.debug("🌐 [LocalizationManager] Menu update in progress. Queued pending update. Reason: \(reason, privacy: .public)")
            return
        }

        updateTask?.cancel()
        updateTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            // 延迟一小帧等待 AppKit 重新布局菜单节点
            try? await Task.sleep(nanoseconds: 30_000_000)
            if !Task.isCancelled {
                self.logger.info("🌐 [LocalizationManager] Executing scheduled system menu update. Reason: \(reason, privacy: .public)")
                self.updateSystemMenuLanguage()
            }
        }
    }

    /// 阶梯式连续更新（针对切换语言后的 Popover/Sheet 动画过渡期）
    private func scheduleStaggeredUpdates() {
        let delaysInMs = [50, 150, 300, 500]
        for delay in delaysInMs {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
                self?.scheduleMenuUpdate(reason: "Staggered update (\(delay)ms)")
            }
        }
    }

    /// 切换应用语言
    public func setLanguage(_ language: AppLanguage) {
        logger.info("🌐 [LocalizationManager] Changing active language: '\(self.currentLanguage.rawValue, privacy: .public)' -> '\(language.rawValue, privacy: .public)'")
        currentLanguage = language

        // 同步设置进程级 AppleLanguages 语言环境变量
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        // 立即刷新并触发阶梯式补刷，确保动画过渡期 100% 覆盖
        updateSystemMenuLanguage()
        scheduleStaggeredUpdates()
    }

    /// 切换应用语言（根据 locale 字符串如 "en" 或 "zh"）
    public func setLanguage(localeString: String) {
        let lang = AppLanguage.from(localeString: localeString)
        setLanguage(lang)
    }

    /// 加载指定语言的 Localizable.strings 字典
    private func loadStrings(for language: AppLanguage) -> [String: String] {
        if let cached = stringCaches[language] {
            return cached
        }

        let langCode = language.rawValue
        let candidates = [
            langCode,
            langCode.lowercased(),
            langCode.replacingOccurrences(of: "-", with: "_"),
            String(langCode.prefix(2))
        ]

        for code in candidates {
            if let path = Bundle.module.path(forResource: "Localizable", ofType: "strings", inDirectory: "\(code).lproj") ??
                          Bundle.module.path(forResource: "Localizable", ofType: "strings", inDirectory: "\(code.lowercased()).lproj"),
               let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
                logger.info("🌐 [LocalizationManager] Successfully loaded \(dict.count) localized strings for '\(language.rawValue, privacy: .public)' from '\(path, privacy: .public)'")
                stringCaches[language] = dict
                return dict
            }
        }

        logger.error("❌ [LocalizationManager] Failed to locate Localizable.strings for '\(language.rawValue, privacy: .public)' in Bundle.module")
        return [:]
    }

    /// 根据 Key 获取对应语言的本地化字符串（直接从对应语言包字典查询）
    public func string(for key: String) -> String {
        let dict = loadStrings(for: currentLanguage)
        if let val = dict[key] {
            return val
        }
        logger.warning("⚠️ [LocalizationManager] Key '\(key, privacy: .public)' not found in language '\(self.currentLanguage.rawValue, privacy: .public)'")
        return key
    }

    /// 动态刷新 NSMenu 系统菜单栏标题（可传入特定 NSMenu 进行测试）
    @discardableResult
    public func updateSystemMenuLanguage(targetMenu: NSMenu? = nil) -> Int {
        guard let mainMenu = targetMenu ?? NSApplication.shared.mainMenu else {
            logger.warning("⚠️ [LocalizationManager] NSApplication.shared.mainMenu is nil (headless mode or before launch)")
            return 0
        }

        isUpdatingMenu = true
        defer {
            isUpdatingMenu = false
            if pendingUpdateNeeded {
                pendingUpdateNeeded = false
                scheduleMenuUpdate(reason: "Pending update queue drain")
            }
        }

        // 双向标题与本地化 Key 字典映射表（覆盖英文、中文、德语、法语各种系统默认词条变体）
        let keyMapping: [String: String] = [
            // Top Level System Menus
            "File": "file",
            "文件": "file",
            "Datei": "file",
            "Fichier": "file",

            "Edit": "edit",
            "编辑": "edit",
            "Bearbeiten": "edit",
            "Édition": "edit",

            "View": "view",
            "显示": "view",
            "视图": "view",
            "Darstellung": "view",
            "Présentation": "view",

            "Window": "window",
            "窗口": "window",
            "Fenster": "window",
            "Fenêtre": "window",

            "Help": "help",
            "帮助": "help",
            "Hilfe": "help",
            "Aide": "help",

            // Custom Top Level & Submenus
            "Encoding": "encoding",
            "编码": "encoding",
            "Kodierung": "encoding",
            "Encodage": "encoding",

            "Theme": "theme",
            "外观主题": "theme",
            "主题": "theme",
            "Erscheinungsbild": "theme",
            "Thème": "theme",

            "Language": "language",
            "语言": "language",
            "Sprache": "language",
            "Langue": "language",

            // Submenu Items
            "Open...": "open_file",
            "打开...": "open_file",
            "Öffnen...": "open_file",
            "Ouvrir...": "open_file",

            "Zoom In": "zoom_in",
            "放大": "zoom_in",
            "Vergrößern": "zoom_in",
            "Zoom avant": "zoom_in",

            "Zoom Out": "zoom_out",
            "缩小": "zoom_out",
            "Verkleinern": "zoom_out",
            "Zoom arrière": "zoom_out",

            "Actual Size": "actual_size",
            "实际大小": "actual_size",
            "Originalgröße": "actual_size",
            "Taille réelle": "actual_size",

            "Toggle Sidebar": "toggle_sidebar",
            "切换侧边栏": "toggle_sidebar",
            "Seitenleiste umschalten": "toggle_sidebar",
            "Masquer/Afficher la barre latérale": "toggle_sidebar",

            // Themes
            "Day": "theme_day",
            "日光": "theme_day",
            "Tag": "theme_day",
            "Jour": "theme_day",

            "Night": "theme_night",
            "夜间": "theme_night",
            "Nacht": "theme_night",
            "Nuit": "theme_night",

            "Muji": "theme_muji",
            "纸感": "theme_muji",

            "Forest": "theme_forest",
            "护眼": "theme_forest",
            "Wald": "theme_forest",
            "Forêt": "theme_forest"
        ]

        var updatedCount = 0

        func updateMenu(_ menu: NSMenu) {
            for item in menu.items {
                // 1. 尝试通过 item.title 匹配 key
                var matchedKey: String? = keyMapping[item.title]

                // 2. 若 item.title 未匹配到，尝试通过 item.submenu?.title 匹配 key
                if matchedKey == nil, let subTitle = item.submenu?.title {
                    matchedKey = keyMapping[subTitle]
                }

                if let key = matchedKey {
                    let newTitle = string(for: key)

                    if item.title != newTitle {
                        logger.info("🌐 [LocalizationManager] Item title updated: '\(item.title, privacy: .public)' -> '\(newTitle, privacy: .public)' (key: \(key, privacy: .public))")
                        item.title = newTitle
                        updatedCount += 1
                    }

                    if let submenu = item.submenu {
                        if submenu.title != newTitle {
                            logger.info("🌐 [LocalizationManager] Submenu title updated: '\(submenu.title, privacy: .public)' -> '\(newTitle, privacy: .public)' (key: \(key, privacy: .public))")
                            submenu.title = newTitle
                            updatedCount += 1
                        }
                    }
                } else if !item.title.isEmpty && item.title != "PureReader" && !item.isSeparatorItem {
                    logger.notice("ℹ️ [LocalizationManager] Unmapped menu item encountered: '\(item.title, privacy: .public)'")
                }

                // 递归更新深层子菜单
                if let submenu = item.submenu {
                    updateMenu(submenu)
                }
            }
        }

        updateMenu(mainMenu)
        logger.info("✅ [LocalizationManager] Menu update finished. Current language: '\(self.currentLanguage.rawValue, privacy: .public)', updated \(updatedCount) titles")
        return updatedCount
    }
}
