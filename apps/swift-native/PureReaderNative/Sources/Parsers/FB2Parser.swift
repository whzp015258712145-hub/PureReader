//
//  FB2Parser.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-26.
//

import Foundation

struct FB2Parser: EbookParser {
    func parse(filePath: String, encoding: String? = nil) async throws -> EbookContent {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ParserError.fileNotFound(filePath)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let doc = try parseFB2Document(data: data)
        let fallbackTitle = (filePath as NSString).lastPathComponent

        return EbookContent(
            format: .fb2,
            filePath: filePath,
            title: doc.title?.isEmpty == false ? doc.title : fallbackTitle,
            author: doc.author,
            metadata: doc.metadata,
            chapters: doc.chapters,
            htmlContent: wrapHTML(body: doc.htmlBody, title: doc.title ?? fallbackTitle),
            pages: nil,
            useFallbackRenderer: false
        )
    }

    private func parseFB2Document(data: Data) throws -> FB2Document {
        if let parsed = parseWithXMLParser(data: data) {
            return parsed
        }

        let declaredEncoding = extractDeclaredEncoding(from: data)
        var candidates: [String.Encoding] = []

        if let declaredEncoding,
           let declared = stringEncoding(from: declaredEncoding) {
            candidates.append(declared)
        }

        candidates.append(.utf8)
        candidates.append(windows1251Encoding())
        candidates.append(.isoLatin1)

        var unique: [String.Encoding] = []
        for item in candidates where !unique.contains(item) {
            unique.append(item)
        }

        for enc in unique {
            guard let decoded = String(data: data, encoding: enc),
                  let normalizedData = decoded.data(using: .utf8),
                  let parsed = parseWithXMLParser(data: normalizedData)
            else {
                continue
            }
            return parsed
        }

        throw ParserError.invalidStructure("FB2 XML parse failed")
    }

    private func parseWithXMLParser(data: Data) -> FB2Document? {
        let decoder = FB2XMLDecoder()
        let parser = XMLParser(data: data)
        parser.delegate = decoder
        parser.shouldProcessNamespaces = false

        let ok = parser.parse()
        guard ok else { return nil }
        return decoder.buildDocument()
    }

