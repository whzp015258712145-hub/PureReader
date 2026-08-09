//
//  ReaderView.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-23.
//
//  对应 Flutter: lib/unified_render_engine.dart 的格式路由逻辑
//

import SwiftUI

struct ReaderView: View {

    @EnvironmentObject var vm: ReaderViewModel

    var body: some View {
        ZStack {
            // 背景色跟随主题（对应 Flutter Container(color: theme.backgroundColor)）
            vm.config.theme.backgroundColorValue
                .ignoresSafeArea()

            if vm.isLoading {
                // 对应 Flutter CupertinoActivityIndicator
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)

            } else if let err = vm.errorMessage {
                // 错误状态（对应 Flutter ErrorRecoveryManager 展示逻辑）
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(vm.config.theme.textColorValue.opacity(0.4))
                    Text(err)
                        .foregroundColor(vm.config.theme.textColorValue.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button(vm.l("retry")) {
                        if let path = vm.currentPath {
                            Task { await vm.loadBook(path: path) }
                        }
                    }
                }

            } else if let content = vm.content {
                // 格式路由（对应 Flutter UnifiedRenderEngine._buildRenderer()）
                switch content.format {
                case .epub, .mobi, .azw3, .fb2:
                    // 对应 Flutter WebViewEpubRenderer
                    WebViewRenderer(content: content, config: $vm.config, vm: vm)
                case .pdf:
                    // 对应 Flutter PdfReaderWidget
                    PDFRenderer(filePath: content.filePath, config: $vm.config)
                case .txt:
                    // 对应 Flutter TxtReaderWidget
                    TextRenderer(pages: content.pages ?? [], config: $vm.config)
                case .unknown:
                    Text(vm.l("unsupported_format"))
                        .foregroundColor(vm.config.theme.textColorValue.opacity(0.5))
                }

            } else {
                // 未打开书籍时显示空状态（对应 Flutter _buildEmptyState）
                EmptyStateView()
            }
        }
    }
}
