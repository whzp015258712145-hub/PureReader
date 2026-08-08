//
//  EPUBToHTMLConverter.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-23.
//

import Foundation
import ZIPFoundation

struct EPUBToHTMLConverter {
    enum ConvertMode { case tocBased, spineBased }

    let archive: Archive
    let spine: [String]
    let manifest: [String: String]
    let opfDir: String
    let toc: [EbookContent.Chapter]

    func convert(mode: ConvertMode) async throws -> String {
        let caseInsensitiveLookup = buildCaseInsensitiveLookup()
        var parts = [buildHeader()]
        switch mode {
        case .tocBased:
            let spinePaths = buildSpinePaths(lookup: caseInsensitiveLookup)
            var spineExactIndexMap: [String: Int] = [:]
            var spineLowerIndexMap: [String: Int] = [:]
            for (idx, path) in spinePaths.enumerated() {
                spineExactIndexMap[path] = idx
                let lowered = path.lowercased()
                if spineLowerIndexMap[lowered] == nil {
                    spineLowerIndexMap[lowered] = idx
                }
            }

            for (i, chapter) in toc.enumerated() {
                let chapterHTML = try buildTOCChapter(
                    index: i,
                    chapter: chapter,
                    spinePaths: spinePaths,
                    spineExactIndexMap: spineExactIndexMap,
                    spineLowerIndexMap: spineLowerIndexMap,
                    lookup: caseInsensitiveLookup
                )
                parts.append(chapterHTML)
            }

        case .spineBased:
            for itemId in spine {
                guard let href = manifest[itemId] else { continue }
                let rawPath = opfDir.isEmpty ? href : "\(opfDir)/\(href)"
                let chapterPath = normalizeArchivePath(rawPath)
                guard let entry = archive[chapterPath],
                      let data = try? archive.extractData(from: entry),
                      var html = String(data: data, encoding: .utf8)
                else { continue }
                html = processImages(html: html, chapterPath: chapterPath)
                parts.append("<div class=\"chapter\">\(html)</div>")
            }
        }
        parts.append(buildFooter())
        return parts.joined(separator: "\n")
    }

