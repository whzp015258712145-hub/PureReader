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
    case traditionalChinese = "zh-Hant"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case japanese = "ja"
    case korean = "ko"
    case italian = "it"
    case russian = "ru"
    case portuguese = "pt"
    case dutch = "nl"
    case polish = "pl"
    case turkish = "tr"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .spanish: return "Español"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .italian: return "Italiano"
        case .russian: return "Русский"
        case .portuguese: return "Português"
        case .dutch: return "Nederlands"
        case .polish: return "Polski"
        case .turkish: return "Türkçe"
        }
    }

    public static func from(localeString: String) -> AppLanguage {
        if localeString.hasPrefix("zh-Hant") || localeString.hasPrefix("zh-TW") || localeString.hasPrefix("zh-HK") {
            return .traditionalChinese
        } else if localeString.hasPrefix("zh") {
            return .simplifiedChinese
        } else if localeString.hasPrefix("de") {
            return .german
        } else if localeString.hasPrefix("fr") {
            return .french
        } else if localeString.hasPrefix("es") {
            return .spanish
        } else if localeString.hasPrefix("ja") {
            return .japanese
        } else if localeString.hasPrefix("ko") {
            return .korean
        } else if localeString.hasPrefix("it") {
            return .italian
        } else if localeString.hasPrefix("ru") {
            return .russian
        } else if localeString.hasPrefix("pt") {
            return .portuguese
        } else if localeString.hasPrefix("nl") {
            return .dutch
        } else if localeString.hasPrefix("pl") {
            return .polish
        } else if localeString.hasPrefix("tr") {
            return .turkish
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
        validateAndLogResourceIntegrity()
    }

    /// 校验并在控制台输出所有受支持语言包的装载日志（防范 App Bundle 打包资源缺失）
    @discardableResult
    public func validateAndLogResourceIntegrity() -> [AppLanguage: Bool] {
        logger.info("🔍 [LocalizationManager] Starting startup resource bundle integrity audit...")
        var results: [AppLanguage: Bool] = [:]
        for lang in AppLanguage.allCases {
            let strings = loadStrings(for: lang)
            let isLoaded = !strings.isEmpty
            results[lang] = isLoaded
            if !isLoaded {
                logger.error("❌ [LocalizationManager] CRITICAL: Language pack '\(lang.rawValue, privacy: .public)' (\(lang.displayName, privacy: .public)) failed to load or is empty! Module bundle path: '\(Bundle.module.bundlePath, privacy: .public)'")
            } else {
                logger.info("✅ [LocalizationManager] Verified language pack '\(lang.rawValue, privacy: .public)' (\(lang.displayName, privacy: .public)) loaded \(strings.count) keys successfully.")
            }
        }
        return results
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

        // 双向标题与本地化 Key 字典映射表（覆盖 14 种语言系统默认词条变体）
        let keyMapping: [String: String] = [
            // Top Level System Menus
            "File": "file",
            "文件": "file",
            "檔案": "file",
            "Datei": "file",
            "Fichier": "file",
            "Archivo": "file",
            "ファイル": "file",
            "파일": "file",
            "Файл": "file",
            "Ficheiro": "file",
            "Bestand": "file",
            "Plik": "file",
            "Dosya": "file",

            "Edit": "edit",
            "编辑": "edit",
            "編輯": "edit",
            "Bearbeiten": "edit",
            "Édition": "edit",
            "Edición": "edit",
            "編集": "edit",
            "편집": "edit",
            "Modifica": "edit",
            "Правка": "edit",
            "Editar": "edit",
            "Bewerken": "edit",
            "Edycja": "edit",
            "Düzen": "edit",

            "View": "view",
            "显示": "view",
            "视图": "view",
            "顯示": "view",
            "Darstellung": "view",
            "Présentation": "view",
            "Visualización": "view",
            "表示": "view",
            "보기": "view",
            "Vista": "view",
            "Вид": "view",
            "Visualizar": "view",
            "Weergave": "view",
            "Widok": "view",
            "Görüntü": "view",

            "Window": "window",
            "窗口": "window",
            "視窗": "window",
            "Fenster": "window",
            "Fenêtre": "window",
            "Ventana": "window",
            "ウィンドウ": "window",
            "윈도우": "window",
            "Finestra": "window",
            "Окно": "window",
            "Janela": "window",
            "Venster": "window",
            "Okno": "window",
            "Pencere": "window",

            "Help": "help",
            "帮助": "help",
            "說明": "help",
            "Hilfe": "help",
            "Aide": "help",
            "Ayuda": "help",
            "ヘルプ": "help",
            "도움말": "help",
            "Aiuto": "help",
            "Справка": "help",
            "Ajuda": "help",
            "Pomoc": "help",
            "Yardım": "help",

            // Custom Top Level & Submenus
            "Encoding": "encoding",
            "编码": "encoding",
            "編碼": "encoding",
            "Kodierung": "encoding",
            "Encodage": "encoding",
            "Codificación": "encoding",
            "エンコード": "encoding",
            "인코딩": "encoding",
            "Codifica": "encoding",
            "Кодировка": "encoding",
            "Codering": "encoding",
            "Kodowanie": "encoding",
            "Kodlama": "encoding",

            "Theme": "theme",
            "外观主题": "theme",
            "主題": "theme",
            "Erscheinungsbild": "theme",
            "Thème": "theme",
            "Tema": "theme",
            "テーマ": "theme",
            "테ма": "theme",
            "Тема": "theme",
            "Thema": "theme",
            "Motyw": "theme",

            "Language": "language",
            "语言": "language",
            "語言": "language",
            "Sprache": "language",
            "Langue": "language",
            "Idioma": "language",
            "言語": "language",
            "언어": "language",
            "Lingua": "language",
            "Язык": "language",
            "Taal": "language",
            "Język": "language",
            "Dil": "language",

            // Submenu Items
            "Open...": "open_file",
            "打开...": "open_file",
            "開啟...": "open_file",
            "Öffnen...": "open_file",
            "Ouvrir...": "open_file",
            "Abrir...": "open_file",
            "開く...": "open_file",
            "열기...": "open_file",
            "Apri...": "open_file",
            "Открыть...": "open_file",
            "Otwórz...": "open_file",
            "Aç...": "open_file",

            "Zoom In": "zoom_in",
            "放大": "zoom_in",
            "Vergrößern": "zoom_in",
            "Zoom avant": "zoom_in",
            "Acercar": "zoom_in",
            "拡大": "zoom_in",
            "확대": "zoom_in",
            "Ingrandisci": "zoom_in",
            "Увеличить": "zoom_in",
            "Ampliar": "zoom_in",
            "Inzoomen": "zoom_in",
            "Powiększ": "zoom_in",
            "Yakınlaştır": "zoom_in",

            "Zoom Out": "zoom_out",
            "缩小": "zoom_out",
            "縮小": "zoom_out",
            "Verkleinern": "zoom_out",
            "Zoom arrière": "zoom_out",
            "Alejar": "zoom_out",
            "축소": "zoom_out",
            "Riduci": "zoom_out",
            "Уменьшить": "zoom_out",
            "Reduzir": "zoom_out",
            "Uitzoomen": "zoom_out",
            "Pomniejsz": "zoom_out",
            "Uzaklaştır": "zoom_out",

            "Actual Size": "actual_size",
            "实际大小": "actual_size",
            "實際大小": "actual_size",
            "Originalgröße": "actual_size",
            "Taille réelle": "actual_size",
            "Tamaño real": "actual_size",
            "原寸大": "actual_size",
            "실제 크기": "actual_size",
            "Dimensioni reali": "actual_size",
            "Реальный размер": "actual_size",
            "Tamanho real": "actual_size",
            "Werkelijke grootte": "actual_size",
            "Wielkość rzeczywista": "actual_size",
            "Gerçek Boyut": "actual_size",

            "Toggle Sidebar": "toggle_sidebar",
            "切换侧边栏": "toggle_sidebar",
            "切換側邊欄": "toggle_sidebar",
            "Seitenleiste umschalten": "toggle_sidebar",
            "Masquer/Afficher la barre latérale": "toggle_sidebar",
            "Mostrar/Ocultar barra lateral": "toggle_sidebar",
            "サイドバーの切り替え": "toggle_sidebar",
            "사이드바 전환": "toggle_sidebar",
            "Mostra/Nascondi barra laterale": "toggle_sidebar",
            "Переключить боковую панель": "toggle_sidebar",
            "Alternar barra lateral": "toggle_sidebar",
            "Zijbalk in-/uitschakelen": "toggle_sidebar",
            "Przełącz pasek boczny": "toggle_sidebar",
            "Kenar Çubuğunu Aç/Kapat": "toggle_sidebar",

            // Themes
            "Day": "theme_day",
            "日光": "theme_day",
            "Tag": "theme_day",
            "Jour": "theme_day",
            "Día": "theme_day",
            "昼間": "theme_day",
            "주간": "theme_day",
            "Giorno": "theme_day",
            "Дневная": "theme_day",
            "Dzień": "theme_day",
            "Gündüz": "theme_day",

            "Night": "theme_night",
            "夜间": "theme_night",
            "夜間": "theme_night",
            "Nacht": "theme_night",
            "Nuit": "theme_night",
            "Noche": "theme_night",
            "야간": "theme_night",
            "Notte": "theme_night",
            "Ночная": "theme_night",
            "Noite": "theme_night",
            "Noc": "theme_night",
            "Gece": "theme_night",

            "Muji": "theme_muji",
            "纸感": "theme_muji",
            "紙感": "theme_muji",
            "無印": "theme_muji",
            "무지": "theme_muji",
            "Бумажная": "theme_muji",

            "Forest": "theme_forest",
            "护眼": "theme_forest",
            "護眼": "theme_forest",
            "Wald": "theme_forest",
            "Forêt": "theme_forest",
            "Bosque": "theme_forest",
            "森林": "theme_forest",
            "숲": "theme_forest",
            "Foresta": "theme_forest",
            "Лесная": "theme_forest",
            "Floresta": "theme_forest",
            "Bos": "theme_forest",
            "Las": "theme_forest",
            "Orman": "theme_forest"
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
