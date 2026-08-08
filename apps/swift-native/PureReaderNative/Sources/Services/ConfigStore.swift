//
//  ConfigStore.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-23.
//
//  对应 Flutter: lib/reader_state.dart 中的 _loadSettings 及各 update* 方法
//  UserDefaults key 与 Flutter SharedPreferences key 完全一致：
//    lang / theme / fontSize / font
//

import Foundation

struct ConfigStore {

    private let defaults = UserDefaults.standard

    // MARK: - Public interface

    /// 从 UserDefaults 读取配置，返回 ReaderConfig。
    /// 对应 Flutter ReaderNotifier._loadSettings()
    func load() -> ReaderConfig {
        var c = ReaderConfig()

        // ── 语言 (key: "lang") ──────────────────────────────────────────────
        // 对应 Flutter: prefs.getString('lang') ?? Platform.localeName.split('_')[0]
        if let lang = defaults.string(forKey: "lang") {
            c.locale = lang
        } else {
            // Fallback：读取系统语言，zh 开头返回 "zh"，否则 "en"
            // 对应 Flutter: Platform.localeName.split('_')[0]
            let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
            c.locale = systemLang.hasPrefix("zh") ? "zh" : "en"
        }

        // ── 主题 id (key: "theme") ──────────────────────────────────────────
        // 对应 Flutter: prefs.getString('theme') ?? 'day'
        if let themeId = defaults.string(forKey: "theme") {
            c.themeId = themeId
        }
        // 默认值已在 ReaderConfig 的声明中设置为 "day"，无需额外处理

        // ── 字体大小 (key: "fontSize") ──────────────────────────────────────
        // 对应 Flutter: prefs.getDouble('fontSize')?.clamp(12.0, 40.0) ?? 18.0
        // UserDefaults.double(forKey:) 在 key 不存在时返回 0.0，以此判断是否已存储
        let fs = defaults.double(forKey: "fontSize")
        if fs > 0 {
            // 越界保护：clamp 到 [12.0, 40.0]，对应 Flutter 的 clamp(12.0, 40.0)
            c.fontSize = min(max(fs, 12.0), 40.0)
        }
        // fs == 0 说明从未存储，保留 ReaderConfig 默认值 18.0

        // ── 字体 (key: "font") ──────────────────────────────────────────────
        // 对应 Flutter: prefs.getString('font')
        if let font = defaults.string(forKey: "font") {
            c.fontFamily = font
        }

        return c
    }

    /// 将配置持久化到 UserDefaults。
    /// 对应 Flutter: 各 update* 方法中的 prefs.setString / prefs.setDouble 调用
    func save(_ c: ReaderConfig) {
        defaults.set(c.locale,     forKey: "lang")
        defaults.set(c.themeId,    forKey: "theme")
        defaults.set(c.fontSize,   forKey: "fontSize")
        defaults.set(c.fontFamily, forKey: "font")
    }
}


