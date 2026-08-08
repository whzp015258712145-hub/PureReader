//
//  TextEncoding.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import Foundation

struct TextEncoding: Identifiable {
    let id: String
    let name: String
    let encoding: String.Encoding
    
    static let allEncodings = [
        TextEncoding(id: "auto", name: "Auto (Detect)", encoding: .utf8),
        TextEncoding(id: "utf8", name: "UTF-8 (Universal)", encoding: .utf8),
        TextEncoding(id: "gbk", name: "GBK (Chinese)", encoding: String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))),
        TextEncoding(id: "shiftjis", name: "Shift-JIS (Japanese)", encoding: .shiftJIS),
        TextEncoding(id: "windows1252", name: "Windows-1252 (Western)", encoding: .windowsCP1252),
        TextEncoding(id: "windows1251", name: "Windows-1251 (Cyrillic)", encoding: String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.windowsCyrillic.rawValue)))),
    ]
}

