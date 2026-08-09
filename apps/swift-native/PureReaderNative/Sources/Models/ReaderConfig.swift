//
//  ReaderConfig.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import Foundation

public struct ReaderConfig: Codable {
    public var fontSize:   Double = 18.0
    public var lineHeight: Double = 1.6
    public var fontFamily: String = "-apple-system"
    // 只存主题 id，不存整个 ReaderTheme 对象
    // 避免预设主题颜色更新后用户本地缓存仍保留旧颜色的 bug
    // UserDefaults key: "theme"（与 Flutter SharedPreferences key 一致）
    public var themeId:    String = "day"
    public var locale:     String = "en"

    // 计算属性，不参与 Codable 序列化
    public var theme: ReaderTheme { ReaderTheme.fromId(themeId) }

    public static let `default` = ReaderConfig()

    public init(fontSize:   Double = 18.0,
         lineHeight: Double = 1.6,
         fontFamily: String = "-apple-system",
         themeId:    String = "day",
         locale:     String = "en") {
        self.fontSize   = fontSize
        self.lineHeight = lineHeight
        self.fontFamily = fontFamily
        self.themeId    = themeId
        self.locale     = locale
    }
}
