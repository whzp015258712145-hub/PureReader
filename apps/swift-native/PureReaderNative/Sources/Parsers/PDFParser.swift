//
//  PDFParser.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import Foundation
import PDFKit

struct PDFParser: EbookParser {
    func parse(filePath: String, encoding: String? = nil) async throws -> EbookContent {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ParserError.fileNotFound(filePath)
        }
        guard let doc = PDFDocument(url: URL(fileURLWithPath: filePath)) else {
            throw ParserError.invalidFile
        }
        let title  = doc.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        let author = doc.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String

        // 提取章节目录（从 PDFOutline）
        var chapters: [EbookContent.Chapter] = []
        if let outline = doc.outlineRoot {
            chapters = extractOutline(outline: outline, level: 0)
        }

        return EbookContent(
            format: .pdf,
            filePath: filePath,
            title: title,
            author: author,
            chapters: chapters,
            htmlContent: nil,
            pages: nil,
            useFallbackRenderer: false
        )
    }

    private func extractOutline(outline: PDFOutline, level: Int) -> [EbookContent.Chapter] {
        var result: [EbookContent.Chapter] = []
        for i in 0..<outline.numberOfChildren {
            guard let item = outline.child(at: i) else { continue }
            // anchor 使用页码字符串，供渲染层跳转
            let pageNumber = item.destination?.page?.pageRef?.pageNumber ?? 0
            let anchor = String(pageNumber)
            result.append(EbookContent.Chapter(
                title: item.label ?? "Section \(i + 1)",
                anchor: anchor,
                level: level,
                href: nil
            ))
            // 递归提取子条目
            if item.numberOfChildren > 0 {
                result.append(contentsOf: extractOutline(outline: item, level: level + 1))
            }
        }
        return result
    }
}


