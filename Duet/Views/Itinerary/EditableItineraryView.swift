//
//  EditableItineraryView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct EditableItineraryView: View {
    @State private var itineraryItems: [ItineraryItem]
    @State private var requiredItems: [String]
    
    @State private var isExpanded = false
    @State private var selectedTab: ItineraryView.ItineraryTab = .equipment
    @State private var isEditing = false
    
    let originalItineraryItems: [ItineraryItem]
    let originalRequiredItems: [String]
    let totalDuration: String
    let location: String
    let onSave: ([ItineraryItem], [String]) -> Void
    let onCancel: () -> Void
    
    init(
        itineraryItems: [ItineraryItem],
        requiredItems: [String],
        totalDuration: String,
        location: String,
        onSave: @escaping ([ItineraryItem], [String]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.originalItineraryItems = itineraryItems
        self.originalRequiredItems = requiredItems
        self.totalDuration = totalDuration
        self.location = location
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state with current values
        self._itineraryItems = State(initialValue: itineraryItems)
        self._requiredItems = State(initialValue: requiredItems)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and edit/save/cancel buttons
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Suggested Itinerary")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.midnightSlate)
                    
                    Spacer()
                    
                    if isEditing {
                        // Cancel and Save buttons when editing
                        HStack(spacing: 8) {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    cancelEditing()
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    saveChanges()
                                }
                            }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(isValidForSaving ? .appPrimary : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!isValidForSaving)
                        }
                    } else {
                        // Edit button when not editing - using pastel purple color
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                startEditing()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text("Edit")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.darkPurple)
                                
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.darkPurple)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.lightLavender.opacity(0.5))
                            .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Expand/Collapse button
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text(isExpanded ? "Less" : "More")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.appPrimary)
                            
                            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.appPrimary)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.appPrimary.opacity(0.1))
                        .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .contentShape(Rectangle()) // Make entire header area tappable
                .onTapGesture {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
                
                Divider()
                    .padding(.horizontal, 16)
            }
            
            // Always visible overview section
            ItineraryOverviewSection(
                itineraryItems: itineraryItems,
                requiredItems: requiredItems,
                totalDuration: totalDuration,
                location: location
            )
            .padding(.horizontal, 16)
            
            // Expandable content with tab view
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                    
                    // Tab selector
                    ItineraryTabSelector(
                        selectedTab: $selectedTab,
                        availableTabs: availableTabs
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Tab content
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .equipment:
                            if !requiredItems.isEmpty || isEditing {
                                if isEditing {
                                    EditableRequiredItemsSection(requiredItems: $requiredItems)
                                        .padding(.horizontal, 16)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)
                                        ))
                                } else {
                                    RequiredItemsSection(requiredItems: requiredItems)
                                        .padding(.horizontal, 16)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)
                                        ))
                                }
                            }
                            
                        case .schedule:
                            if !itineraryItems.isEmpty || isEditing {
                                if isEditing {
                                    EditableItinerarySchedule(itineraryItems: $itineraryItems)
                                        .padding(.horizontal, 16)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)
                                        ))
                                } else {
                                    ItineraryItemsSection(itineraryItems: itineraryItems)
                                        .padding(.horizontal, 16)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)
                                        ))
                                }
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
                    .animation(.easeInOut(duration: 0.3), value: isEditing)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .onAppear {
            // Set initial tab to the first available one
            if let firstTab = availableTabs.first {
                selectedTab = firstTab
            }
        }
    }
    
    private var availableTabs: [ItineraryView.ItineraryTab] {
        var tabs: [ItineraryView.ItineraryTab] = []
        
        if !requiredItems.isEmpty || isEditing {
            tabs.append(.equipment)
        }
        
        if !itineraryItems.isEmpty || isEditing {
            tabs.append(.schedule)
        }
        
        return tabs
    }
    
    // MARK: - Validation
    
    private var isValidForSaving: Bool {
        return hasValidRequiredItems && hasValidItineraryItems
    }
    
    private var hasValidRequiredItems: Bool {
        // If no required items, it's valid
        // If has required items, all must have non-empty text after trimming
        return requiredItems.isEmpty || requiredItems.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    private var hasValidItineraryItems: Bool {
        // If no itinerary items, it's valid
        // If has itinerary items, all must have time, title, and activity filled
        return itineraryItems.isEmpty || itineraryItems.allSatisfy { item in
            !item.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func startEditing() {
        HapticFeedbacks.light()
        isEditing = true
        if !isExpanded {
            isExpanded = true
        }
    }
    
    private func cancelEditing() {
        HapticFeedbacks.light()
        isEditing = false
        // Reset to original values
        itineraryItems = originalItineraryItems
        requiredItems = originalRequiredItems
        onCancel()
    }
    
    private func saveChanges() {
        HapticFeedbacks.light()
        isEditing = false
        
        // Clean up empty items
        let cleanedRequiredItems = requiredItems.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let cleanedItineraryItems = itineraryItems.filter { item in
            !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        onSave(cleanedItineraryItems, cleanedRequiredItems)
    }
}

#Preview {
    let sampleItinerary = [
        ItineraryItem(
            time: "Day 1 - Morning",
            title: "Arrival & Setup - Maracas Beach at Sunrise",
            activity: "Arrive at Central Park and find a good spot near the lake",
            duration: "30 minutes",
            location: "East entrance",
            notes: "Look for shady areas near the lake"
        ),
        ItineraryItem(
            time: "Late Afternoon: This is a long time from now",
            title: "Picnic Time",
            activity: "Set up your picnic and enjoy the sunset views with your partner",
            duration: "2 hours",
            location: "Sheep Meadow",
            notes: "Best views are from the west side"
        ),
        ItineraryItem(
            time: "Evening",
            title: "Romantic Walk",
            activity: "Pack up and take a romantic night walk around the illuminated paths",
            duration: "1 hour",
            location: "Around the park",
            notes: nil
        )
    ]
    
    EditableItineraryView(
        itineraryItems: sampleItinerary,
        requiredItems: ["Picnic blanket", "Wine and glasses", "Cheese and crackers", "Portable speaker"],
        totalDuration: "3.5 hours",
        location: "Central Park, NYC",
        onSave: { items, equipment in
            print("✅ Itinerary saved with \(items.count) activities and \(equipment.count) equipment items")
        },
        onCancel: {
            print("❌ Itinerary editing cancelled")
        }
    )
    .padding()
} 
