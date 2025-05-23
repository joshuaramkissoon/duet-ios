//
//  ShareToGroupViewModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import Foundation

@MainActor
class ShareToGroupViewModel: ObservableObject {
    /// Holds either a success or failure result after sharing
    @Published var shareResult: AlertResult? = nil
    /// Indicates an in‐flight share operation
    @Published var isLoading = false
    
    private let toastManager: ToastManager
    
    init(shareResult: AlertResult? = nil, isLoading: Bool = false, toastManager: ToastManager) {
        self.shareResult = shareResult
        self.isLoading = isLoading
        self.toastManager = toastManager
    }

    /// Share a DateIdeaResponse into the given group, using your shared GroupsViewModel.
    ///
    /// - Parameters:
    ///   - idea: the DateIdeaResponse to share
    ///   - group: the DuetGroup to share into
    ///   - groupsVM: your environment-injected GroupsViewModel
    func share(
        _ idea: DateIdeaResponse,
        to group: DuetGroup,
        using groupsVM: GroupsViewModel
    ) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await groupsVM.share(idea, to: group)
            toastManager.success("Shared \(idea.title) to \(group.name)!")
//            shareResult = .success(
//                title: "Shared!",
//                message: "“\(idea.title)” was added to \(group.name)."
//            )
        } catch {
            toastManager.error(error.localizedDescription)
//            shareResult = .failure(
//                title: "Error",
//                message: error.localizedDescription
//            )
        }
    }
}
