//
//  PDFRenderer.swift
//  PureReader
//
//  Spec D — D2: PDF 渲染器
//  使用系统 PDFKit，无第三方库，对应 Flutter lib/rendering/pdf_reader_widget.dart
//

import PDFKit
import SwiftUI

struct PDFRenderer: NSViewRepresentable {
    let filePath: String
    @Binding var config: ReaderConfig

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        if let doc = PDFDocument(url: URL(fileURLWithPath: filePath)) {
            pdfView.document = doc
        }

        applyTheme(to: pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        applyTheme(to: pdfView)
    }

    // MARK: - Private

    private func applyTheme(to pdfView: PDFView) {
        pdfView.backgroundColor = NSColor(hex: config.theme.backgroundColor)
    }
}

// MARK: - NSColor Hex 扩展
// PDFView.backgroundColor 需要 NSColor，无法直接用 SwiftUI Color

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            srgbRed:   Double(r) / 255,
            green:     Double(g) / 255,
            blue:      Double(b) / 255,
            alpha:     Double(a) / 255
        )
    }
}


