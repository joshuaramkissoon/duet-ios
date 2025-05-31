//
//  EditableEquipmentCard.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct EditableEquipmentCard: View {
    @Binding var item: String
    let onDelete: (() -> Void)?
    let index: Int
    @FocusState.Binding var focusedField: Int?
    
    private var isFocused: Bool {
        get { focusedField == index }
        nonmutating set { 
            if newValue {
                focusedField = index
            } else if focusedField == index {
                focusedField = nil
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            TextField("Equipment item", text: $item)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($focusedField, equals: index)
                .multilineTextAlignment(.leading)
                .onSubmit {
                    focusedField = nil
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.appAccent.opacity(0.08))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isFocused {
                focusedField = index
            }
        }
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

struct AddEquipmentCard: View {
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.appPrimary)
                
                Text("Add Equipment")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.appPrimary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EditableRequiredItemsSection: View {
    @Binding var requiredItems: [String]
    @FocusState private var focusedField: Int?
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 8) {
                // Beautiful equipment grid with add button as a cell
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(requiredItems.indices, id: \.self) { index in
                        EditableEquipmentCard(
                            item: bindingForItem(at: index),
                            onDelete: deleteActionForItem(at: index),
                            index: index,
                            focusedField: $focusedField
                        )
                        .id("equipment_\(index)")
                    }
                    
                    // Add button as a grid cell
                    AddEquipmentCard(onAdd: addNewItem)
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
            .onChange(of: focusedField) { _, newValue in
                if let newValue = newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("equipment_\(newValue)", anchor: .center)
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
            requiredItems.append("")
            // Focus on the newly added item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = requiredItems.count - 1
            }
        }
    }
    
    private func bindingForItem(at index: Int) -> Binding<String> {
        return Binding<String>(
            get: {
                guard index < requiredItems.count else { return "" }
                return requiredItems[index]
            },
            set: { newValue in
                guard index < requiredItems.count else { return }
                requiredItems[index] = newValue
            }
        )
    }
    
    private func deleteActionForItem(at index: Int) -> (() -> Void)? {
        guard requiredItems.count > 1 else { return nil }
        
        return {
            withAnimation(.easeInOut(duration: 0.2)) {
                guard index < requiredItems.count else { return }
                // Clear focus if deleting focused item
                if focusedField == index {
                    focusedField = nil
                }
                requiredItems.remove(at: index)
                // Adjust focus if necessary
                if let currentFocus = focusedField, currentFocus > index {
                    focusedField = currentFocus - 1
                }
            }
        }
    }
} 