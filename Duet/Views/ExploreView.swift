//
//  ExploreView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 19/05/2025.
//

import SwiftUI
import AVKit

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @State private var selectedActivity: DateIdeaResponse?

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // MARK: Search bar
                HStack {
                    TextField("Search ideas", text: $viewModel.query)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                        .onSubmit {
                            viewModel.performSearch()
                        }
                    
                    if !viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button(action: viewModel.performSearch) {
                            Image(systemName: "magnifyingglass")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.appPrimary)
                                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                )
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                .padding(.horizontal)
                
                // MARK: Body
                if viewModel.isLoading {
                    SearchingView()
                }
                else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                else if viewModel.hasSearched && viewModel.results.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No activities found")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                else {
                    // Only scroll when there are results
                    if !viewModel.results.isEmpty {
                        resultList(viewModel.results)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Explore")
            .sheet(item: $selectedActivity) { activity in
                NavigationView {
                    ActivityDetailLoader(activityId: activity.id)
                }
            }
        }
    }
    
    @ViewBuilder
    private func resultList(_ list: [DateIdeaResponse]) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(list, id: \.id) { activity in
                    ActivityHistoryCard(activity: activity)
                        .onTapGesture { selectedActivity = activity }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct SearchingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image("duet")
              .resizable()
              .scaledToFit()
              .clipShape(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
              )
              .padding(.horizontal, 40)
              .padding(.top, 20)
            
            Text("Searching for similar ideas")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.appPrimary)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimary))
                .scaleEffect(1.5)
                .padding(.top, 16)
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .withAppBackground()
    }
}

#Preview {
    ExploreView()
}
