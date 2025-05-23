//
//  StringHelpers.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 23/05/2025.
//

import Foundation

extension String {
    var djb2hash: UInt {
        let unicodeScalars = self.unicodeScalars.map { $0.value }
        return unicodeScalars.reduce(5381) {
            ($0 << 5) &+ $0 &+ UInt($1)
        }
    }
}
