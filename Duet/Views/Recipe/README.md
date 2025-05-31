# Editable Recipe System

This document describes the editable recipe view system that allows users to seamlessly edit recipe equipment, ingredients, and instructions.

## Components Overview

### Core Components

1. **`EditableRecipeView`** - Main editable recipe view with the same layout as `RecipeView`
2. **`EditableEquipmentCard`** - Editable equipment/required items with context menu delete
3. **`EditableIngredientCard`** - Editable ingredient cards for the ingredients section
4. **`EditableInstructionCard`** - Editable instruction steps with numbered format
5. **`RecipeService`** - Service for updating recipe data in Firestore or backend

### UI Features

- **Seamless Edit Mode**: Tap "Edit" to enter editing mode, maintaining the same visual design
- **Context Menu Delete**: Long press any item to delete it (equipment, ingredients, instructions)
- **Add Buttons**: Clean add buttons for each section when in editing mode
- **Save/Cancel**: Clear save and cancel buttons when editing
- **Auto-expand**: Automatically expands when entering edit mode
- **Haptic Feedback**: Tactile feedback for all interactions

## Usage

### Basic Integration

```swift
import SwiftUI

struct MyRecipeView: View {
    let recipe: RecipeMetadata
    let equipment: [String]
    let ideaId: String
    let groupId: String? // nil for personal, groupId for shared
    
    var body: some View {
        EditableRecipeView(
            recipeMetadata: recipe,
            requiredItems: equipment,
            onSave: { updatedRecipe, updatedEquipment in
                // Handle save with RecipeService
                RecipeService.shared.updateRecipeMetadata(
                    ideaId: ideaId,
                    groupId: groupId,
                    recipeMetadata: updatedRecipe,
                    requiredItems: updatedEquipment
                ) { error in
                    if let error = error {
                        print("Save failed: \(error)")
                    } else {
                        print("Recipe saved successfully!")
                    }
                }
            },
            onCancel: {
                print("Edit cancelled")
            }
        )
    }
}
```

### Advanced Usage with Loading States

See `RecipeViewExample.swift` for a complete implementation including:
- Loading states during save operations
- Error handling and display
- Sheet presentation for editing
- Both callback and async/await patterns

## Data Storage

### Group Ideas (Firestore)
- Stored in: `groups/{groupId}/ideas/{ideaId}`
- Updates: `dateIdea.recipe_metadata.*` and `dateIdea.required_items`

### Personal Ideas (Backend)
- Endpoint: `PATCH /ideas/{ideaId}`
- Body format:
```json
{
  "recipe_metadata": {
    "ingredients": ["item1", "item2"],
    "instructions": ["step1", "step2"],
    // ... other metadata fields
  },
  "required_items": ["equipment1", "equipment2"]
}
```

## File Structure

```
Views/Recipe/
├── RecipeView.swift              # Original read-only recipe view
├── EditableRecipeView.swift      # Main editable recipe view
├── EditableIngredients.swift     # Editable ingredients components
├── EditableInstructions.swift    # Editable instructions components
├── RecipeViewExample.swift       # Usage examples
├── Ingredients.swift             # Original ingredients components
└── Instructions.swift            # Original instructions components

Views/Components/
└── EditableEquipmentCard.swift   # Editable equipment components

Services/
└── RecipeService.swift           # Recipe update service
```

## Key Features

### 1. Context Menu Delete
- Long press any editable item to see delete option
- Prevents accidental deletions
- Maintains clean UI without visible delete buttons

### 2. Smart Tab Management
- Tabs only show when they have content OR when in editing mode
- Seamless switching between view and edit modes
- Maintains selected tab state

### 3. Data Validation
- Removes empty items on save
- Trims whitespace from all text fields
- Maintains data integrity

### 4. Responsive Design
- 2-column grid layout for equipment and ingredients
- Expandable text fields for instructions
- Maintains original visual design when not editing

## Animation & UX

- **Spring animations** for mode transitions
- **Asymmetric transitions** for tab content
- **Haptic feedback** for all interactions
- **Focus management** for text fields
- **Auto-submit** on return key

## Error Handling

The `RecipeService` provides comprehensive error handling for:
- Network connectivity issues
- Firestore permission errors
- Invalid data format
- Backend API errors

See `RecipeViewExample.swift` for implementation patterns.

## Testing

Use the provided preview data in each component file to test:
- Edit mode transitions
- Add/delete operations
- Save/cancel functionality
- Context menu interactions

## Future Enhancements

- [ ] Drag and drop reordering for instructions
- [ ] Rich text support for ingredients/instructions
- [ ] Photo attachments for recipe steps
- [ ] Recipe sharing and collaboration features
- [ ] Offline editing with sync capabilities 