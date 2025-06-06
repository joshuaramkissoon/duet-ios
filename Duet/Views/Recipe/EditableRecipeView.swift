//
//  EditableRecipeView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct EditableRecipeView: View {
    @State private var recipeMetadata: RecipeMetadata
    @State private var requiredItems: [String]
    
    @State private var isExpanded = false
    @State private var selectedTab: RecipeView.RecipeTab = .equipment
    @State private var isEditing = false
    @State private var checkedIngredients: Set<Int> = [] // Persistent checklist state
    
    let originalRecipeMetadata: RecipeMetadata
    let originalRequiredItems: [String]
    let onSave: (RecipeMetadata, [String]) -> Void
    let onCancel: () -> Void
    
    init(recipeMetadata: RecipeMetadata, requiredItems: [String], onSave: @escaping (RecipeMetadata, [String]) -> Void, onCancel: @escaping () -> Void) {
        self.originalRecipeMetadata = recipeMetadata
        self.originalRequiredItems = requiredItems
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state with current values
        self._recipeMetadata = State(initialValue: recipeMetadata)
        self._requiredItems = State(initialValue: requiredItems)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and edit/save/cancel buttons
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Recipe Details")
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
                                    .foregroundColor(.appPrimary)
                            }
                            .buttonStyle(PlainButtonStyle())
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
            if recipeMetadata.cuisine_type != nil || recipeMetadata.difficulty_level != nil ||
               recipeMetadata.servings != nil || recipeMetadata.prep_time != nil || recipeMetadata.cook_time != nil {
                RecipeInfoSection(recipeMetadata: recipeMetadata)
                    .padding(.horizontal, 16)
            }
            
            // Expandable content with tab view
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                    
                    // Tab selector
                    RecipeTabSelector(
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
                            
                        case .ingredients:
                            if let ingredients = recipeMetadata.ingredients, (!ingredients.isEmpty || isEditing) {
                                if isEditing {
                                    EditableIngredientsSection(ingredients: Binding(
                                        get: { recipeMetadata.ingredients ?? [] },
                                        set: { recipeMetadata = RecipeMetadata(
                                            cuisine_type: recipeMetadata.cuisine_type,
                                            difficulty_level: recipeMetadata.difficulty_level,
                                            servings: recipeMetadata.servings,
                                            prep_time: recipeMetadata.prep_time,
                                            cook_time: recipeMetadata.cook_time,
                                            ingredients: $0,
                                            instructions: recipeMetadata.instructions
                                        )}
                                    ))
                                    .padding(.horizontal, 16)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                } else {
                                    RecipeIngredientsSection(
                                        ingredients: ingredients,
                                        checkedIngredients: $checkedIngredients
                                    )
                                    .padding(.horizontal, 16)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                }
                            }
                            
                        case .instructions:
                            if let instructions = recipeMetadata.instructions, (!instructions.isEmpty || isEditing) {
                                if isEditing {
                                    EditableInstructionsSection(instructions: Binding(
                                        get: { recipeMetadata.instructions ?? [] },
                                        set: { recipeMetadata = RecipeMetadata(
                                            cuisine_type: recipeMetadata.cuisine_type,
                                            difficulty_level: recipeMetadata.difficulty_level,
                                            servings: recipeMetadata.servings,
                                            prep_time: recipeMetadata.prep_time,
                                            cook_time: recipeMetadata.cook_time,
                                            ingredients: recipeMetadata.ingredients,
                                            instructions: $0
                                        )}
                                    ))
                                    .padding(.horizontal, 16)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                } else {
                                    RecipeInstructionsSection(instructions: instructions)
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
        .background(Color.adaptiveCardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .onAppear {
            // Set initial tab to the first available one
            if let firstTab = availableTabs.first {
                selectedTab = firstTab
            }
        }
    }
    
    private var availableTabs: [RecipeView.RecipeTab] {
        var tabs: [RecipeView.RecipeTab] = []
        
        if !requiredItems.isEmpty || isEditing {
            tabs.append(.equipment)
        }
        
        if let ingredients = recipeMetadata.ingredients, (!ingredients.isEmpty || isEditing) {
            tabs.append(.ingredients)
        }
        
        if let instructions = recipeMetadata.instructions, (!instructions.isEmpty || isEditing) {
            tabs.append(.instructions)
        }
        
        return tabs
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
        recipeMetadata = originalRecipeMetadata
        requiredItems = originalRequiredItems
        onCancel()
    }
    
    private func saveChanges() {
        HapticFeedbacks.light()
        isEditing = false
        // Clean up empty items
        requiredItems = requiredItems.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        let updatedMetadata = RecipeMetadata(
            cuisine_type: recipeMetadata.cuisine_type,
            difficulty_level: recipeMetadata.difficulty_level,
            servings: recipeMetadata.servings,
            prep_time: recipeMetadata.prep_time,
            cook_time: recipeMetadata.cook_time,
            ingredients: recipeMetadata.ingredients?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            instructions: recipeMetadata.instructions?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        )
        
        onSave(updatedMetadata, requiredItems)
    }
}

#Preview {
    let sampleRecipeMetadata = RecipeMetadata(
        cuisine_type: "Italian-American-French Cuisine",
        difficulty_level: "Easy",
        servings: "4",
        prep_time: "15 minutes",
        cook_time: "30-80 minutes",
        ingredients: [
            "2 cups of pasta",
            "1 jar of marinara sauce", 
            "1 lb ground beef",
            "1 onion, diced",
            "2 cloves garlic, minced",
            "1 cup shredded mozzarella cheese",
            "Salt and pepper to taste",
            "2 tbsp olive oil",
            "1/4 cup fresh basil leaves",
            "1/2 cup grated parmesan cheese"
        ],
        instructions: [
            "Bring a large pot of salted water to boil and cook pasta according to package directions",
            "In a large skillet, brown the ground beef over medium-high heat, breaking it up as it cooks",
            "Add diced onion and garlic to the beef and cook until onion is translucent",
            "Stir in the marinara sauce and simmer for 10 minutes",
            "Drain the pasta and serve topped with the meat sauce and mozzarella cheese"
        ]
    )
    
    EditableRecipeView(
        recipeMetadata: sampleRecipeMetadata,
        requiredItems: ["Large pot", "Skillet", "Wooden spoon", "Strainer", "Mixing bowl", "Chef's knife"],
        onSave: { metadata, items in
            print("✅ Recipe saved with \(metadata.ingredients?.count ?? 0) ingredients and \(items.count) equipment items")
        },
        onCancel: {
            print("❌ Recipe editing cancelled")
        }
    )
    .padding()
} 
