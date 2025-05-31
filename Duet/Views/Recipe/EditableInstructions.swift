//
//  EditableInstructions.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct EditableInstructionCard: View {
    let stepNumber: Int
    @Binding var instruction: String
    let onDelete: (() -> Void)?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.15))
                    .frame(width: 30, height: 30)
                
                Text("\(stepNumber)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.appPrimary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                TextField("Instruction step", text: $instruction, axis: .vertical)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isFocused)
                    .lineLimit(3...10)
                    .onSubmit {
                        isFocused = false
                    }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isFocused {
                isFocused = true
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

struct AddInstructionButton: View {
    let stepNumber: Int
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.15))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "plus")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.appPrimary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Step")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EditableInstructionsSection: View {
    @Binding var instructions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(instructions.indices, id: \.self) { index in
                    EditableInstructionCard(
                        stepNumber: index + 1,
                        instruction: bindingForInstruction(at: index),
                        onDelete: deleteActionForInstruction(at: index)
                    )
                    
                    if index < instructions.count - 1 {
                        Divider()
                            .padding(.leading, 30)
                    }
                }
                
                // Add divider before add button if there are existing instructions
                if !instructions.isEmpty {
                    Divider()
                        .padding(.leading, 30)
                }
                
                // Add button at the end of the list
                AddInstructionButton(
                    stepNumber: instructions.count + 1,
                    onAdd: addNewStep
                )
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - Helper Methods
    
    private func addNewStep() {
        HapticFeedbacks.light()
        withAnimation(.easeInOut(duration: 0.2)) {
            instructions.append("")
        }
    }
    
    private func bindingForInstruction(at index: Int) -> Binding<String> {
        return Binding<String>(
            get: {
                guard index < instructions.count else { return "" }
                return instructions[index]
            },
            set: { newValue in
                guard index < instructions.count else { return }
                instructions[index] = newValue
            }
        )
    }
    
    private func deleteActionForInstruction(at index: Int) -> (() -> Void)? {
        guard instructions.count > 1 else { return nil }
        
        return {
            withAnimation(.easeInOut(duration: 0.2)) {
                guard index < instructions.count else { return }
                instructions.remove(at: index)
            }
        }
    }
} 