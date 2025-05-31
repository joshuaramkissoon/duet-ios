//
//  EditableIngredients.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct EditableIngredientCard: View {
    @Binding var ingredient: String
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
            Image(systemName: "circle")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
                .frame(width: 12)
                .padding(.top, 2)
            
            TextField("Ingredient", text: $ingredient)
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
        .background(Color.gray.opacity(0.06))
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

struct AddIngredientCard: View {
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.appPrimary)
                
                Text("Add Ingredient")
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

struct EditableIngredientsSection: View {
    @Binding var ingredients: [String]
    @FocusState private var focusedField: Int?
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 8) {
                // Beautiful ingredients checklist grid with add button as a cell
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(ingredients.indices, id: \.self) { index in
                        EditableIngredientCard(
                            ingredient: bindingForIngredient(at: index),
                            onDelete: deleteActionForIngredient(at: index),
                            index: index,
                            focusedField: $focusedField
                        )
                        .id("ingredient_\(index)")
                    }
                    
                    // Add button as a grid cell
                    AddIngredientCard(onAdd: addNewIngredient)
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
            .onChange(of: focusedField) { _, newValue in
                if let newValue = newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("ingredient_\(newValue)", anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addNewIngredient() {
        HapticFeedbacks.light()
        withAnimation(.easeInOut(duration: 0.2)) {
            ingredients.append("")
            // Focus on the newly added item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = ingredients.count - 1
            }
        }
    }
    
    private func bindingForIngredient(at index: Int) -> Binding<String> {
        return Binding<String>(
            get: {
                guard index < ingredients.count else { return "" }
                return ingredients[index]
            },
            set: { newValue in
                guard index < ingredients.count else { return }
                ingredients[index] = newValue
            }
        )
    }
    
    private func deleteActionForIngredient(at index: Int) -> (() -> Void)? {
        guard ingredients.count > 1 else { return nil }
        
        return {
            withAnimation(.easeInOut(duration: 0.2)) {
                guard index < ingredients.count else { return }
                // Clear focus if deleting focused item
                if focusedField == index {
                    focusedField = nil
                }
                ingredients.remove(at: index)
                // Adjust focus if necessary
                if let currentFocus = focusedField, currentFocus > index {
                    focusedField = currentFocus - 1
                }
            }
        }
    }
} 