    private func extractDeclaredEncoding(from data: Data) -> String? {
        let probeData = data.prefix(1024)
        guard let probe = String(data: probeData, encoding: .isoLatin1) else {
            return nil
        }
        guard let regex = try? NSRegularExpression(
            pattern: #"<\?xml[^>]*encoding\s*=\s*["']\s*([^"']+)\s*["'][^>]*\?>"#,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(location: 0, length: probe.utf16.count)
        guard let match = regex.firstMatch(in: probe, options: [], range: range),
              match.numberOfRanges > 1,
              let encodingRange = Range(match.range(at: 1), in: probe)
        else {
            return nil
        }

        return String(probe[encodingRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stringEncoding(from charset: String) -> String.Encoding? {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(charset as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        return String.Encoding(rawValue: nsEncoding)
    }

    private func windows1251Encoding() -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.windowsCyrillic.rawValue)
        ))
    }

    private func wrapHTML(body: String, title: String) -> String {
        let safeTitle = escapeHTML(title)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(safeTitle)</title>
            <style>
            :root {
                --bg-color: #F9F7F1;
                --text-color: #333333;
                --font-size: 18px;
                --line-height: 1.6;
                --font-family: -apple-system, 'PingFang SC', 'Hiragino Sans', 'Microsoft YaHei', sans-serif;
            }
            * { margin: 0; padding: 0; box-sizing: border-box; }
            html { scroll-behavior: smooth; }
            body {
                background-color: var(--bg-color);
                color: var(--text-color);
                font-size: var(--font-size);
                line-height: var(--line-height);
                font-family: var(--font-family);
                padding: 40px;
                max-width: 800px;
                margin: 0 auto;
            }
            .book-title {
                font-size: calc(var(--font-size) * 1.7);
                margin-bottom: 24px;
                opacity: 0.9;
            }
            section { margin-bottom: 2em; }
            p { margin-bottom: 1em; text-indent: 2em; }
            h2, h3, h4, h5, h6 {
                margin: 1.2em 0 0.6em;
                text-indent: 0;
            }
            .subtitle { font-style: italic; opacity: 0.85; text-indent: 0; }
            .poem { margin: 1em 0; padding-left: 1.2em; }
            .poem-line, .text-author { text-indent: 0; margin-bottom: 0.4em; }
            blockquote {
                margin: 1em 0;
                padding-left: 1em;
                border-left: 3px solid var(--text-color);
                opacity: 0.85;
            }
            </style>
        </head>
        <body>
            <h1 class="book-title">\(safeTitle)</h1>
            \(body)
        <script>
        function scrollToChapter(index) {
            const el = document.getElementById('chapter-' + index);
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
        let scrollTimeout;
        window.addEventListener('scroll', function() {
            clearTimeout(scrollTimeout);
            scrollTimeout = setTimeout(function() {
                const scrollTop = window.pageYOffset;
                const sh = document.documentElement.scrollHeight - document.documentElement.clientHeight;
                const progress = sh > 0 ? scrollTop / sh : 0;
                window.webkit.messageHandlers.onScroll.postMessage(progress);
            }, 200);
        });
        window.addEventListener('load', function() {
            window.webkit.messageHandlers.onLoad.postMessage(null);
        });
        </script>
        </body></html>
        """
    }

    private func escapeHTML(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

private struct FB2Document {
    let title: String?
    let author: String?
    let metadata: [String: String]
    let htmlBody: String
    let chapters: [EbookContent.Chapter]
}

private final class FB2XMLDecoder: NSObject, XMLParserDelegate {
    private var path: [String] = []
    private var textBuffer = ""

    private var title: String?
    private var bookTitleBuffer = ""

    private var authorFirstName = ""
    private var authorMiddleName = ""
    private var authorLastName = ""
    private var authorNickname = ""
    private var firstAuthorLocked = false

    private var inBody = false
    private var sectionDepth = 0
    private var bodyHTML = ""

    private var chapters: [EbookContent.Chapter] = []

    private var capturingSectionTitle = false
    private var sectionTitleCaptureDepth = 0
    private var sectionTitleBuffer = ""

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        let element = localName(of: elementName)
        path.append(element)
        textBuffer = ""

        if element == "body" {
            inBody = true
        }

        if inBody {
            if capturingSectionTitle {
                sectionTitleCaptureDepth += 1
                return
            }

            if element == "section" {
                sectionDepth += 1
                bodyHTML += "<section>"
                return
            }

            if element == "title", sectionDepth > 0 {
                capturingSectionTitle = true
                sectionTitleCaptureDepth = 1
                sectionTitleBuffer = ""
                return
            }

            switch element {
            case "p": bodyHTML += "<p>"
            case "subtitle": bodyHTML += "<p class=\"subtitle\">"
            case "emphasis": bodyHTML += "<em>"
            case "strong": bodyHTML += "<strong>"
            case "poem": bodyHTML += "<div class=\"poem\">"
            case "stanza": bodyHTML += "<div class=\"stanza\">"
            case "v": bodyHTML += "<p class=\"poem-line\">"
            case "text-author": bodyHTML += "<p class=\"text-author\">"
            case "epigraph", "cite": bodyHTML += "<blockquote>"
            case "empty-line": bodyHTML += "<br/>"
            default: break
            }
        }

        _ = namespaceURI
        _ = qName
        _ = attributeDict
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string

        if capturingSectionTitle {
            sectionTitleBuffer += string
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        let element = localName(of: elementName)
        let text = normalize(textBuffer)

        if element == "book-title", isPath("description", "title-info", "book-title") {
            if !text.isEmpty {
                bookTitleBuffer += (bookTitleBuffer.isEmpty ? "" : " ") + text
            }
        }

        if !firstAuthorLocked {
            if element == "first-name", isPath("description", "title-info", "author", "first-name") {
                authorFirstName += (authorFirstName.isEmpty ? "" : " ") + text
            }
            if element == "middle-name", isPath("description", "title-info", "author", "middle-name") {
                authorMiddleName += (authorMiddleName.isEmpty ? "" : " ") + text
            }
            if element == "last-name", isPath("description", "title-info", "author", "last-name") {
                authorLastName += (authorLastName.isEmpty ? "" : " ") + text
            }
            if element == "nickname", isPath("description", "title-info", "author", "nickname") {
                authorNickname += (authorNickname.isEmpty ? "" : " ") + text
            }
            if element == "author", isPath("description", "title-info", "author") {
                firstAuthorLocked = true
            }
        }

        if inBody {
            if capturingSectionTitle {
                sectionTitleCaptureDepth -= 1
                if sectionTitleCaptureDepth == 0 {
                    capturingSectionTitle = false
                    let titleText = normalize(sectionTitleBuffer)
                    if !titleText.isEmpty {
                        let level = max(0, sectionDepth - 1)
                        let heading = min(6, 2 + level)
                        let chapterIndex = chapters.count
                        chapters.append(EbookContent.Chapter(
                            title: titleText,
                            anchor: "chapter-\(chapterIndex)",
                            level: level,
                            href: nil
                        ))
                        bodyHTML += "<h\(heading) id=\"chapter-\(chapterIndex)\">\(escapeHTML(titleText))</h\(heading)>"
                    }
                    sectionTitleBuffer = ""
                }
            } else {
                switch element {
                case "p": bodyHTML += "</p>"
                case "subtitle": bodyHTML += "</p>"
                case "emphasis": bodyHTML += "</em>"
                case "strong": bodyHTML += "</strong>"
                case "poem": bodyHTML += "</div>"
                case "stanza": bodyHTML += "</div>"
                case "v": bodyHTML += "</p>"
                case "text-author": bodyHTML += "</p>"
                case "epigraph", "cite": bodyHTML += "</blockquote>"
                case "section":
                    bodyHTML += "</section>"
                    sectionDepth = max(0, sectionDepth - 1)
                case "body":
                    inBody = false
                default:
                    if shouldEmitText(for: element), !text.isEmpty {
                        bodyHTML += escapeHTML(text)
                    }
                }
            }
        }

        _ = path.popLast()
        textBuffer = ""
        _ = parser
        _ = namespaceURI
        _ = qName
    }

    func buildDocument() -> FB2Document {
        let resolvedTitle = normalize(bookTitleBuffer)
        title = resolvedTitle.isEmpty ? nil : resolvedTitle

        let fullAuthor = normalize([authorFirstName, authorMiddleName, authorLastName]
            .filter { !$0.isEmpty }
            .joined(separator: " "))
        let resolvedAuthor: String?
        if !fullAuthor.isEmpty {
            resolvedAuthor = fullAuthor
        } else {
            let nick = normalize(authorNickname)
            resolvedAuthor = nick.isEmpty ? nil : nick
        }

        let body = bodyHTML.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackBody = body.isEmpty ? "<p>此 FB2 文件未提取到正文内容。</p>" : body

        var metadata: [String: String] = ["format": "fb2"]
        if let t = title { metadata["title"] = t }
        if let a = resolvedAuthor { metadata["author"] = a }

        return FB2Document(
            title: title,
            author: resolvedAuthor,
            metadata: metadata,
            htmlBody: fallbackBody,
            chapters: chapters
        )
    }

    private func shouldEmitText(for element: String) -> Bool {
        switch element {
        case "section", "body", "title", "poem", "stanza", "epigraph", "cite", "empty-line":
            return false
        default:
            return true
        }
    }

    private func isPath(_ nodes: String...) -> Bool {
        guard path.count >= nodes.count else { return false }
        return Array(path.suffix(nodes.count)) == nodes
    }

    private func localName(of raw: String) -> String {
        raw.split(separator: ":").last.map(String.init) ?? raw
    }

    private func normalize(_ raw: String) -> String {
        raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func escapeHTML(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}









