//
//  ReaderViewModel.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
class ReaderViewModel: ObservableObject {
    @Published var content: EbookContent?
    @Published var config: ReaderConfig
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSidebarCollapsed = false

    private(set) var currentPath: String?
    private let cache = CacheManager()
    private let configStore = ConfigStore()
    /// WebViewRenderer.Coordinator 注册的章节跳转回调，SidebarView TOC 点击时调用
    var scrollToChapterHandler: ((Int) -> Void)? {
        didSet { trace("scrollToChapterHandler 已注册: \(scrollToChapterHandler != nil)") }
    }

    private func trace(_ message: String) {
        #if DEBUG
        print("🧭 [SwiftNav] \(message)")
        #endif
    }

    init() {
        self.config = configStore.load()
    }

    // 对应 Flutter _loadBook()
    func loadBook(path: String, encoding: String? = nil) async {
        trace("loadBook start path=\(path), encoding=\(encoding ?? "auto"), currentPath=\(currentPath ?? "nil")")
        if currentPath == path && encoding == nil {
            trace("loadBook skipped: same path and auto encoding")
            return
        }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            trace("loadBook end isLoading=false")
        }

        do {
            if encoding == nil, let cached = cache.get(path: path) {
                trace("cache hit path=\(path), format=\(cached.format)")
                content = cached
                currentPath = path
                return
            }
            let format = FormatDetector.detect(path: path)
            trace("detected format=\(format)")
            let parser = ParserFactory.create(format: format, encoding: encoding)
            let result = try await parser.parse(filePath: path, encoding: encoding)
            trace("parse done format=\(result.format), chapters=\(result.chapters.count), hasHTML=\(result.htmlContent != nil)")
            if encoding == nil { cache.set(path: path, content: result) }
            content = result
            currentPath = path
        } catch {
            trace("loadBook failed error=\(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // 对应 Flutter _handleManualOpen()
    func openFilePicker() {
        let panel = NSOpenPanel()
        var types: [UTType] = [.pdf, .plainText]
        if let epub = UTType(filenameExtension: "epub") { types.append(epub) }
        if let mobi = UTType(filenameExtension: "mobi") { types.append(mobi) }
        if let azw3 = UTType(filenameExtension: "azw3") { types.append(azw3) }
        if let fb2 = UTType(filenameExtension: "fb2") { types.append(fb2) }
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { await self?.loadBook(path: url.path) }
        }
    }

    // 对应 Flutter openFileWithEncodingProvider 的 RELOAD 逻辑
    func reloadWithEncoding(_ encoding: String?) {
        guard let path = currentPath else {
            trace("reloadWithEncoding ignored: currentPath is nil")
            return
        }
        trace("reloadWithEncoding encoding=\(encoding ?? "auto") path=\(path)")
        Task { await loadBook(path: path, encoding: encoding) }
    }

    // 对应 Flutter ReaderNotifier 各 update 方法
    func updateFontSize(_ size: Double) {
        config.fontSize = min(max(size, 12.0), 40.0)
        configStore.save(config)
    }

    func updateLineHeight(_ h: Double) {
        config.lineHeight = h
        configStore.save(config)
    }

    func updateFontFamily(_ f: String) {
        config.fontFamily = f
        configStore.save(config)
    }

    func setTheme(_ id: String) {
        config.themeId = id
        configStore.save(config)
    }

    func setLocale(_ lang: String) {
        config.locale = lang
        configStore.save(config)
    }

    /// 动态多语言本地化 Lookup（支持随 config.locale 实时切换字符串）
    func l(_ key: String) -> String {
        let lang = config.locale.hasPrefix("zh") ? "zh-Hans" : "en"
        if let path = Bundle.module.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }
        return NSLocalizedString(key, bundle: .module, comment: "")
    }
}

