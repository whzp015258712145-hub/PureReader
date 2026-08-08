//
//  ParserFactory.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//
//  对应 Flutter lib/parsers/ebook_parser_factory.dart
//

import Foundation

struct ParserFactory {
    /// 根据格式创建对应的解析器实例。
    /// - Parameters:
    ///   - format: 电子书格式
    ///   - encoding: 可选的字符编码提示（仅 TXT 解析器使用）
    /// - Returns: 实现 EbookParser 协议的解析器
    static func create(format: EbookFormat, encoding: String? = nil) -> any EbookParser {
        switch format {
        case .epub:        return EPUBParser()
        case .pdf:         return PDFParser()
        case .txt:         return TXTParser()
        case .mobi, .azw3: return MOBIParser()
        case .fb2:         return FB2Parser()
        case .unknown:     return TXTParser()  // fallback：按纯文本尝试解析
        }
    }
}
