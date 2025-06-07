import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var toast: ToastManager
    @EnvironmentObject private var exploreVM: ExploreViewModel
    @EnvironmentObject private var processingManager: ProcessingManager
    @EnvironmentObject private var navigationManager: NavigationManager
    @StateObject var activityVM: ActivityHistoryViewModel
    @StateObject private var viewModel: DateIdeaViewModel
    
    // Navigation state for deep linking
    @State private var deepLinkIdeaToOpen: DateIdeaResponse?
    @State private var isLoadingDeepLinkIdea = false

    init(toast: ToastManager, activityHistoryVM: ActivityHistoryViewModel) {
        _activityVM = StateObject(wrappedValue: activityHistoryVM)
        _viewModel = StateObject(wrappedValue: DateIdeaViewModel(toast: toast, activityHistoryVM: activityHistoryVM))
    }

    var body: some View {
        TabView(selection: $navigationManager.selectedTab) {
            // Home
            NavigationStack {
                homeContent
                    .withAppBackground()
                    .navigationTitle("Duet")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(0)

            // Explore
            NavigationStack {
                ExploreView(viewModel: exploreVM)
                    .withAppBackground()
            }
            .tabItem {
                Label("Explore", systemImage: "magnifyingglass")
            }
            .tag(1)
            
            // Groups
            GroupsView()
                .withAppBackground()
                .tabItem { Label("Groups",  systemImage: "person.3.fill") }
                .tag(2)
            
            // Profile
            NavigationStack {
                ProfileView()
                    .navigationTitle("Explore")
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .tag(3)
        }
        .accentColor(.appPrimary)
        .tint(.appPrimary)
        .onChange(of: navigationManager.selectedTab) { oldValue, newValue in
            // If tapping the explore tab while already on explore tab, reset to root
            if oldValue == 1 && newValue == 1 {
                NotificationCenter.default.post(name: .exploreTabTapped, object: nil)
            }
        }
        .onAppear {
            // Configure tab bar appearance for better dark mode support
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.appPrimary)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.appPrimary)]
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            
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
        .onChange(of: navigationManager.pendingIdeaNavigation) { pendingNavigation in
            if let pending = pendingNavigation {
                handlePendingNavigation(pending)
            }
        }
        .sheet(item: $deepLinkIdeaToOpen) { ideaToOpen in
            NavigationView {
                DateIdeaDetailView(
                    dateIdea: ideaToOpen,
                    groupId: navigationManager.pendingIdeaNavigation?.groupId,
                    viewModel: DateIdeaViewModel(toast: toast, videoUrl: ideaToOpen.cloudFrontVideoURL)
                )
                .navigationBarTitleDisplayMode(.inline)
//                .toolbar {
//                    ToolbarItem(placement: .navigationBarTrailing) {
//                        Button("Done") {
//                            deepLinkIdeaToOpen = nil
//                        }
//                    }
//                }
            }
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
        .scrollDismissesKeyboard(.immediately)
    }
    
    // MARK: - Deep Link Navigation
    
    private func handlePendingNavigation(_ pending: PendingIdeaNavigation) {
        guard !isLoadingDeepLinkIdea else { return }
        
        isLoadingDeepLinkIdea = true
        
        // Fetch the idea data
        Task {
            do {
                let ideaData = try await NetworkClient.shared.getActivity(id: pending.ideaId)
                await MainActor.run {
                    isLoadingDeepLinkIdea = false
                    deepLinkIdeaToOpen = ideaData
                    navigationManager.clearPendingNavigation()
                    print("🧭 ContentView: Successfully loaded and opened idea \(pending.ideaId)")
                }
            } catch {
                await MainActor.run {
                    isLoadingDeepLinkIdea = false
                    navigationManager.clearPendingNavigation()
                    toast.error("Could not open completed idea")
                    print("❌ ContentView: Failed to load idea for deep link: \(error)")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(toast: ToastManager(), activityHistoryVM: ActivityHistoryViewModel())
            .environmentObject(ProcessingManager(toast: ToastManager(), activityVM: ActivityHistoryViewModel()))
            .environmentObject(NavigationManager.shared)
    }
}
