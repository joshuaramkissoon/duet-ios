//
//  RecipeView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import SwiftUI

struct RecipeView: View {
    let recipeMetadata: RecipeMetadata
    let requiredItems: [String]
    
    @State private var isExpanded = false
    @State private var selectedTab: RecipeTab = .equipment
    @State private var checkedIngredients: Set<Int> = [] // Persistent checklist state
    
    enum RecipeTab: String, CaseIterable {
        case equipment = "Equipment"
        case ingredients = "Ingredients"
        case instructions = "Instructions"
        
        var icon: String {
            switch self {
            case .equipment: return "wrench.and.screwdriver"
            case .ingredients: return "leaf"
            case .instructions: return "list.number"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and expand/collapse button
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Recipe Details")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.midnightSlate)
                    
                    Spacer()
                    
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
                            if !requiredItems.isEmpty {
                                RequiredItemsSection(requiredItems: requiredItems)
                                    .padding(.horizontal, 16)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            }
                            
                        case .ingredients:
                            if let ingredients = recipeMetadata.ingredients, !ingredients.isEmpty {
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
                            
                        case .instructions:
                            if let instructions = recipeMetadata.instructions, !instructions.isEmpty {
                                RecipeInstructionsSection(instructions: instructions)
                                    .padding(.horizontal, 16)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
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
    
    private var availableTabs: [RecipeTab] {
        var tabs: [RecipeTab] = []
        
        if !requiredItems.isEmpty {
            tabs.append(.equipment)
        }
        
        if let ingredients = recipeMetadata.ingredients, !ingredients.isEmpty {
            tabs.append(.ingredients)
        }
        
        if let instructions = recipeMetadata.instructions, !instructions.isEmpty {
            tabs.append(.instructions)
        }
        
        return tabs
    }
}

struct RecipeTabSelector: View {
    @Binding var selectedTab: RecipeView.RecipeTab
    let availableTabs: [RecipeView.RecipeTab]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(availableTabs, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10, weight: .medium))
                        
                        Text(tab.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(selectedTab == tab ? .white : .appPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedTab == tab ? Color.appPrimary : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                if tab != availableTabs.last {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.appPrimary.opacity(0.08))
        )
    }
}

struct RecipeInfoSection: View {
    let recipeMetadata: RecipeMetadata
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.appPrimary)
                .padding(.top, 16)
            
            
            // Two-row layout with beautiful colors
            VStack(spacing: 8) {
                // First row: Cuisine, Difficulty, Servings
                HorizontalChipRow(chips: primaryInfoChips)
                
                // Second row: Prep time and Cook time
                HorizontalChipRow(chips: timeInfoChips)
            }
            .padding(.bottom, 12)
        }
    }
    
    private var primaryInfoChips: [ChipData] {
        var chips: [ChipData] = []
        
        if let cuisineType = recipeMetadata.cuisine_type {
            chips.append(ChipData(icon: "globe", text: cuisineType.capitalized, color: Color.appSecondary))
        }
        
        if let difficulty = recipeMetadata.difficulty_level {
            chips.append(ChipData(icon: "speedometer", text: difficulty.capitalized, color: Color.appPrimary))
        }
        
        if let servings = recipeMetadata.servings {
            chips.append(ChipData(icon: "person.2.fill", text: "Serves \(servings)", color: Color.appAccent))
        }
        
        return chips
    }
    
    private var timeInfoChips: [ChipData] {
        var chips: [ChipData] = []
        
        if let prepTime = recipeMetadata.prep_time {
            chips.append(ChipData(icon: "clock", text: "Prep: \(prepTime)", color: Color.darkPurple))
        }
        
        if let cookTime = recipeMetadata.cook_time {
            chips.append(ChipData(icon: "flame", text: "Cook: \(cookTime)", color: Color.warmOrange))
        }
        
        return chips
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
    
    RecipeView(recipeMetadata: sampleRecipeMetadata, requiredItems: ["Large pot", "Skillet", "Wooden spoon", "Strainer", "Mixing bowl", "Chef's knife"])
        .padding()
}
