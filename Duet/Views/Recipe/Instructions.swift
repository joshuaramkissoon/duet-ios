//
//  Instructions.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct RecipeInstructionsSection: View {
    let instructions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.appPrimary.opacity(0.15))
                                .frame(width: 30, height: 30)
                            
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.appPrimary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(instruction)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    if index < instructions.count - 1 {
                        Divider()
                            .padding(.leading, 30)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }
}