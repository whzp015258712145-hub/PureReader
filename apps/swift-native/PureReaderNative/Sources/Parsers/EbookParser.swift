//
//  EbookParser.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-23.
//

import Foundation

protocol EbookParser {
    func parse(filePath: String, encoding: String?) async throws -> EbookContent
}

enum ParserError: LocalizedError {
    case fileNotFound(String)
    case invalidFile
    case invalidStructure(String)
    case timeout
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return "File not found: \(path)"
        case .invalidFile: return "Invalid or corrupted file"
        case .invalidStructure(let d): return "Invalid structure: \(d)"
        case .timeout: return "File loading timed out"
        case .unsupportedFormat: return "Unsupported file format"
        }
    }
}
