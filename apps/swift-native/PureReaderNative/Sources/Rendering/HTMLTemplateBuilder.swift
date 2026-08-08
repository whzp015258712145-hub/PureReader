//
//  HTMLTemplateBuilder.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-23.
//

import Foundation

struct HTMLTemplateBuilder {
    /// Wrap raw HTML body or content into a full self-contained WKWebView-ready HTML string
    static func build(
        bodyHTML: String,
        title: String = "PureReader",
        config: ReaderConfig? = nil,
        injectedCSS: String? = nil
    ) -> String {
        let escapedTitle = title
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")

        let theme = config?.theme
        let bgColor = theme?.backgroundColor ?? "#F9F7F1"
        let textColor = theme?.textColor ?? "#333333"
        let fontSize = config?.fontSize ?? 18.0
        let lineHeight = config?.lineHeight ?? 1.6
        let fontFamily = (config?.fontFamily ?? "-apple-system") + ", 'PingFang SC', 'Hiragino Sans', 'Microsoft YaHei', sans-serif"

        let extraCSS: String
        if let injectedCSS = injectedCSS, !injectedCSS.isEmpty {
            extraCSS = "\n/* Injected CSS */\n\(injectedCSS)\n"
        } else {
            extraCSS = ""
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(escapedTitle)</title>
        <style>
        :root {
            --bg-color: \(bgColor);
            --text-color: \(textColor);
            --font-size: \(fontSize)px;
            --line-height: \(lineHeight);
            --font-family: \(fontFamily);
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html { scroll-behavior: smooth; height: auto; min-height: 100%; overflow-y: auto; }
        body {
            background-color: var(--bg-color);
            color: var(--text-color);
            font-size: var(--font-size);
            line-height: var(--line-height);
            font-family: var(--font-family);
            padding: 40px;
            max-width: 800px;
            margin: 0 auto;
            overflow-wrap: anywhere;
            height: auto;
            min-height: 0;
            overflow-y: auto;
        }
        img { max-width: 100%; height: auto; display: block; margin: 20px auto; }
        p { margin-bottom: 1em; text-indent: 2em; }
        h1, h2, h3, h4, h5, h6 { margin-top: 1.5em; margin-bottom: 0.5em; font-weight: 600; }
        blockquote { margin: 1em 0; padding-left: 1em; border-left: 3px solid var(--text-color); opacity: 0.8; }
        a { color: var(--text-color); text-decoration: underline; }
        \(extraCSS)
        </style>
        </head>
        <body>
        \(bodyHTML)
        <script>
        function scrollToChapter(index) {
            var el = document.getElementById('chapter-' + index);
            if (el) { el.scrollIntoView({ behavior: 'smooth', block: 'start' }); return true; }
            return false;
        }
        function updateTheme(bgColor, textColor) {
            document.documentElement.style.setProperty('--bg-color', bgColor);
            document.documentElement.style.setProperty('--text-color', textColor);
        }
        function updateFontSize(size) {
            document.documentElement.style.setProperty('--font-size', size + 'px');
        }
        function updateLineHeight(h) {
            document.documentElement.style.setProperty('--line-height', h);
        }
        function updateFontFamily(f) {
            document.documentElement.style.setProperty('--font-family', f + ", 'PingFang SC', 'Hiragino Sans', 'Microsoft YaHei', sans-serif");
        }
        var _scrollTimeout;
        window.addEventListener('scroll', function() {
            clearTimeout(_scrollTimeout);
            _scrollTimeout = setTimeout(function() {
                var scrollTop = window.pageYOffset;
                var sh = document.documentElement.scrollHeight - document.documentElement.clientHeight;
                var progress = sh > 0 ? scrollTop / sh : 0;
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.onScroll) {
                    window.webkit.messageHandlers.onScroll.postMessage(progress);
                }
            }, 200);
        });
        window.addEventListener('load', function() {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.onLoad) {
                window.webkit.messageHandlers.onLoad.postMessage(null);
            }
        });
        </script>
        </body>
        </html>
        """
    }
}
