//
//  CharHelpers.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 23/05/2025.
//

import Foundation

extension Character {
  var isSimpleEmoji: Bool {
    // true if it’s a single‐scalar emoji
    unicodeScalars.count == 1 && unicodeScalars.first?.properties.isEmoji == true
  }

  var isEmoji: Bool {
    // either simple or a multi-scalar sequence
    isSimpleEmoji || unicodeScalars.contains { $0.properties.isEmojiPresentation }
  }
}
