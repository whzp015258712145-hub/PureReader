//
//  ContentView.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import SwiftUI
import UniformTypeIdentifiers
import Inject

public struct ContentView: View {
    @ObserveInjection var inject
    @EnvironmentObject var vm: ReaderViewModel


    public init() {}

    public var body: some View {
        HSplitView {
            if vm.isSidebarCollapsed {
                collapsedSidebarHandle
                    .frame(width: 40)
            } else {
                SidebarView(onChapterTap: { index in
                    #if DEBUG
                    print("🧭 [SwiftNav] ContentView forwarding chapter tap index=\(index), handlerReady=\(vm.scrollToChapterHandler != nil)")
                    #endif
                    vm.scrollToChapterHandler?(index)
                })
                .frame(width: 280)
            }

            ReaderView()
                .frame(minWidth: 400, maxWidth: .infinity)
        }
        .frame(minWidth: 900, minHeight: 600)
        // 文件拖拽打开（对应 Flutter _initNativeFileListener）
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            providers.first?.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil)
                else { return }
                Task { await vm.loadBook(path: url.path) }
            }
            return true
        }
        .enableInjection()
    }


    private var collapsedSidebarHandle: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 38 + proxy.safeAreaInsets.top)

                Spacer().frame(height: 8)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        vm.isSidebarCollapsed = false
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(vm.config.theme.textColorValue.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(vm.config.theme.uiOverlayColorValue.opacity(0.3))
        }
    }
}
