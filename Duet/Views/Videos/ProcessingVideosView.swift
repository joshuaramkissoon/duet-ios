//
//  ProcessingVideosView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 23/05/2025.
//

import SwiftUI

// MARK: - Loading Spinner Component

struct LoadingSpinner: View {
   let color: Color
   @State private var isAnimating = false
   
   var body: some View {
       Circle()
           .trim(from: 0, to: 0.7)
           .stroke(
               color,
               style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
           )
           .rotationEffect(.degrees(isAnimating ? 360 : 0))
           .animation(
               .linear(duration: 1.0)
               .repeatForever(autoreverses: false),
               value: isAnimating
           )
           .onAppear {
               isAnimating = true
           }
           .fixedSize()
   }
}



// MARK: - Preview

//struct ProcessingVideosView_Previews: PreviewProvider {
//    static var previews: some View {
//        let toast = ToastManager()
//        let viewModel = DateIdeaViewModel(toast: toast)
//        
//        // Add sample processing videos
//        viewModel.processingVideos = [
//            ProcessingVideo(
//                url: "https://www.tiktok.com/@user/video/1234567890",
//                startTime: Date().addingTimeInterval(-10),
//                status: .processing
//            ),
//            ProcessingVideo(
//                url: "https://www.instagram.com/reel/ABC123DEF456/?query=buildingmyquery&anothervalue=123",
//                startTime: Date().addingTimeInterval(-30),
//                endTime: Date().addingTimeInterval(30),
//                status: .completed(
//                    DateIdeaResponse(
//                        id: UUID().uuidString,
//                        summary: DateIdea(
//                            title: "Romantic Dinner out on the town with long night",
//                            summary: "A lovely evening out",
//                            sales_pitch: "Perfect date!",
//                            activity: Activity(title: "Outdoors", icon: "leaf"),
//                            location: "Paris",
//                            season: .summer,
//                            duration: "2 hours",
//                            cost_level: .medium,
//                            required_items: [],
//                            tags: []
//                        ),
//                        title: "Dinner",
//                        description: "Romantic dinner",
//                        thumbnail_b64: nil,
//                        thumbnail_url: nil,
//                        video_url: "test",
//                        original_source_url: "",
//                        user_id: nil,
//                        user_name: nil,
//                        created_at: nil
//                    )
//                )
//            ),
//            ProcessingVideo(
//                url: "https://www.youtube.com/watch?v=invalidvideo",
//                startTime: Date().addingTimeInterval(-45),
//                endTime: Date().addingTimeInterval(-35),
//                status: .failed("Invalid video format")
//            ),
//            ProcessingVideo(
//                url: "https://www.youtube.com/watch?v=invalidvideosuperlongvideowith even more textandmoretext",
//                startTime: Date().addingTimeInterval(-45),
//                endTime: Date(),
//                status: .failed("Invalid video format: The video could not be downloaded")
//            )
//        ]
//        
//        return ProcessingVideosView(viewModel: viewModel)
//            .environmentObject(toast)
//            .padding()
//            .withAppBackground()
//    }
//}
//
////#Preview {
////    ProcessingVideosView()
////}
