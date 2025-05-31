//
//  GroupsView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI

import CoreImage.CIFilterBuiltins

struct GroupsView: View {
    @StateObject private var vm = GroupsViewModel()
    @State private var showingCreateSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Create Group button
                    createGroupButton
                    
                    // My Groups section
                    if !vm.groups.isEmpty {
                        groupsSection
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .withAppBackground()
            .navigationTitle("Your Groups")
            .onAppear { vm.startListening() }
            .onDisappear { vm.stopListening() }
            .alert("Error", isPresented: Binding {
                vm.errorMessage != nil
            } set: { _ in vm.errorMessage = nil }) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .sheet(isPresented: Binding {
                vm.joinResult != nil
            } set: { showing in
                if !showing { vm.joinResult = nil }
            }) {
                if let result = vm.joinResult {
                    ResultAlertView(result: result) {
                        vm.joinResult = nil
                    }
                }
            }
            .sheet(
              isPresented: Binding(
                get: { vm.inviteLink != nil && vm.selectedGroup != nil },
                set: { newValue in
                  if !newValue {
                    vm.inviteLink = nil
                    // if you also want to clear selectedGroup:
                    // vm.selectedGroup = nil
                  }
                }
              )
            ) {
              // By the time this runs, both inviteLink and selectedGroup are non-nil
              if let link = vm.inviteLink, let group = vm.selectedGroup {
                NavigationStack {
                  InviteQRView(url: link, group: group)
                    .navigationTitle("Invite")
                    .navigationBarTitleDisplayMode(.large)
                }
              }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateGroupSheet(onSubmit: { name, emoji in
                    Task {
                        await vm.createGroup(named: name, emoji: emoji)
                    }
                })
            }
        }
    }
    
    // Create Group Button
    private var createGroupButton: some View {
        Button(action: {
            showingCreateSheet = true
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
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .foregroundColor(.primary)
    }
    
    // Groups List Section
    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My Groups")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.leading, 4)
            
            ForEach(vm.groups) { group in
                NavigationLink(destination: GroupDetailView(group: group)) {
                    GroupCard(group: group, onInvite: {
                        Task {
                            vm.selectedGroup = group
                            await vm.generateInviteLink(for: group)
                        }
                    }, onSelect: nil)
                }
            }
        }
    }
    
    // Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundColor(.appPrimary.opacity(0.6))
                .padding(.bottom, 8)
            
            Text("No groups yet")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Create a group to share date ideas with friends or your partner")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct GroupIcon: View {
    let group: DuetGroup
    let color: Color
    let diam: CGFloat
    let fontSize: CGFloat
    
    init(group: DuetGroup, diam: CGFloat = 50, fontSize: CGFloat = 18) {
        self.group = group
        self.diam = diam
        self.fontSize = fontSize
        self.color = getColorForText(group.name)
    }
    
    var body: some View {
        ZStack {
            AbstractGradientBackground(seedString: group.id ?? group.name)
                .frame(width: diam, height: diam)
            Text(group.emojiIcon ?? group.initials)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(color)
        }
    }
}

// Group Card Component
struct GroupCard: View {
    let group: DuetGroup
    /// If non‐nil, shows an invite button that calls this action.
    let onInvite: (() -> Void)?
    /// If non‐nil, the whole card becomes tappable and calls this.
    let onSelect: (() -> Void)?

    init(
      group: DuetGroup,
      onInvite: (() -> Void)? = nil,
      onSelect: (() -> Void)? = nil
    ) {
      self.group = group
      self.onInvite = onInvite
      self.onSelect = onSelect
    }
    
