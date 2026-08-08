//
//  TextRenderer.swift
//  PureReader
//
//  Spec D — D3: TXT 分页渲染器
//  对应 Flutter lib/rendering/txt_reader_widget.dart
//

import SwiftUI

struct TextRenderer: View {
    let pages: [String]
    @Binding var config: ReaderConfig
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 内容区
            ScrollView {
                Text(pages[safe: currentPage] ?? "")
                    .font(.custom(config.fontFamily, size: config.fontSize))
                    .foregroundColor(Color(hex: config.theme.textColor))
                    .lineSpacing(config.fontSize * (config.lineHeight - 1))
                    .padding(40)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(hex: config.theme.backgroundColor))

            // MARK: 翻页控制栏（仅多页时显示）
            if pages.count > 1 {
                HStack {
                    Button("<") {
                        if currentPage > 0 { currentPage -= 1 }
                    }
                    .disabled(currentPage == 0)

                    Spacer()

                    Text("\(currentPage + 1) / \(pages.count)")
                        .foregroundColor(Color(hex: config.theme.textColor).opacity(0.5))
                        .font(.caption)

                    Spacer()

                    Button(">") {
                        if currentPage < pages.count - 1 { currentPage += 1 }
                    }
                    .disabled(currentPage == pages.count - 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(hex: config.theme.uiOverlayColor).opacity(0.5))
            }
        }
    }
}

// MARK: - Array 安全下标扩展
// 防止 currentPage 越界导致崩溃

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}


