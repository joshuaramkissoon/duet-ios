//
//  HorizontalChipRow.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct ChipData {
    let icon: String
    let text: String
    let color: Color
}

struct HorizontalChipRow: View {
    let chips: [ChipData]
    
    var body: some View {
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips.indices, id: \.self) { index in
                        OverviewChip(
                            icon: chips[index].icon,
                            text: chips[index].text,
                            color: chips[index].color
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
    }
} 