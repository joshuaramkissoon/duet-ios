import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var toast: ToastManager
    @EnvironmentObject private var exploreVM: ExploreViewModel
    @EnvironmentObject private var processingManager: ProcessingManager
    @StateObject var activityVM: ActivityHistoryViewModel
    @StateObject private var viewModel: DateIdeaViewModel

    init(toast: ToastManager, activityHistoryVM: ActivityHistoryViewModel) {
        _activityVM = StateObject(wrappedValue: activityHistoryVM)
        _viewModel = StateObject(wrappedValue: DateIdeaViewModel(toast: toast, activityHistoryVM: activityHistoryVM))
    }

    var body: some View {
        TabView {
            // Home
            NavigationView {
                homeContent
                    .withAppBackground()
                    .navigationTitle("Duet")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            // Explore
            NavigationView {
                ExploreView(viewModel: exploreVM)
                    .withAppBackground()
                    .navigationTitle("Explore")
            }
            .tabItem {
                Label("Explore", systemImage: "magnifyingglass")
            }
            
            // Groups
            GroupsView()
                .withAppBackground()
                .tabItem { Label("Groups",  systemImage: "person.3.fill") }
            
            // Profile
            NavigationView {
                ProfileView()
                    .navigationTitle("Explore")
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
        }
        .accentColor(.appPrimary)
        .onAppear {
            // Configure the shared processing manager
            processingManager.updateToast(toast)
            
            // Provide the ActivityHistoryViewModel reference
            processingManager.updateActivityVM(activityVM)
            
            // Set up the processing manager in the view model
            viewModel.setProcessingManager(processingManager)
            
            // Start listening to user processing jobs
            print("🔄 ContentView appeared - starting user processing jobs listener")
            processingManager.startListeningToUserJobs()
        }
        .onDisappear {
            // Stop listening when view disappears
            print("🛑 ContentView disappeared - stopping user processing jobs listener")
            processingManager.stopListeningToUserJobs()
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                URLInputView(viewModel: viewModel)
                    .transition(.opacity)
                
                ProcessingJobsView(processingManager: processingManager)
                    .transition(.opacity)

                ActivityHistoryView(viewModel: activityVM)
                    .transition(.opacity)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(toast: ToastManager(), activityHistoryVM: ActivityHistoryViewModel())
            .environmentObject(ProcessingManager(toast: ToastManager(), activityVM: ActivityHistoryViewModel()))
    }
}
