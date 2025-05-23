//
//  SearchView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 19/05/2025.
//

import SwiftUI
import AVKit

struct SearchView: View {
    @ObservedObject var viewModel: ActivityHistoryViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("Search ideas", text: $viewModel.searchQuery, onCommit: viewModel.performSearch)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .disableAutocorrection(true)

                if !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: viewModel.performSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.appPrimary)
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            )
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .padding(.horizontal)
        }
        .withAppBackground()
    }
}


#Preview {
    SearchView(viewModel: ActivityHistoryViewModel())
}
