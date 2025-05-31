//
//  DetailRow.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundColor(.gray)
                .frame(width: 16)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}