//
//  Ingredients.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct IngredientCheckCard: View {
    let ingredient: String
    let isChecked: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isChecked ? .appPrimary : .gray.opacity(0.5))
                .frame(width: 12)
                .padding(.top, 2)
            
            Text(ingredient)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isChecked ? .secondary.opacity(0.7) : .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .strikethrough(isChecked, color: .secondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isChecked ? Color.appPrimary.opacity(0.08) : Color.gray.opacity(0.06))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

struct RecipeIngredientsSection: View {
    let ingredients: [String]
    @Binding var checkedIngredients: Set<Int>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Beautiful ingredients checklist grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                    IngredientCheckCard(
                        ingredient: ingredient,
                        isChecked: checkedIngredients.contains(index)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            HapticFeedbacks.light()
                            if checkedIngredients.contains(index) {
                                checkedIngredients.remove(index)
                            } else {
                                checkedIngredients.insert(index)
                            }
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }
}