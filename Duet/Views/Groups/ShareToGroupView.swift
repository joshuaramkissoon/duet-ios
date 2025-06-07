//
//  ShareToGroupView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI

struct ShareToGroupView: View {
    @StateObject private var groupsVM = GroupsViewModel()
    @StateObject private var vm: ShareToGroupViewModel
    
    @EnvironmentObject private var toast: ToastManager
    
    init(idea: DateIdeaResponse,
         isPresented: Binding<Bool>,
         toastManager: ToastManager)
    {
        self.idea = idea
        self._isPresented = isPresented
        _vm = StateObject(
            wrappedValue: ShareToGroupViewModel(toastManager: toastManager)
        )
    }
    
    let idea: DateIdeaResponse
    @Binding var isPresented: Bool
    @State private var showCreateGroupSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if groupsVM.groups.isEmpty {
                    VStack(spacing: 16) {
                        Image("duet-group")
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 40)
                            .padding(.top, 20)

                        Text("No Groups Yet")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.midnightSlateSoft)
                        
                        Text("You're not in any groups yet. Create a group first to share this idea.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button(action: {
                            showCreateGroupSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Group")
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.appPrimaryLightBackground)
                            .foregroundColor(.appPrimary)
                            .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // List of groups
                    ScrollView {
                        VStack(spacing: 8) {
                            // Thumbnail section
                            if let thumbnailB64 = idea.thumbnail_b64 {
                                VStack(spacing: 12) {
                                    Base64ImageView(
                                        base64String: thumbnailB64,
                                        thumbWidth: 200,
                                        thumbHeight: 200 / (idea.videoMetadata?.aspectRatio ?? 9/16)
                                    )
                                    
                                    Text(idea.title)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .padding(.top, 16)
                                .padding(.bottom, 16)
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 32))
                                        .foregroundColor(.appPrimary)
                                    
                                    Text("Share Date Idea")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text("Choose a group to share this amazing date idea with")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 20)
                            }
                            
                            // Create Group button
                            Button(action: {
                                showCreateGroupSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.appPrimary)
                                    Text("Create a new group")
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.appPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.adaptiveCardBackground)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                            .padding(.horizontal)
                            
                            Divider().padding(12)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(groupsVM.groups, id: \.id) { group in
                                    GroupCard(
                                        group: group,
                                        onInvite: nil,
                                        onSelect: {
                                            Task {
                                                await vm.share(idea, to: group, using: groupsVM)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .withAppBackground()
            .navigationTitle("Share to Group")
            .navigationBarTitleDisplayMode(.inline)
            .toast($toast.state)
            .onAppear { groupsVM.startListening() }
        }
        .sheet(isPresented: $showCreateGroupSheet) {
            CreateGroupSheet(onSubmit: { name, emoji in
                Task {
                    await groupsVM.createGroup(named: name, emoji: emoji)
                    showCreateGroupSheet = false
                }
            })
            .buttonStyle(.plain)
        }
    }
}

struct ShareToGroupView_Previews: PreviewProvider {
    @State static var showing = true
    static let dateIdea = DateIdea(
        id: "idea1",
        title: "Stargazing Picnic",
        summary: "Enjoy a cozy picnic under the stars.",
        sales_pitch: "Romantic and unforgettable!",
        activity: Activity(title: "Outdoor", icon: "sparkles"),
        location: "Hilltop Park",
        season: .summer,
        duration: "2–3 hours",
        cost_level: .medium,
        required_items: ["Blanket", "Snacks"],
        tags: [Tag(id: "night", title: "Night", icon: "moon.stars")],
        suggested_itinerary: nil
    )
    
    static var previews: some View {
        
        ShareToGroupView(
            idea: DateIdeaResponse(id: "id", summary: dateIdea, title: dateIdea.title, description: dateIdea.summary, thumbnail_b64: nil, thumbnail_url: nil, video_url: nil, videoMetadata: nil, original_source_url: nil, user_id: nil, user_name: nil, created_at: nil, isPublic: false),
            isPresented: $showing,
            toastManager: ToastManager()
        )
        .environmentObject(ToastManager())
        .environmentObject({
            let vm = GroupsViewModel()
            vm.groups = [
                DuetGroup(id: "g1", name: "Weekend Crew", ownerId: "u1", members: ["u1","u2"]),
                DuetGroup(id: "g2", name: "Date Night",   ownerId: "u2", members: ["u1","u2","u3"])
            ]
            return vm
        }())
    }
}
