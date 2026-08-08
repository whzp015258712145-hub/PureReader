//
//  WebViewRenderer.swift
//  PureReader
//
//  Spec D — D1: EPUB/MOBI/AZW3 渲染器
//  使用系统 WKWebView，无 Method Channel，窗口调整 <5ms 原生 reflow
//

import WebKit
import SwiftUI

struct WebViewRenderer: NSViewRepresentable {
    let content: EbookContent
    @Binding var config: ReaderConfig
    /// ViewModel 弱引用，makeNSView 时注册 scrollToChapterHandler
    weak var vm: ReaderViewModel?

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> WKWebView {
        #if DEBUG
        print("🧭 [SwiftNav] WebViewRenderer.makeNSView format=\(content.format), chapters=\(content.chapters.count), hasHTML=\(content.htmlContent != nil)")
        #endif
        let ucc = WKUserContentController()
        ucc.add(context.coordinator, name: "onScroll")
        ucc.add(context.coordinator, name: "onLoad")
        ucc.add(context.coordinator, name: "onScrollDiag")

        // 通过 WKUserScript 在 document 加载完成后注入 JS 控制函数
        // 这样无论 HTML 内容里是否含有 </script> 导致内嵌脚本截断，JS 函数都能保证存在
        let bridgeJS = """
        function scrollToChapter(i){var el=document.getElementById('chapter-'+i);if(el){el.scrollIntoView({behavior:'smooth',block:'start'});return true;}return false;}
        function updateTheme(bg,fg){document.documentElement.style.setProperty('--bg-color',bg);document.documentElement.style.setProperty('--text-color',fg);}
        function updateFontSize(s){document.documentElement.style.setProperty('--font-size',s+'px');}
        function updateLineHeight(h){document.documentElement.style.setProperty('--line-height',h);}
        function updateFontFamily(f){document.documentElement.style.setProperty('--font-family',f+",\'PingFang SC\',\'Hiragino Sans\',\'Microsoft YaHei\',sans-serif");}
        """
        let userScript = WKUserScript(source: bridgeJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        ucc.addUserScript(userScript)

        let cfg = WKWebViewConfiguration()
        cfg.userContentController = ucc

        let webView = WKWebView(frame: .zero, configuration: cfg)
        webView.navigationDelegate = context.coordinator
        // 透明背景，颜色完全由 CSS 变量控制，不与系统主题冲突
        webView.setValue(false, forKey: "drawsBackground")

        context.coordinator.webView = webView
        context.coordinator.load(content: content, config: config)
        // 将 Coordinator.scrollToChapter 注册到 ViewModel，供 SidebarView TOC 点击调用
        let coordinator = context.coordinator
        vm?.scrollToChapterHandler = { [weak coordinator] index in
            coordinator?.scrollToChapter(index)
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        #if DEBUG
        print("🧭 [SwiftNav] WebViewRenderer.updateNSView loadedContentId=\(String(describing: coordinator.loadedContentId)) newContentId=\(content.id) isLoaded=\(coordinator.isLoaded)")
        #endif
        // 内容切换时重新加载（比较 UUID，精确判断）
        if coordinator.loadedContentId != content.id {
            #if DEBUG
            print("🧭 [SwiftNav] updateNSView detected content switch -> reload")
            #endif
            coordinator.load(content: content, config: config)
            return
        }
        // 仅配置变化时做字段级 diff，避免无效 JS 调用
        coordinator.applyConfigIfNeeded(config)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        /// WebView 是否已完成首次 navigation（didFinish 触发后为 true）
        var isLoaded = false
        /// 当前已加载内容的 UUID，用于 updateNSView 中的内容变化判断
        var loadedContentId: UUID?
        /// 缓存当前内容章节，用于 TOC 跳转诊断日志
        var currentChapters: [EbookContent.Chapter] = []
        /// 缓存上次应用的 config，做字段级 diff
        var lastConfig: ReaderConfig?

        /// 加载新内容（对应 Flutter webview 的 loadData()，但无 Method Channel / 大小限制）
        func load(content: EbookContent, config: ReaderConfig) {
            guard let wv = webView, let html = content.htmlContent else {
                #if DEBUG
                print("🧭 [SwiftNav] Coordinator.load skipped: webView/html nil, webViewReady=\(webView != nil), hasHTML=\(content.htmlContent != nil)")
                #endif
                return
            }
            #if DEBUG
            print("🧭 [SwiftNav] Coordinator.load contentId=\(content.id), format=\(content.format), chapters=\(content.chapters.count), htmlSize=\(html.count)")
            #endif
            isLoaded = false
            loadedContentId = content.id
            currentChapters = content.chapters
            lastConfig = config
            let hydratedHTML = htmlByApplyingInitialConfig(html, config: config)
            // 统一使用 loadHTMLString + baseURL: temporaryDirectory
            // file:// origin 确保 WKWebView JS 上下文可信，message handler 正常工作
            wv.loadHTMLString(hydratedHTML, baseURL: FileManager.default.temporaryDirectory)
        }

        /// 字段级 diff，仅在 isLoaded 后执行，避免页面未就绪时 JS 失效
        func applyConfigIfNeeded(_ config: ReaderConfig) {
            guard isLoaded else {
                #if DEBUG
                print("🧭 [SwiftNav] applyConfigIfNeeded deferred: page not loaded")
                #endif
                // 记录最新 config，等 didFinish 后统一应用
                lastConfig = config
                return
            }
            guard let last = lastConfig else {
                #if DEBUG
                print("🧭 [SwiftNav] applyConfigIfNeeded applyAll: no lastConfig")
                #endif
                applyAll(config)
                lastConfig = config
                return
            }
            // 逐字段比较，对应 Flutter didUpdateWidget 的逐字段对比策略
            if last.themeId    != config.themeId    {
                #if DEBUG
                print("🧭 [SwiftNav] config diff: theme \(last.themeId) -> \(config.themeId)")
                #endif
                updateTheme(config.theme)
            }
            if last.fontSize   != config.fontSize   {
                #if DEBUG
                print("🧭 [SwiftNav] config diff: fontSize \(last.fontSize) -> \(config.fontSize)")
                #endif
                updateFontSize(config.fontSize)
            }
            if last.lineHeight != config.lineHeight {
                #if DEBUG
                print("🧭 [SwiftNav] config diff: lineHeight \(last.lineHeight) -> \(config.lineHeight)")
                #endif
                updateLineHeight(config.lineHeight)
            }
            if last.fontFamily != config.fontFamily {
                #if DEBUG
                print("🧭 [SwiftNav] config diff: fontFamily \(last.fontFamily) -> \(config.fontFamily)")
                #endif
                updateFontFamily(config.fontFamily)
            }
            lastConfig = config
        }

        private func applyAll(_ config: ReaderConfig) {
            updateTheme(config.theme)
            updateFontSize(config.fontSize)
            updateLineHeight(config.lineHeight)
            updateFontFamily(config.fontFamily)
        }

        private func htmlByApplyingInitialConfig(_ html: String, config: ReaderConfig) -> String {
            if !html.contains("--bg-color:") {
                return HTMLTemplateBuilder.build(bodyHTML: html, config: config)
            }
            let initialFamily = config.fontFamily + ", 'PingFang SC', 'Hiragino Sans', 'Microsoft YaHei', sans-serif"
            return html
                .replacingOccurrences(of: "--bg-color: #F9F7F1;", with: "--bg-color: \(config.theme.backgroundColor);")
                .replacingOccurrences(of: "--text-color: #333333;", with: "--text-color: \(config.theme.textColor);")
                .replacingOccurrences(of: "--font-size: 18px;", with: "--font-size: \(config.fontSize)px;")
                .replacingOccurrences(of: "--line-height: 1.6;", with: "--line-height: \(config.lineHeight);")
                .replacingOccurrences(of: "--font-family: -apple-system, 'PingFang SC', 'Hiragino Sans', 'Microsoft YaHei', sans-serif;", with: "--font-family: \(initialFamily);")
        }

        /// 章节跳转，由 SidebarView TOC 点击后调用
        /// 对应 HTML 中 buildFooter() 注入的 scrollToChapter(index) 函数
        func scrollToChapter(_ index: Int) {
            #if DEBUG
            print("🧭 [SwiftNav] Coordinator.scrollToChapter index=\(index), isLoaded=\(isLoaded), hasWebView=\(webView != nil)")
            #endif
            webView?.evaluateJavaScript("scrollToChapter(\(index))") { [weak self] result, error in
                #if DEBUG
                if let error {
                    print("🧭 [SwiftNav] scrollToChapter(\(index)) JS error=\(error.localizedDescription)")
                } else {
                    print("🧭 [SwiftNav] scrollToChapter(\(index)) result=\(String(describing: result))")
                    let didFailJump: Bool
                    if let ok = result as? Bool {
                        didFailJump = !ok
                    } else if let num = result as? NSNumber {
                        didFailJump = num.intValue == 0
                    } else {
                        didFailJump = false
                    }
                    if didFailJump {
                        let title = self?.chapterTitle(at: index) ?? ""
                        print("🧭 [SwiftNav] TOC jump failed index=\(index), title=\(title)")
                    }
                }
                #endif
            }
        }

        private func chapterTitle(at index: Int) -> String {
            guard currentChapters.indices.contains(index) else { return "" }
            return currentChapters[index].title
        }

        private func updateTheme(_ theme: ReaderTheme) {
            eval("updateTheme('\(theme.backgroundColor)', '\(theme.textColor)')")
        }
        private func updateFontSize(_ s: Double)  { eval("updateFontSize(\(s))") }
        private func updateLineHeight(_ h: Double) { eval("updateLineHeight(\(h))") }
        private func updateFontFamily(_ f: String) { eval("updateFontFamily('\(f)')") }

        private func eval(_ js: String) {
            webView?.evaluateJavaScript(js) { result, error in
                #if DEBUG
                if let error {
                    print("🧭 [SwiftNav] JS eval failed: \(js) error=\(error.localizedDescription)")
                } else {
                    print("🧭 [SwiftNav] JS eval ok: \(js) result=\(String(describing: result))")
                }
                #endif
            }
        }

        // MARK: WKNavigationDelegate

        func webView(_ wv: WKWebView, didFinish nav: WKNavigation!) {
            isLoaded = true
            #if DEBUG
            print("🧭 [SwiftNav] webView didFinish, contentId=\(String(describing: loadedContentId))")
            #endif
            wv.evaluateJavaScript("document.querySelectorAll('[id^=\\\"chapter-\\\"]').length") { result, error in
                #if DEBUG
                if let error {
                    print("🧭 [SwiftNav] chapter anchor count JS error=\(error.localizedDescription)")
                } else {
                    print("🧭 [SwiftNav] chapter anchor count=\(String(describing: result))")
                }
                #endif
            }
            // 滚动诊断：原生侧主动评估，确保即使 onScrollDiag 消息未到达也有日志
            #if DEBUG
            let diagJS = """
            (function() {
                var sh = document.documentElement.scrollHeight;
                var ch = document.documentElement.clientHeight;
                var htmlOY = getComputedStyle(document.documentElement).overflowY;
                var bodyOY = getComputedStyle(document.body).overflowY;
                return JSON.stringify({scrollHeight:sh,clientHeight:ch,htmlOverflowY:htmlOY,bodyOverflowY:bodyOY,canScroll:sh>ch});
            })()
            """
            wv.evaluateJavaScript(diagJS) { result, error in
                if let error {
                    print("🧭 [ScrollDiag] JS error=\(error.localizedDescription)")
                } else if let json = result as? String {
                    print("🧭 [ScrollDiag] \(json)")
                }
            }
            #endif
            // 页面就绪后应用在加载期间积累的最新 config
            // 延迟 100ms 确保 WKWebView JS 上下文完全初始化（大文件 loadFileURL 场景）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                // 先诊断 JS 函数是否真的存在，确认 script 块未被截断
                wv.evaluateJavaScript("typeof updateTheme") { result, _ in
                    #if DEBUG
                    print("🧭 [SwiftNav] typeof updateTheme=\(String(describing: result))")
                    #endif
                    if let t = result as? String, t == "function" {
                        if let config = self?.lastConfig { self?.applyAll(config) }
                    } else {
                        // JS 函数不存在，说明 script 块被截断，尝试重新注入
                        #if DEBUG
                        print("🧭 [SwiftNav] ⚠️ updateTheme not found — script block likely truncated by </script> in content")
                        #endif
                        let reInjectJS = """
                        (function(){
                        if(typeof updateTheme!=='function'){
                            window.updateTheme=function(bg,fg){document.documentElement.style.setProperty('--bg-color',bg);document.documentElement.style.setProperty('--text-color',fg);};
                            window.updateFontSize=function(s){document.documentElement.style.setProperty('--font-size',s+'px');};
                            window.updateLineHeight=function(h){document.documentElement.style.setProperty('--line-height',h);};
                            window.updateFontFamily=function(f){document.documentElement.style.setProperty('--font-family',f+",\'PingFang SC\',sans-serif");};
                            window.scrollToChapter=function(i){var el=document.getElementById('chapter-'+i);if(el){el.scrollIntoView({behavior:'smooth',block:'start'});return true;}return false;};
                        }
                        })()
                        """
                        wv.evaluateJavaScript(reInjectJS) { _, err in
                            #if DEBUG
                            if let err { print("🧭 [SwiftNav] re-inject error=\(err.localizedDescription)") }
                            else { print("🧭 [SwiftNav] re-inject ok") }
                            #endif
                            if let config = self?.lastConfig { self?.applyAll(config) }
                        }
                    }
                }
            }
        }

        // MARK: WKScriptMessageHandler
        // 接收 HTML 中 webkit.messageHandlers.xxx.postMessage() 的消息
        // 对应 Flutter flutter_inappwebview 的 callHandler 回调

        func userContentController(_ ucc: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "onScroll":
                // message.body 为 JS 传来的 progress (Double 0.0~1.0)
                if let progress = message.body as? Double {
                    #if DEBUG
                    print("🧭 [SwiftNav] JS onScroll progress=\(String(format: "%.3f", progress))")
                    #endif
                    _ = progress  // 可扩展：更新进度条 / 持久化进度
                }
            case "onLoad":
                #if DEBUG
                print("🧭 [SwiftNav] JS onLoad received")
                #endif
                break  // 页面 load 事件，可扩展
            case "onScrollDiag":
                #if DEBUG
                if let body = message.body as? [String: Any] {
                    let sh  = body["scrollHeight"] as? Int ?? -1
                    let ch  = body["clientHeight"] as? Int ?? -1
                    let hoy = body["htmlOverflowY"] as? String ?? "?"
                    let boy = body["bodyOverflowY"] as? String ?? "?"
                    let can = body["canScroll"] as? Bool ?? false
                    print("🧭 [ScrollDiag] scrollHeight=\(sh) clientHeight=\(ch) htmlOverflowY=\(hoy) bodyOverflowY=\(boy) canScroll=\(can)")
                }
                #endif
                break
            default:
                #if DEBUG
                print("🧭 [SwiftNav] JS message unknown=\(message.name)")
                #endif
                break
            }
        }
    }
}