    private func buildTOCChapter(
        index: Int,
        chapter: EbookContent.Chapter,
        spinePaths: [String],
        spineExactIndexMap: [String: Int],
        spineLowerIndexMap: [String: Int],
        lookup: [String: String]
    ) throws -> String {
        let href = chapter.href ?? ""
        let candidatePaths = buildChapterCandidatePaths(href: href)

        func failedChapterHTML() -> String {
            """
            <div class="chapter" id="chapter-\(index)">
                <h2 class="chapter-title">\(chapter.title)</h2>
                <div class="chapter-content"><p>章节内容加载失败，请返回目录重试。</p></div>
            </div>
            """
        }

        func renderChapterHTML(contentHTML: String) -> String {
            """
            <div class="chapter" id="chapter-\(index)">
                <h2 class="chapter-title">\(chapter.title)</h2>
                <div class="chapter-content">\(contentHTML)</div>
            </div>
            """
        }

        func loadChapterContent(path: String) -> String? {
            guard let entry = archive[path] else {
                #if DEBUG
                print("🧭 [SwiftNav] TOC span file missing index=\(index), title=\(chapter.title), path=\(path)")
                #endif
                return nil
            }

            let data: Data
            do {
                data = try archive.extractData(from: entry)
            } catch {
                #if DEBUG
                print("🧭 [SwiftNav] TOC span file read failed index=\(index), title=\(chapter.title), path=\(path), error=\(error.localizedDescription)")
                #endif
                return nil
            }

            guard let decoded = decodeHTML(data: data, path: path) else {
                #if DEBUG
                print("🧭 [SwiftNav] TOC span file decode failed index=\(index), title=\(chapter.title), path=\(path)")
                #endif
                return nil
            }

            return processImages(html: decoded.html, chapterPath: path)
        }

        guard let resolution = resolveChapterEntry(href: href, lookup: lookup) else {
            #if DEBUG
            print("🧭 [SwiftNav] TOC chapter path resolve failed index=\(index), title=\(chapter.title), href=\(href), candidatePaths=\(candidatePaths)")
            #endif
            return failedChapterHTML()
        }

        let startPath = resolution.path
        guard let startIndex = spineIndex(for: startPath, exactMap: spineExactIndexMap, lowerMap: spineLowerIndexMap) else {
            guard let singleHTML = loadChapterContent(path: startPath) else { return failedChapterHTML() }
            #if DEBUG
            print("🧭 [SwiftNav] TOC span startPath not in spine index=\(index), title=\(chapter.title), spanStartPath=\(startPath)")
            logTOCChapterDiagnostics(
                index: index,
                title: chapter.title,
                spanStartPath: startPath,
                spanEndPath: startPath,
                spanFileCount: 1,
                mergedHTML: singleHTML
            )
            #endif
            return renderChapterHTML(contentHTML: singleHTML)
        }

        let nextStartPath: String? = {
            guard index + 1 < toc.count else { return nil }
            let nextHref = toc[index + 1].href ?? ""
            return resolveChapterEntry(href: nextHref, lookup: lookup)?.path
        }()

        var endIndex = spinePaths.count - 1
        if let nextStartPath,
           let nextStartIndex = spineIndex(for: nextStartPath, exactMap: spineExactIndexMap, lowerMap: spineLowerIndexMap) {
            if nextStartIndex > startIndex {
                endIndex = nextStartIndex - 1
            } else {
                #if DEBUG
                print("🧭 [SwiftNav] TOC span invalid nextStartIndex<=startIndex index=\(index), title=\(chapter.title), startIndex=\(startIndex), nextStartIndex=\(nextStartIndex), fallback=single")
                #endif
                guard let singleHTML = loadChapterContent(path: startPath) else { return failedChapterHTML() }
                #if DEBUG
                logTOCChapterDiagnostics(
                    index: index,
                    title: chapter.title,
                    spanStartPath: startPath,
                    spanEndPath: startPath,
                    spanFileCount: 1,
                    mergedHTML: singleHTML
                )
                #endif
                return renderChapterHTML(contentHTML: singleHTML)
            }
        }

        let spanPaths = Array(spinePaths[startIndex...endIndex])
        var mergedParts: [String] = []
        mergedParts.reserveCapacity(spanPaths.count)

        for spanPath in spanPaths {
            if let part = loadChapterContent(path: spanPath) {
                mergedParts.append(part)
            }
        }

        guard !mergedParts.isEmpty else {
            guard let singleHTML = loadChapterContent(path: startPath) else { return failedChapterHTML() }
            #if DEBUG
            logTOCChapterDiagnostics(
                index: index,
                title: chapter.title,
                spanStartPath: startPath,
                spanEndPath: startPath,
                spanFileCount: 1,
                mergedHTML: singleHTML
            )
            #endif
            return renderChapterHTML(contentHTML: singleHTML)
        }

        let mergedHTML = mergedParts.joined(separator: "\n")

        #if DEBUG
        logTOCChapterDiagnostics(
            index: index,
            title: chapter.title,
            spanStartPath: spanPaths.first ?? startPath,
            spanEndPath: spanPaths.last ?? startPath,
            spanFileCount: spanPaths.count,
            mergedHTML: mergedHTML
        )
        #endif

        return renderChapterHTML(contentHTML: mergedHTML)
    }

