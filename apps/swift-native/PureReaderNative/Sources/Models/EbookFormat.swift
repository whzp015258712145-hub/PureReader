//
//  EbookFormat.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import Foundation

public enum EbookFormat: String, Codable {
    case epub
    case pdf
    case txt
    case mobi
    case azw3
    case fb2
    case unknown

    public var displayName: String {
        switch self {
        case .epub: return "EPUB"
        case .pdf: return "PDF"
        case .txt: return "TXT"
        case .mobi: return "MOBI"
        case .azw3: return "AZW3"
        case .fb2: return "FB2"
        case .unknown: return "Unknown"
        }
    }

    public var fileExtensions: [String] {
        switch self {
        case .epub: return ["epub"]
        case .pdf: return ["pdf"]
        case .txt: return ["txt"]
        case .mobi: return ["mobi"]
        case .azw3: return ["azw3", "azw"]
        case .fb2: return ["fb2"]
        case .unknown: return []
        }
    }
}


