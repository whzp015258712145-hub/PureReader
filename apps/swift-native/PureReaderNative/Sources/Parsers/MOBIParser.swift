//
//  MOBIParser.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import Foundation

struct MOBIParser: EbookParser {

    private struct MOBIParseResult {
        let html: String
        let metadata: [String: String]
    }

    // MARK: - Public API (EbookParser protocol conformance)

    func parse(filePath: String, encoding: String? = nil) async throws -> EbookContent {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ParserError.fileNotFound(filePath)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))

        #if DEBUG
        print("📖 [MOBIParser] Parsing file: \((filePath as NSString).lastPathComponent), size: \(data.count) bytes")
        #endif

        let result = try parseMOBI(bytes: data, encoding: encoding)

        let format: EbookFormat = filePath.lowercased().hasSuffix(".azw3")
            ? .azw3
            : .mobi

        let fallbackTitle = (filePath as NSString).lastPathComponent
        let wrappedHTML = ensureWebViewShell(
            html: result.html,
            title: result.metadata["title"] ?? fallbackTitle,
            injectedCSS: result.metadata["_injected_css"]
        )

        let pages = paginateHTML(html: wrappedHTML)

        #if DEBUG
        print("📖 [MOBIParser] Parse complete: title=\(result.metadata["title"] ?? "nil"), htmlSize=\(wrappedHTML.count), pages=\(pages.count)")
        #endif

        return EbookContent(
            format: format,
            filePath: filePath,
            title: result.metadata["title"],
            author: result.metadata["creator"],
            metadata: result.metadata,
            chapters: [],
            htmlContent: wrappedHTML,
            pages: pages,
            useFallbackRenderer: false
        )
    }

    // MARK: - Main MOBI parsing logic

    private func parseMOBI(bytes data: Data, encoding userEncoding: String?) throws -> MOBIParseResult {
        let pdb = PDBDecoder.parse(data)

        guard !pdb.records.isEmpty else {
            throw ParserError.invalidStructure("invalid_pdb")
        }

        let r0 = pdb.records[0]
        guard r0.offset + r0.length <= data.count, r0.length >= 14 else {
            throw ParserError.invalidStructure("invalid_pdb")
        }

        let rec0 = data.subdata(in: r0.offset..<(r0.offset + r0.length))

        let compression = (Int(rec0[0]) << 8) | Int(rec0[1])
        let encryption = (Int(rec0[12]) << 8) | Int(rec0[13])

        if encryption != 0 {
            throw ParserError.invalidStructure("drm_protected")
        }

        if compression == 17480 {
            throw ParserError.invalidStructure("unsupported_huffman")
        }

        var mobiOffset = -1
        for i in 0..<(rec0.count - 3) {
            if rec0[i] == 0x4D, rec0[i + 1] == 0x4F,
               rec0[i + 2] == 0x42, rec0[i + 3] == 0x49 {
                mobiOffset = i
                break
            }
        }

        var firstContentRecord = 1
        var lastContentRecord = 1
        var firstImageRecord = Int.max

        if mobiOffset >= 0, mobiOffset + 96 <= rec0.count {
            firstContentRecord = (Int(rec0[mobiOffset + 80]) << 24) | (Int(rec0[mobiOffset + 81]) << 16) |
                                 (Int(rec0[mobiOffset + 82]) << 8) | Int(rec0[mobiOffset + 83])
            lastContentRecord  = (Int(rec0[mobiOffset + 84]) << 24) | (Int(rec0[mobiOffset + 85]) << 16) |
                                 (Int(rec0[mobiOffset + 86]) << 8) | Int(rec0[mobiOffset + 87])
            firstImageRecord   = (Int(rec0[mobiOffset + 92]) << 24) | (Int(rec0[mobiOffset + 93]) << 16) |
                                 (Int(rec0[mobiOffset + 94]) << 8) | Int(rec0[mobiOffset + 95])
        } else if rec0.count >= 10 {
            firstContentRecord = 1
            lastContentRecord = (Int(rec0[8]) << 8) | Int(rec0[9])
        }

        if firstContentRecord == 0 {
            firstContentRecord = 1
        }

        let textEncoding: String.Encoding
        if mobiOffset >= 0 {
            let mobiHeader = rec0.subdata(in: mobiOffset..<rec0.count)
            textEncoding = detectTextEncoding(mobiHeaderBytes: mobiHeader, userEncoding: userEncoding)
        } else {
            textEncoding = .utf8
        }

        let heuristic = firstContentRecord > lastContentRecord ||
                        firstContentRecord >= pdb.records.count ||
                        firstContentRecord == 0xFFFF_FFFF

        var htmlStr = ""

        if heuristic {
            for i in 1..<pdb.records.count {
                if firstImageRecord != Int.max, i >= firstImageRecord { continue }

                let rec = pdb.records[i]
                guard rec.offset + rec.length <= data.count, rec.length >= 10 else { continue }

                let recordData = data.subdata(in: rec.offset..<(rec.offset + rec.length))

                let decoded: String
                if compression == 2 {
                    decoded = PalmDocDecompressor.decompress(recordData)
                } else {
                    decoded = String(data: recordData, encoding: textEncoding)
                        ?? String(data: recordData, encoding: .isoLatin1)
                        ?? ""
                }

                if decoded.contains("<") || decoded.contains("&") {
                    htmlStr += decoded
                }
            }
        } else {
            let end = min(lastContentRecord, pdb.records.count - 1)
            if firstContentRecord <= end {
                for i in firstContentRecord...end {
                    let rec = pdb.records[i]
                    guard rec.offset + rec.length <= data.count else { continue }

                    let recordData = data.subdata(in: rec.offset..<(rec.offset + rec.length))

                    let decoded: String
                    if compression == 2 {
                        decoded = PalmDocDecompressor.decompress(recordData)
                    } else {
                        decoded = String(data: recordData, encoding: textEncoding)
                            ?? String(data: recordData, encoding: .utf8)
                            ?? String(data: recordData, encoding: .isoLatin1)
                            ?? ""
                    }

                    htmlStr += decoded
                }
            }
        }

        let trimmedContent = htmlStr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw ParserError.invalidStructure("empty_content")
        }

        var metadata: [String: String] = [:]

        if let titleRange = findFirstRegexMatch(pattern: "<title[^>]*>([\\s\\S]*?)</title>", in: htmlStr) {
            let title = String(htmlStr[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                metadata["title"] = title
            }
        }

        let authorPatterns = [
            "<meta[^>]*name\\s*=\\s*[\"']author[\"'][^>]*content\\s*=\\s*[\"']([^\"']*)[\"']",
            "<meta[^>]*name\\s*=\\s*[\"']dc\\.creator[\"'][^>]*content\\s*=\\s*[\"']([^\"']*)[\"']",
            "<meta[^>]*name\\s*=\\s*[\"']DC\\.Creator[\"'][^>]*content\\s*=\\s*[\"']([^\"']*)[\"']",
            "<dc:creator[^>]*>([^<]+)</dc:creator>",
            "<meta[^>]*content\\s*=\\s*[\"']([^\"']*)[\"'][^>]*name\\s*=\\s*[\"']author[\"']",
        ]

        for pattern in authorPatterns {
            if let matchRange = findFirstRegexMatch(pattern: pattern, in: htmlStr) {
                let author = String(htmlStr[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !author.isEmpty {
                    metadata["creator"] = author
                    break
                }
            }
        }

        return MOBIParseResult(html: htmlStr, metadata: metadata)
    }

    private func detectTextEncoding(mobiHeaderBytes: Data, userEncoding: String?) -> String.Encoding {
        if let userEncoding {
            let lowered = userEncoding.lowercased().trimmingCharacters(in: .whitespaces)
            if lowered == "utf-8" || lowered == "utf8" {
                return .utf8
            }
            let cfEnc = CFStringConvertIANACharSetNameToEncoding(userEncoding as CFString)
            if cfEnc != kCFStringEncodingInvalidId {
                let nsEnc = CFStringConvertEncodingToNSStringEncoding(cfEnc)
                return String.Encoding(rawValue: nsEnc)
            }
        }

        guard mobiHeaderBytes.count >= 32 else { return .utf8 }

        let encodingCode = (Int(mobiHeaderBytes[28]) << 24) | (Int(mobiHeaderBytes[29]) << 16) |
                           (Int(mobiHeaderBytes[30]) << 8) | Int(mobiHeaderBytes[31])

        switch encodingCode {
        case 65001:
            return .utf8
        case 1252:
            return .windowsCP1252
        default:
            let cfEnc = CFStringConvertWindowsCodepageToEncoding(CFStringEncoding(encodingCode))
            if cfEnc != kCFStringEncodingInvalidId {
                let nsEnc = CFStringConvertEncodingToNSStringEncoding(cfEnc)
                return String.Encoding(rawValue: nsEnc)
            }
            return .utf8
        }
    }

    private func findFirstRegexMatch(pattern: String, in string: String) -> Range<String.Index>? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(location: 0, length: string.utf16.count)
        guard let match = regex.firstMatch(in: string, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: string) else {
            return nil
        }
        return captureRange
    }

    private func ensureWebViewShell(html rawHTML: String, title: String, injectedCSS: String?) -> String {
        let trimmed = rawHTML.trimmingCharacters(in: .whitespacesAndNewlines)

        let requiredContracts = [
            "function updateTheme(",
            "function updateFontSize(",
            "function updateLineHeight(",
            "function updateFontFamily(",
            "window.webkit.messageHandlers.onScroll.postMessage",
            "window.webkit.messageHandlers.onLoad.postMessage",
        ]

        if requiredContracts.allSatisfy({ trimmed.contains($0) }) {
            return trimmed
        }

        return HTMLTemplateBuilder.build(
            bodyHTML: trimmed,
            title: title,
            injectedCSS: injectedCSS
        )
    }

    private func paginateHTML(html: String) -> [String] {
        let pageSize = 5000

        guard html.count > pageSize else {
            return [html]
        }

        let (shellPrefix, shellSuffix, bodyContent) = dissectHTML(html)

        guard !bodyContent.isEmpty else {
            return [html]
        }

        var pages: [String] = []
        var currentIndex = bodyContent.startIndex
        let endIndex = bodyContent.endIndex

        while currentIndex < endIndex {
            let remaining = bodyContent.distance(from: currentIndex, to: endIndex)
            let chunkSize = min(pageSize, remaining)
            let roughEnd = bodyContent.index(currentIndex, offsetBy: chunkSize, limitedBy: endIndex) ?? endIndex

            var actualEnd = roughEnd

            if roughEnd < endIndex {
                let searchBackDist = min(500, bodyContent.distance(from: currentIndex, to: roughEnd))
                let searchStart = bodyContent.index(roughEnd, offsetBy: -searchBackDist)

                let breakPatterns = [
                    "</p>", "</div>", "</section>", "</article>",
                    "</tr>", "</li>", "blockquote>", "</table>",
                    "</h1>", "</h2>", "3>", "4>", "5>", "6>",
                    "<br>", "<br/>", "<br />",
                ]

                var foundBreak = false
                for pattern in breakPatterns {
                    if let range = bodyContent.range(of: pattern, options: [.backwards, .caseInsensitive],
                                                      range: searchStart..<roughEnd) {
                        actualEnd = range.upperBound
                        foundBreak = true
                        break
                    }
                }

                if !foundBreak {
                    if let spaceRange = bodyContent.range(of: " ", options: [.backwards],
                                                           range: searchStart..<roughEnd) {
                        actualEnd = spaceRange.upperBound
                    }
                }
            }

            let chunk = String(bodyContent[currentIndex..<actualEnd])
            let page = "\(shellPrefix)\(chunk)\(shellSuffix)"
            pages.append(page)

            currentIndex = actualEnd
        }

        return pages
    }

    private func dissectHTML(_ html: String) -> (prefix: String, suffix: String, body: String) {
        var headEndIdx: String.Index
        if let headClose = html.range(of: "</head>", options: [.caseInsensitive]) {
            headEndIdx = headClose.upperBound
        } else if let bodyOpen = findBodyTagEnd(in: html) {
            headEndIdx = bodyOpen
        } else {
            return ("<!DOCTYPE html><html><body>", "</body></html>", html)
        }

        let prefix = String(html[html.startIndex..<headEndIdx])

        let afterHead = html[headEndIdx...]
        let bodyContent: String
        let suffix: String

        if let bodyStart = findBodyTagEnd(in: String(afterHead)) {
            let bodyStartAbsolute = afterHead.index(afterHead.startIndex, offsetBy:
                afterHead.distance(from: afterHead.startIndex, to: bodyStart))
            let afterBodyOpen = afterHead[bodyStartAbsolute...]

            if let bodyClose = afterBodyOpen.range(of: "</body>", options: [.caseInsensitive, .backwards]) {
                bodyContent = String(afterBodyOpen[afterBodyOpen.startIndex..<bodyClose.lowerBound])
                suffix = String(afterBodyOpen[bodyClose.lowerBound...])
            } else {
                bodyContent = String(afterBodyOpen)
                suffix = "</body></html>"
            }
        } else {
            bodyContent = String(afterHead)
            suffix = "</body></html>"
        }

        return (prefix, suffix, bodyContent)
    }

    private func findBodyTagEnd(in html: String) -> String.Index? {
        let pattern = "<body[^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(location: 0, length: html.utf16.count)
        if let match = regex.firstMatch(in: html, options: [], range: range),
           let matchRange = Range(match.range(at: 0), in: html) {
            return matchRange.upperBound
        }
        return nil
    }
}
