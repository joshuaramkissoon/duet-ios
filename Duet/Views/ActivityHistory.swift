//
//  ActivityHistory.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import SwiftUI

struct ActivityHistoryView: View {
    @StateObject private var viewModel: ActivityHistoryViewModel
    @State private var tabHeight: CGFloat = 0
    @State private var selectedActivity: DateIdeaResponse? = nil
    
    init(viewModel: ActivityHistoryViewModel = ActivityHistoryViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack {
                    Text("Recent Ideas")
                        .font(.title3).fontWeight(.bold)
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button { viewModel.loadActivities() } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.appPrimary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                if viewModel.activities.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    resultList(viewModel.activities)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    @ViewBuilder
    private func resultList(_ list: [DateIdeaResponse]) -> some View {
        LazyVStack(spacing: 16) {
            ForEach(list, id: \.id) { activity in
                ActivityHistoryCard(activity: activity)
                    .onTapGesture { selectedActivity = activity }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func setupAppearance() {
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(Color.appPrimary)
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(Color.appSecondary)
      }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundColor(.appPrimary)
            
            Text("No recent ideas yet")
                .font(.headline)
            
            Text("Your recent ideas will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}

struct ActivityDetailLoader: View {
    let activityId: String
    @EnvironmentObject private var toast: ToastManager
    @StateObject private var viewModel = ActivityDetailViewModel()
    @StateObject private var dateIdeaViewModel: DateIdeaViewModel
    
    init(activityId: String) {
        self.activityId = activityId
        self._dateIdeaViewModel = StateObject(wrappedValue: DateIdeaViewModel(toast: ToastManager(), videoUrl: ""))
    }
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else if let dateIdea = viewModel.dateIdea {
                DateIdeaDetailView(dateIdea: dateIdea, viewModel: dateIdeaViewModel)
                    .onAppear {
                        // Update video URL and toast manager when dateIdea becomes available
                        dateIdeaViewModel.videoUrl = dateIdea.cloudFrontVideoURL
                        dateIdeaViewModel.updateToastManager(toast)
                    }
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    
                    Text("Error loading activity")
                        .font(.headline)
                    
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        viewModel.loadActivity(id: activityId)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .withAppBackground()
        .navigationTitle("Date Idea")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadActivity(id: activityId)
            // Update the dateIdeaViewModel with the correct toast manager
            dateIdeaViewModel.updateToastManager(toast)
        }
    }
}

#Preview {
    let mockDateIdea = DateIdea(
        title: "Sunset Picnic in the Park",
        summary: "Enjoy a romantic evening with your partner watching the sunset while having a picnic at a local park. Bring along wine, cheese, and fruits for a perfect evening.",
        sales_pitch: "Create an unforgettable evening under the fading sky with delicious treats and the one you love!",
        activity: Activity(title: "Outdoors", icon: "sun.max"),
        location: "Central Park, NYC",
        season: .summer,
        duration: "2-3 hours",
        cost_level: .low,
        required_items: ["Picnic blanket", "Wine and glasses", "Cheese and crackers", "Portable speaker"],
        tags: [Tag(title: "Romantic", icon: "heart.fill"), Tag(title: "relaxing", icon: "moon"), Tag(title: "nature", icon: "leaf")],
        suggested_itinerary: []
    )
    let res = DateIdeaResponse(id: "", summary: mockDateIdea, title: "Title", description: "Desc", thumbnail_b64: nil, thumbnail_url: nil, video_url: "", videoMetadata: VideoMetadata(ratio_width: 9, ratio_height: 16), original_source_url: nil, user_id: nil, user_name: nil, created_at: nil)
    let vm = ActivityHistoryViewModel(activities: [res])
    ActivityHistoryView(viewModel: vm)
        .environmentObject(ToastManager())
        .withAppBackground()
}
