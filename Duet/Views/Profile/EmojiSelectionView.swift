//
//  EmojiSelectionView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 23/05/2025.
//

import SwiftUI

import SwiftUI

struct EmojiPickerContent: View {
    @Binding var selectedEmoji: String?
    @State private var manualEmojiInput = ""
    
    let onEmojiSelected: () -> Void
    
    // Popular group emojis
    private let groupEmojis = [
        "👥", "🎉", "❤️", "🍕", "🎬", "🏖️", "🎵", "⚽️",
        "🍷", "🌟", "🔥", "💫", "🎯", "🚀", "🎨", "📚",
        "🌮", "🍔", "🎪", "🎭", "🎸", "🏃‍♂️", "🏊‍♀️", "🚴‍♂️"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Manual emoji input
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter your own emoji")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("Type emoji here", text: $manualEmojiInput)
                        .font(.title2)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .onChange(of: manualEmojiInput) { _, newValue in
                            // Filter to only keep emojis and limit to 1 character
                            let filtered = newValue.filter { $0.isEmoji }
                            if filtered.count > 1 {
                                manualEmojiInput = String(filtered.first!)
                            } else {
                                manualEmojiInput = filtered
                            }
                        }
                    
                    Button("Use") {
                        if !manualEmojiInput.isEmpty {
                            selectedEmoji = manualEmojiInput
                            manualEmojiInput = ""
                            onEmojiSelected()
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        manualEmojiInput.isEmpty ?
                        Color.secondary : Color.appPrimary
                    )
                    .cornerRadius(8)
                    .disabled(manualEmojiInput.isEmpty)
                }
            }
            
            // Divider
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                Text("or choose")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            
            // Preset emoji grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(groupEmojis, id: \.self) { emoji in
                    Button(action: {
                        selectedEmoji = emoji
                        onEmojiSelected()
                    }) {
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(
                                selectedEmoji == emoji ?
                                Color.appPrimary.opacity(0.2) :
                                Color.gray.opacity(0.1)
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if selectedEmoji != nil {
                Button("Remove emoji") {
                    selectedEmoji = nil
                    onEmojiSelected()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .transition(.opacity.combined(with: .scale))
    }
}

struct EmojiSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEmoji: String?
    
    let initialEmoji: String?
    let onEmojiSelected: (String?) -> Void
    
    init(initialEmoji: String?, onEmojiSelected: @escaping (String?) -> Void) {
        self.initialEmoji = initialEmoji
        self.onEmojiSelected = onEmojiSelected
        self._selectedEmoji = State(initialValue: initialEmoji)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Preview section
                VStack(spacing: 16) {
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
                    
                    Text("Select Group Icon")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.top, 20)
                
                // Emoji selection
                EmojiPickerContent(selectedEmoji: $selectedEmoji) {
                    // Auto-dismiss on selection - no action needed here
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(12)
                    
                    Button("Save") {
                        onEmojiSelected(selectedEmoji)
                        dismiss()
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appPrimary)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .withAppBackground()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    EmojiSelectionSheet(initialEmoji: nil) { new in
        
    }
}
