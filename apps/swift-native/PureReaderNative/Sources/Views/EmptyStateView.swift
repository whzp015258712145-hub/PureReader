//
//  EmptyStateView.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject var vm: ReaderViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book")
                .font(.system(size: 80))
                .foregroundColor(vm.config.theme.textColorValue.opacity(0.15))
            Button(vm.l("open")) {
                vm.openFilePicker()
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.config.theme.accentColorValue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
