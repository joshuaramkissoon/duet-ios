//
//  VisibilityHelper.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 21/05/2025.
//

import Foundation
import SwiftUI

struct VisibilityDetector: View {
    let onChange: (Bool) -> Void
    
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { report(frame: geo.frame(in: .global)) }
                .onChange(of: geo.frame(in: .global)) { oldFrame, newFrame in
                    if abs(newFrame.midY - oldFrame.midY) > 10 {
                        report(frame: newFrame)
                    }
                }
        }
    }
    
    private func report(frame: CGRect) {
        let screen = UIScreen.main.bounds
        let visibleH = screen.intersection(frame).height
        onChange(visibleH / frame.height > 0.6)
    }
}

private struct FrameKey: PreferenceKey {
    static var defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}