    private func buildSpinePaths(lookup: [String: String]) -> [String] {
        var paths: [String] = []

        for itemId in spine {
            guard let href = manifest[itemId] else { continue }
            var resolvedPath: String?

            for candidate in manifestArchivePaths(from: href) {
                if archive[candidate] != nil {
                    resolvedPath = candidate
                    break
                }
            }

            if resolvedPath == nil {
                for candidate in manifestArchivePaths(from: href) {
                    if let caseInsensitivePath = findArchivePathCaseInsensitive(candidate, lookup: lookup) {
                        resolvedPath = caseInsensitivePath
                        break
                    }
                }
            }

            if let resolvedPath, !paths.contains(resolvedPath) {
                paths.append(resolvedPath)
            }
        }

        return paths
    }

    private func spineIndex(for path: String, exactMap: [String: Int], lowerMap: [String: Int]) -> Int? {
        if let exact = exactMap[path] {
            return exact
        }
        return lowerMap[path.lowercased()]
    }

    private func logTOCChapterDiagnostics(
        index: Int,
        title: String,
        spanStartPath: String,
        spanEndPath: String,
        spanFileCount: Int,
        mergedHTML: String
    ) {
        #if DEBUG
        let mergedTextLength = plainTextLength(fromHTML: mergedHTML)
        let isLikelyTruncated = mergedTextLength < 200
        print("🧭 [SwiftNav] TOC chapter diagnostics index=\(index), title=\(title), spanStartPath=\(spanStartPath), spanEndPath=\(spanEndPath), spanFileCount=\(spanFileCount), mergedTextLength=\(mergedTextLength), isLikelyTruncated=\(isLikelyTruncated)")
        #endif
    }

