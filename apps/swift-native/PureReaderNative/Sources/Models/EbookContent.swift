//
//  EbookContent.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import Foundation

struct EbookContent: Identifiable {
    let id = UUID()
    let format: EbookFormat
    let filePath: String
    let title: String?
    let author: String?
    let metadata: [String: String]

    // EPUB TOC，anchor 为字符串（对应 HTML id 属性，供 JS getElementById 跳转）
    // MOBI / TXT / PDF 此字段为空数组
    let chapters: [Chapter]

    // EPUB / MOBI / AZW3 渲染用：EPUBToHTMLConverter 预生成的完整 HTML
    // TXT / PDF 此字段为 nil
    let htmlContent: String?

    // TXT 分页数组（按字符数切页）
    // MOBI 分页数组（按 5000 字符硬切，对应 Flutter mobi_parser 逻辑）
    // EPUB / PDF 此字段为 nil
    let pages: [String]?

    // EPUB 专用：true 表示 TOC 残缺，走 spine 顺序拼接路径（spineBased）
    // false 表示 TOC 正常，走章节结构路径（tocBased）
    // 对应 Flutter epub_parser.dart 的 useFallbackRenderer 字段
    // 非 EPUB 格式此字段为 false
    let useFallbackRenderer: Bool

    struct Chapter: Identifiable {
        let id = UUID()
        let title: String
        let anchor: String  // HTML element id，对应 JS document.getElementById(anchor)
        let level: Int
        let href: String?   // spine 中的文件相对路径，spineBased 路径使用
    }

    init(format: EbookFormat,
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
