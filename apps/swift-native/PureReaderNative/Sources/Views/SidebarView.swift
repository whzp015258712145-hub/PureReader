//
//  SidebarView.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var vm: ReaderViewModel
    @State private var selectedChapterIndex: Int?
    var onChapterTap: ((Int) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: 38 + proxy.safeAreaInsets.top)

                HStack(alignment: .center, spacing: 10) {
                    Text(l("toc"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(vm.config.theme.textColorValue)

                    Spacer(minLength: 8)

                    HStack(spacing: 4) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                vm.isSidebarCollapsed = true
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(vm.config.theme.textColorValue.opacity(0.6))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)

                        Button {
                            NotificationCenter.default.post(name: .showSettings, object: nil)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(vm.config.theme.textColorValue.opacity(0.6))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                if let content = vm.content, !content.chapters.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(content.chapters.enumerated()), id: \.offset) { index, chapter in
                                let isSelected = selectedChapterIndex == index
                                Button {
                                    selectedChapterIndex = index
                                    #if DEBUG
                                    print("🧭 [SwiftNav] TOC tap index=\(index), title=\(chapter.title), hasCallback=\(onChapterTap != nil)")
                                    #endif
                                    onChapterTap?(index)
                                } label: {
                                    HStack(spacing: 0) {
                                        Text(chapter.title)
                                            .font(.system(size: 14, weight: .regular))
                                            .lineLimit(2)
                                            .foregroundColor(
                                                isSelected
                                                ? vm.config.theme.textColorValue
                                                : vm.config.theme.textColorValue.opacity(0.88)
                                            )
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 16 + CGFloat(chapter.level * 12))
                                    .padding(.trailing, 12)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                isSelected
                                                ? vm.config.theme.accentColorValue.opacity(0.18)
                                                : Color.clear
                                            )
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                            }
                        }
                        .padding(.top, 2)
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.never)
                } else {
                    Spacer()
                    VStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 48, weight: .regular))
                            .foregroundColor(vm.config.theme.textColorValue.opacity(0.3))

                        Spacer().frame(height: 16)

                        Text(l("no_chapters"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(vm.config.theme.textColorValue.opacity(0.6))
                            .multilineTextAlignment(.center)

                        Spacer().frame(height: 8)

                        Text(l("no_chapters_subtitle"))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(vm.config.theme.textColorValue.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    Spacer()
                }

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(vm.config.theme.uiOverlayColorValue.opacity(0.3))
        }
    }

    private func l(_ key: String) -> String {
        vm.l(key)
    }

}

public extension Notification.Name {
    static let showSettings = Notification.Name("showSettings")
}