    private func plainTextLength(fromHTML html: String) -> Int {
        let pattern = #"<[^>]+>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return html.count
        }
        let range = NSRange(location: 0, length: html.utf16.count)
        let stripped = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "")
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private func resolveChapterEntry(href: String, lookup: [String: String]) -> (path: String, entry: Entry)? {
        let candidatePaths = buildChapterCandidatePaths(href: href)

        for candidate in candidatePaths {
            if let entry = archive[candidate] {
                return (candidate, entry)
            }
        }

        if let manifestPath = resolveChapterPathViaManifest(candidatePaths: candidatePaths, lookup: lookup) {
            return (manifestPath, archive[manifestPath]!)
        }

        return nil
    }

    private func buildChapterCandidatePaths(href: String) -> [String] {
        let filePart = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? href
        var candidates: [String] = []

        func appendCandidate(_ rawPath: String) {
            let normalized = normalizeArchivePath(rawPath)
            guard !normalized.isEmpty, !candidates.contains(normalized) else { return }
            candidates.append(normalized)
        }

        appendCandidate(filePart)
        if !opfDir.isEmpty {
            appendCandidate("\(opfDir)/\(filePart)")
        }

        if let decodedFilePart = filePart.removingPercentEncoding, decodedFilePart != filePart {
            appendCandidate(decodedFilePart)
            if !opfDir.isEmpty {
                appendCandidate("\(opfDir)/\(decodedFilePart)")
            }
        }

        return candidates
    }

    private func resolveChapterPathViaManifest(candidatePaths: [String], lookup: [String: String]) -> String? {
        let exactSet = Set(candidatePaths)
        let lowerSet = Set(candidatePaths.map { $0.lowercased() })

        for manifestHref in manifest.values {
            for manifestPath in manifestArchivePaths(from: manifestHref) {
                if exactSet.contains(manifestPath), archive[manifestPath] != nil {
                    return manifestPath
                }
            }
        }

        for manifestHref in manifest.values {
            for manifestPath in manifestArchivePaths(from: manifestHref) {
                guard lowerSet.contains(manifestPath.lowercased()) else { continue }
                if let caseInsensitivePath = findArchivePathCaseInsensitive(manifestPath, lookup: lookup) {
                    return caseInsensitivePath
                }
            }
        }

        return nil
    }

    private func manifestArchivePaths(from href: String) -> [String] {
        var paths: [String] = []

        func appendPath(_ rawPath: String) {
            let normalized = normalizeArchivePath(rawPath)
            guard !normalized.isEmpty, !paths.contains(normalized) else { return }
            paths.append(normalized)
        }

        appendPath(href)
        if !opfDir.isEmpty {
            appendPath("\(opfDir)/\(href)")
        }

        if let decodedHref = href.removingPercentEncoding, decodedHref != href {
            appendPath(decodedHref)
            if !opfDir.isEmpty {
                appendPath("\(opfDir)/\(decodedHref)")
            }
        }

        return paths
    }

    private func buildCaseInsensitiveLookup() -> [String: String] {
        var lookup: [String: String] = [:]
        for entry in archive {
            let lowered = entry.path.lowercased()
            if lookup[lowered] == nil {
                lookup[lowered] = entry.path
            }
        }
        return lookup
    }

    private func findArchivePathCaseInsensitive(_ targetPath: String, lookup: [String: String]) -> String? {
        return lookup[targetPath.lowercased()]
    }

    private func normalizeArchivePath(_ path: String) -> String {
        var stack: [String] = []
        for component in path.split(separator: "/", omittingEmptySubsequences: true) {
            switch component {
            case ".":
                continue
            case "..":
                if !stack.isEmpty { _ = stack.removeLast() }
            default:
                stack.append(String(component))
            }
        }
        return stack.joined(separator: "/")
    }

    private func decodeHTML(data: Data, path: String) -> (html: String, encoding: String)? {
        _ = path
        if let html = String(data: data, encoding: .utf8) {
            return (html, "utf-8")
        }

        var attemptedEncodings: Set<String> = ["utf-8"]

        if let metaCharset = extractHTMLCharset(from: data) {
            let normalizedMetaCharset = normalizeCharsetName(metaCharset)
            if !normalizedMetaCharset.isEmpty,
               !attemptedEncodings.contains(normalizedMetaCharset),
               let encoding = stringEncoding(from: normalizedMetaCharset),
               let html = String(data: data, encoding: encoding) {
                return (html, normalizedMetaCharset)
            }
            attemptedEncodings.insert(normalizedMetaCharset)
        }

        let fallbackCharsets = ["gb18030", "gb2312", "gbk", "shift_jis", "windows-1252", "iso-8859-1"]
        for charset in fallbackCharsets {
            let normalized = normalizeCharsetName(charset)
            guard !attemptedEncodings.contains(normalized),
                  let encoding = stringEncoding(from: normalized),
                  let html = String(data: data, encoding: encoding)
            else {
                attemptedEncodings.insert(normalized)
                continue
            }
            return (html, normalized)
        }

        return nil
    }

    private func extractHTMLCharset(from data: Data) -> String? {
        let probeData = data.prefix(8192)
        guard let probe = String(data: probeData, encoding: .isoLatin1) else {
            return nil
        }

        let patterns = [
            #"<meta[^>]*charset\s*=\s*["']?\s*([^\s"'/>;]+)"#,
            #"<meta[^>]*http-equiv\s*=\s*["']content-type["'][^>]*content\s*=\s*["'][^"']*charset\s*=\s*([^\s"'/>;]+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(location: 0, length: probe.utf16.count)
            guard let match = regex.firstMatch(in: probe, options: [], range: range),
                  match.numberOfRanges > 1,
                  let charsetRange = Range(match.range(at: 1), in: probe)
            else {
                continue
            }

            let charset = String(probe[charsetRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !charset.isEmpty {
                return charset
            }
        }

        return nil
    }

    private func stringEncoding(from charset: String) -> String.Encoding? {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(charset as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        return String.Encoding(rawValue: nsEncoding)
    }

    private func normalizeCharsetName(_ charset: String) -> String {
        charset
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func processImages(html: String, chapterPath: String) -> String {
        guard !html.isEmpty else { return html }

        let pattern = #"<img[^>]+src\s*=\s*["']([^"']+)["'][^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return html
        }

        let chapterDir = (chapterPath as NSString).deletingLastPathComponent
        let nsResult = NSMutableString(string: html)
        let fullRange = NSRange(location: 0, length: nsResult.length)
        let matches = regex.matches(in: html, range: fullRange)

        for match in matches.reversed() {
            let srcNSRange = match.range(at: 1)
            guard srcNSRange.location != NSNotFound else { continue }

            let src = nsResult.substring(with: srcNSRange)
            if src.hasPrefix("data:") { continue }

            let srcWithoutFragment = src.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? src
            let srcWithoutQuery = srcWithoutFragment.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? srcWithoutFragment

            let resolvedPath: String
            if srcWithoutQuery.hasPrefix("/") {
                resolvedPath = normalizeArchivePath(String(srcWithoutQuery.dropFirst()))
            } else {
                let base = chapterDir.isEmpty ? srcWithoutQuery : "\(chapterDir)/\(srcWithoutQuery)"
                resolvedPath = normalizeArchivePath(base)
            }

            guard let entry = archive[resolvedPath],
                  let imageData = try? archive.extractData(from: entry)
            else {
                #if DEBUG
                print("🖼️ [SwiftNative] Image resolve failed chapterPath=\(chapterPath), src=\(src), resolvedPath=\(resolvedPath)")
                #endif
                continue
            }

            // Prevent OOM: skip base64 inlining for images exceeding 5 MB
            let maxInlineBytes = 5_000_000
            if imageData.count > maxInlineBytes {
                #if DEBUG
                let sizeMB = Double(imageData.count) / 1_000_000.0
                print("🖼️ [SwiftNative] Image too large for inlining chapterPath=\(chapterPath), src=\(src), sizeMB=\(String(format: "%.1f", sizeMB)), keeping original src")
                #endif
                continue
            }

            let ext = (resolvedPath as NSString).pathExtension.lowercased()
            let mime: String
            switch ext {
            case "png": mime = "image/png"
            case "gif": mime = "image/gif"
            case "webp": mime = "image/webp"
            case "svg": mime = "image/svg+xml"
            default: mime = "image/jpeg"
            }

            #if DEBUG
            print("🖼️ [SwiftNative] Image resolve hit chapterPath=\(chapterPath), src=\(src), resolvedPath=\(resolvedPath)")
            #endif

            let base64 = imageData.base64EncodedString()
            let dataUri = "data:\(mime);base64,\(base64)"
            nsResult.replaceCharacters(in: srcNSRange, with: dataUri)
        }

        return nsResult as String
    }

    private func buildHeader() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
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
            img { max-width: 100%; height: auto; display: block; margin: 20px auto; }
            .chapter { margin-bottom: 60px; }
            .chapter-title {
                font-size: calc(var(--font-size) * 1.3);
                font-weight: 600;
                margin-bottom: 20px;
                padding-bottom: 10px;
                border-bottom: 2px solid var(--text-color);
                opacity: 0.8;
            }
            .chapter-content p { margin-bottom: 1em; text-indent: 2em; }
            .chapter-content h1,
            .chapter-content h2,
            .chapter-content h3,
            .chapter-content h4,
            .chapter-content h5,
            .chapter-content h6 {
                margin-top: 1.5em;
                margin-bottom: 0.5em;
                font-weight: 600;
            }
            .chapter-content a {
                color: var(--text-color);
                text-decoration: underline;
            }
            .chapter-content blockquote {
                margin: 1em 0;
                padding-left: 1em;
                border-left: 3px solid var(--text-color);
                opacity: 0.8;
            }
            .chapter-content code {
                background-color: rgba(0,0,0,0.05);
                padding: 2px 6px;
                border-radius: 3px;
                font-family: 'Courier New', monospace;
            }
            .chapter-content pre {
                background-color: rgba(0,0,0,0.05);
                padding: 10px;
                border-radius: 5px;
                overflow-x: auto;
                margin: 1em 0;
            }
            </style>
        </head>
        <body>
        """
    }

    private func buildFooter() -> String {
        return """
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
}

