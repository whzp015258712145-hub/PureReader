//
//  TXTParser.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import Foundation

struct TXTParser: EbookParser {
    func parse(filePath: String, encoding: String? = nil) async throws -> EbookContent {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ParserError.fileNotFound(filePath)
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let text = decode(data: data, hint: encoding)
        let pages = paginate(text: text)
        let filename = (filePath as NSString).lastPathComponent
        return EbookContent(
            format: .txt,
            filePath: filePath,
            title: filename,
            author: nil,
            chapters: [],
            htmlContent: nil,
            pages: pages,
            useFallbackRenderer: false
        )
    }

    private func decode(data: Data, hint: String?) -> String {
        // 1. 使用指定编码
        if let hint = hint,
           let enc = encodingFromString(hint),
           let text = String(data: data, encoding: enc) {
            return text
        }
        // 2. BOM 检测（UTF-8 BOM: EF BB BF）
        if data.count >= 3,
           data[0] == 0xEF, data[1] == 0xBB, data[2] == 0xBF,
           let text = String(data: data.dropFirst(3), encoding: .utf8) {
            return text
        }
        // 3. UTF-8
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        // 4. GBK / GB18030
        let gbkEncoding = String.Encoding(rawValue:
            CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let text = String(data: data, encoding: gbkEncoding) {
            return text
        }
        // 5. Latin-1 fallback（永远不会失败）
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    private func encodingFromString(_ s: String) -> String.Encoding? {
        switch s.lowercased() {
        case "utf-8", "utf8":
            return .utf8
        case "gbk", "gb2312", "gb18030":
            return String.Encoding(rawValue:
                CFStringConvertEncodingToNSStringEncoding(
                    CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        case "shift_jis", "shiftjis":
            return .shiftJIS
        case "windows-1252":
            return .windowsCP1252
        case "windows-1251":
            return String.Encoding(rawValue:
                CFStringConvertEncodingToNSStringEncoding(
                    CFStringEncoding(CFStringEncodings.windowsCyrillic.rawValue)))
        case "iso-8859-1", "latin1", "iso_8859-1":
            return .isoLatin1
        default:
            return nil
        }
    }

    // 按 5000 字符切页，与 Flutter MOBI 分页逻辑一致
    private func paginate(text: String, pageSize: Int = 5000) -> [String] {
        guard !text.isEmpty else { return [""] }
        var pages: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: pageSize, limitedBy: text.endIndex) ?? text.endIndex
            pages.append(String(text[start..<end]))
            start = end
        }
        return pages
    }
}


