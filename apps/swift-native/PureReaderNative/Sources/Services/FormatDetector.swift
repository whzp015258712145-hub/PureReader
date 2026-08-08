//
//  FormatDetector.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-23.
//
//  对应 Flutter: lib/formats/file_format_detector.dart
//  检测顺序：先魔数，再扩展名 fallback
//

import Foundation

struct FormatDetector {

    /// 检测文件格式。
    /// 先读取文件头字节做魔数检测，无法确定时 fallback 到扩展名。
    /// 任何错误均返回 `.unknown`，不抛出异常。
    static func detect(path: String) -> EbookFormat {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()

        // 读前 68 字节用于魔数检测（PDB 偏移 60 处需要 8 字节，共 68 字节）
        guard let fh = FileHandle(forReadingAtPath: path) else {
            return .unknown
        }
        defer { try? fh.close() }
        let header = fh.readData(ofLength: 68)

        // ── PDF: %PDF  (25 50 44 46) ────────────────────────────────────────
        if header.count >= 4,
           header[0] == 0x25, header[1] == 0x50,
           header[2] == 0x44, header[3] == 0x46 {
            return .pdf
        }

        // ── ZIP / EPUB: PK\x03\x04  (50 4B 03 04) ──────────────────────────
        // EPUB 是合法的 ZIP，凡扩展名为 .epub 的 ZIP 文件视为 EPUB
        // 对应 Flutter: 先检查 ZIP 魔数，再确认 mimetype 条目
        if header.count >= 4,
           header[0] == 0x50, header[1] == 0x4B,
           header[2] == 0x03, header[3] == 0x04 {
            return ext == "epub" ? .epub : .unknown
        }

        // ── MOBI / AZW3: PDB 格式 ──────────────────────────────────────────
        // PDB 头：偏移 52 处有 8 字节 type+creator 字段
        // MOBI:  type="BOOK" creator="MOBI" → 合并为 "BOOKMOBI"
        // AZW3:  type="BOOK" creator="MOBI"（同）但扩展名为 azw3/azw
        // 对应 Flutter file_format_detector.dart 的 PDB 魔数逻辑
        if header.count >= 68 {
            let typeCreatorBytes = header.subdata(in: 52..<60)
            let typeCreator = String(bytes: typeCreatorBytes, encoding: .ascii) ?? ""
            if typeCreator.hasPrefix("BOOKMOBI") {
                // AZW3 和 MOBI 共用同一 PDB 头，靠扩展名区分
                return (ext == "azw3" || ext == "azw") ? .azw3 : .mobi
            }
        }

        // ── Fallback：扩展名检测 ────────────────────────────────────────────
        // TXT 无魔数，只能走扩展名（对应 Flutter 的 txt 分支）
        switch ext {
        case "epub":        return .epub
        case "pdf":         return .pdf
        case "txt", "text": return .txt
        case "mobi":        return .mobi
        case "azw3", "azw": return .azw3
        case "fb2":         return .fb2
        default:            return .unknown
        }
    }
}


