//
//  ToastManager.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 21/05/2025.
//

import Foundation

/// A single source-of-truth for toasts
final class ToastManager: ObservableObject {
    @Published var state: ToastState?       // nil = hidden
    
    // Convenience helpers (optional)
    func success(_ msg: String, auto: TimeInterval = 2) {
        state = .success(message: msg)      // ToastState already contains the delay
    }
    func error(_ msg: String, auto: TimeInterval = 2) {
        state = .error(message: msg)
    }
    func loading(_ msg: String) {
        state = .loading(message: msg)
    }
    func dismiss() {
        state = nil
    }
}
