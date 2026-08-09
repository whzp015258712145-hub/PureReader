//
//  EbookContent.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import Foundation

public struct EbookContent: Identifiable {
    public let id = UUID()
    public let format: EbookFormat
    public let filePath: String
    public let title: String?
    public let author: String?
    public let metadata: [String: String]

    // EPUB TOC，anchor 为字符串（对应 HTML id 属性，供 JS getElementById 跳转）
    // MOBI / TXT / PDF 此字段为空数组
    public let chapters: [Chapter]

    // EPUB / MOBI / AZW3 渲染用：EPUBToHTMLConverter 预生成的完整 HTML
    // TXT / PDF 此字段为 nil
    public let htmlContent: String?

    // TXT 分页数组（按字符数切页）
    // MOBI 分页数组（按 5000 字符硬切，对应 Flutter mobi_parser 逻辑）
    // EPUB / PDF 此字段为 nil
    public let pages: [String]?

    // EPUB 专用：true 表示 TOC 残缺，走 spine 顺序拼接路径（spineBased）
    // false 表示 TOC 正常，走章节结构路径（tocBased）
    // 对应 Flutter epub_parser.dart 的 useFallbackRenderer 字段
    // 非 EPUB 格式此字段为 false
    public let useFallbackRenderer: Bool

    public struct Chapter: Identifiable {
        public let id = UUID()
        public let title: String
        public let anchor: String  // HTML element id，对应 JS document.getElementById(anchor)
        public let level: Int
        public let href: String?   // spine 中的文件相对路径，spineBased 路径使用

        public init(title: String, anchor: String, level: Int = 0, href: String? = nil) {
            self.title = title
            self.anchor = anchor
            self.level = level
            self.href = href
        }
    }

    public init(format: EbookFormat,
         filePath: String,
         title: String? = nil,
         author: String? = nil,
         metadata: [String: String] = [:],
         chapters: [Chapter] = [],
         htmlContent: String? = nil,
         pages: [String]? = nil,
         useFallbackRenderer: Bool = false) {
        self.format = format
        self.filePath = filePath
        self.title = title
        self.author = author
        self.metadata = metadata
        self.chapters = chapters
        self.htmlContent = htmlContent
        self.pages = pages
        self.useFallbackRenderer = useFallbackRenderer
    }
}
