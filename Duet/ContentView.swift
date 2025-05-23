import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var toast: ToastManager
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
                ExploreView()
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
    }

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                VStack {
                    URLInputView(viewModel: viewModel)
                        .transition(.opacity)
                    
                    ProcessingVideosView(viewModel: viewModel)
                        .transition(.opacity)
                        .padding()

                    ActivityHistoryView(viewModel: activityVM)
                        .padding(.bottom, 20)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(toast: ToastManager(), activityHistoryVM: ActivityHistoryViewModel())
    }
}