    var body: some View {
        let card = HStack(alignment: .center, spacing: 16) {
            GroupIcon(group: group)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                Text("\(group.members.count) member\(group.members.count>1 ? "s" : "")")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()

            // only render if onInvite provided
            if let onInvite = onInvite {
                Button(action: onInvite) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                        Text("Invite")
                    }
                    .font(.subheadline).fontWeight(.medium)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.appPrimary.opacity(0.15))
                    .foregroundColor(Color.appPrimary)
                    .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        
        // wrap in a Button if onSelect provided
        if let onSelect = onSelect {
            Button(action: onSelect) {
                card
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            card
        }
    }
    
    // Generate color from group name (deterministic)
    private var groupColor: Color {
        let colors: [Color] = [.appPrimary, .appSecondary, .appAccent, .blue, .purple, .teal, .pink]
        var total: Int = 0
        for char in group.name.unicodeScalars {
            total += Int(char.value)
        }
        return colors[total % colors.count]
    }
}

// Create Group Sheet
struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedEmoji: String? = nil
    @State private var showingEmojiPicker = false
    
    let onSubmit: (String, String?) -> Void
    

    @ViewBuilder
    private var emojiSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Group Icon (Optional)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingEmojiPicker.toggle()
                }
            }) {
                HStack {
                    if let emoji = selectedEmoji {
                        Text(emoji)
                            .font(.title2)
                        Text("Tap to change")
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "face.smiling")
                            .foregroundColor(.appPrimary)
                        Text("Add an emoji")
                            .foregroundColor(.appPrimary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(showingEmojiPicker ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: showingEmojiPicker)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            // Inline emoji picker using the reusable component
            if showingEmojiPicker {
                EmojiPickerContent(
                    selectedEmoji: $selectedEmoji,
                    onEmojiSelected: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingEmojiPicker = false
                        }
                    }
                )
            }
        }
    }

    private var isValidInput: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
       NavigationView {
           ScrollView {
               VStack(spacing: 24) {
                   // Group preview
                   VStack(spacing: 16) {
                       // Group icon preview
                       ZStack {
                           Circle()
                               .fill(Color.appPrimary.opacity(0.15))
                               .frame(width: 80, height: 80)
                           
                           if let emoji = selectedEmoji {
                               Text(emoji)
                                   .font(.system(size: 36))
                           } else {
                               Image(systemName: "person.3.fill")
                                   .font(.system(size: 32))
                                   .foregroundColor(.appPrimary)
                           }
                       }
                       
                       Text("Create a New Group")
                           .font(.title2)
                           .fontWeight(.bold)
                       
                       Text("Groups let you share and plan activities together")
                           .font(.subheadline)
                           .foregroundColor(.secondary)
                           .multilineTextAlignment(.center)
                           .padding(.horizontal, 24)
                   }
                   .padding(.top, 20)
                   
                   VStack(spacing: 20) {
                       // Group emoji selection
                       emojiSelectionSection
                       
                       // Group name field
                       VStack(alignment: .leading, spacing: 8) {
                           Text("Group Name")
                               .font(.headline)
                               .foregroundColor(.secondary)
                           
                           TextField("e.g. Date Night Crew, Weekend Squad", text: $name)
                               .padding()
                               .background(Color.gray.opacity(0.1))
                               .cornerRadius(10)
                       }
                   }
                   .padding(.horizontal, 24)
                   
                   Spacer()
                   
                   // Create button
                   Button(action: {
                       if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                           onSubmit(name, selectedEmoji)
                           dismiss()
                       }
                   }) {
                       Text("Create Group")
                           .fontWeight(.semibold)
                           .foregroundColor(isValidInput ? .appPrimary : .white)
                           .padding()
                           .frame(maxWidth: .infinity)
                           .background(
                               isValidInput ?
                               Color.appPrimaryLightBackground : Color.gray
                           )
                           .cornerRadius(16)
                           .padding(.horizontal, 24)
                   }
                   .disabled(!isValidInput)
                   .padding(.bottom, 24)
               }
           }
           .withAppBackground()
           .navigationBarItems(trailing: Button("Cancel") {
               dismiss()
           })
           .navigationBarTitleDisplayMode(.inline)
       }
    }
}

#Preview {
    CreateGroupSheet { name, emoji in
        
    }
}
