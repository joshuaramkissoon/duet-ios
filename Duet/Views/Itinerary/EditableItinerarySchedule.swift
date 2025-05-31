//
//  EditableItinerarySchedule.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct EditableItineraryItemCard: View {
    @Binding var item: ItineraryItem
    let onDelete: (() -> Void)?
    let index: Int
    @FocusState.Binding var focusedField: ItineraryFieldFocus?
    
    enum ItineraryField: Hashable {
        case time, title, activity, duration, location, notes
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                PulsingIndicator()
                
                VStack(alignment: .leading, spacing: 6) {
                    // Time field - matching the original design
                    TextField("Time", text: $item.time, axis: .vertical)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appPrimary)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .focused($focusedField, equals: .init(itemIndex: index, field: .time))
                        .onSubmit {
                            focusedField = nil
                        }
                    
                    // Title field - matching the original design
                    TextField("Activity title", text: $item.title, axis: .vertical)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .focused($focusedField, equals: .init(itemIndex: index, field: .title))
                        .padding(.top, 2)
                        .padding(.bottom, 1)
                        .onSubmit {
                            focusedField = nil
                        }
                    
                    // Activity description field - matching the original design
                    TextField("Activity description", text: $item.activity, axis: .vertical)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(2...4)
                        .fixedSize(horizontal: false, vertical: true)
                        .focused($focusedField, equals: .init(itemIndex: index, field: .activity))
                        .onSubmit {
                            focusedField = nil
                        }
                    
                    // Duration field - styled like DetailRow
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: "clock")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .frame(width: 16)
                        
                        TextField("Duration", text: Binding(
                            get: { item.duration ?? "" },
                            set: { item.duration = $0.isEmpty ? nil : $0 }
                        ))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($focusedField, equals: .init(itemIndex: index, field: .duration))
                        .onSubmit {
                            focusedField = nil
                        }
                    }
                    .padding(.vertical, 2)
                    .opacity(item.duration?.isEmpty == false || focusedField?.itemIndex == index && focusedField?.field == .duration ? 1.0 : 0.6)
                    
                    // Location field - styled like DetailRow
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .frame(width: 16)
                        
                        TextField("Location", text: Binding(
                            get: { item.location ?? "" },
                            set: { item.location = $0.isEmpty ? nil : $0 }
                        ))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .textFieldStyle(PlainTextFieldStyle())
                        .fixedSize(horizontal: false, vertical: true)
                        .focused($focusedField, equals: .init(itemIndex: index, field: .location))
                        .onSubmit {
                            focusedField = nil
                        }
                    }
                    .padding(.vertical, 2)
                    .opacity(item.location?.isEmpty == false || focusedField?.itemIndex == index && focusedField?.field == .location ? 1.0 : 0.6)
                    
                    // Notes field - styled like DetailRow
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: "text.quote")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .frame(width: 16)
                        
                        TextField("Notes", text: Binding(
                            get: { item.notes ?? "" },
                            set: { item.notes = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(1...3)
                        .fixedSize(horizontal: false, vertical: true)
                        .focused($focusedField, equals: .init(itemIndex: index, field: .notes))
                        .onSubmit {
                            focusedField = nil
                        }
                    }
                    .padding(.vertical, 2)
                    .opacity(item.notes?.isEmpty == false || focusedField?.itemIndex == index && focusedField?.field == .notes ? 1.0 : 0.6)
                }
                
                Spacer()
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .contextMenu {
                if let onDelete = onDelete {
                    Button(role: .destructive, action: {
                        HapticFeedbacks.light()
                        onDelete()
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}

struct ItineraryFieldFocus: Hashable {
    let itemIndex: Int
    let field: EditableItineraryItemCard.ItineraryField
}

struct AddItineraryItemButton: View {
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.appPrimary)
                
                Text("Add Activity")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.appPrimaryLightBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EditableItinerarySchedule: View {
    @Binding var itineraryItems: [ItineraryItem]
    @FocusState private var focusedField: ItineraryFieldFocus?
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                ForEach(itineraryItems.indices, id: \.self) { index in
                    EditableItineraryItemCard(
                        item: bindingForItem(at: index),
                        onDelete: deleteActionForItem(at: index),
                        index: index,
                        focusedField: $focusedField
                    )
                    .id("itinerary_\(index)")
                    
                    if index < itineraryItems.count - 1 {
                        Divider()
                            .padding(.leading, 32)
                    }
                }
                
                // Add divider before add button if there are existing items
                if !itineraryItems.isEmpty {
                    Divider()
                        .padding(.leading, 32)
                        .padding(.top, 16)
                }
                
                // Add button at the end of the list
                AddItineraryItemButton(onAdd: addNewItem)
                    .padding(.top, 16)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
            .onChange(of: focusedField) { _, newValue in
                if let newValue = newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("itinerary_\(newValue.itemIndex)", anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addNewItem() {
        HapticFeedbacks.light()
        withAnimation(.easeInOut(duration: 0.2)) {
            let newItem = ItineraryItem(
                time: "",
                title: "",
                activity: "",
                duration: nil,
                location: nil,
                notes: nil
            )
            itineraryItems.append(newItem)
            
            // Focus on the time field of the newly added item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = ItineraryFieldFocus(itemIndex: itineraryItems.count - 1, field: .time)
            }
        }
    }
    
    private func bindingForItem(at index: Int) -> Binding<ItineraryItem> {
        return Binding<ItineraryItem>(
            get: {
                guard index < itineraryItems.count else { 
                    return ItineraryItem(time: "", title: "", activity: "", duration: nil, location: nil, notes: nil)
                }
                return itineraryItems[index]
            },
            set: { newValue in
                guard index < itineraryItems.count else { return }
                itineraryItems[index] = newValue
            }
        )
    }
    
    private func deleteActionForItem(at index: Int) -> (() -> Void)? {
        guard itineraryItems.count > 1 else { return nil }
        
        return {
            withAnimation(.easeInOut(duration: 0.2)) {
                guard index < itineraryItems.count else { return }
                // Clear focus if deleting focused item
                if let currentFocus = focusedField, currentFocus.itemIndex == index {
                    focusedField = nil
                }
                itineraryItems.remove(at: index)
                // Adjust focus if necessary
                if let currentFocus = focusedField, currentFocus.itemIndex > index {
                    focusedField = ItineraryFieldFocus(
                        itemIndex: currentFocus.itemIndex - 1,
                        field: currentFocus.field
                    )
                }
            }
        }
    }
} 
