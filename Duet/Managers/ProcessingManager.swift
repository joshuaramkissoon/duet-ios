import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import SwiftUI

class ProcessingManager: ObservableObject {
    @Published var userProcessingJobs: [ProcessingJob] = []
    @Published var groupProcessingJobs: [String: [ProcessingJob]] = [:] // groupId -> jobs
    
    // Notification setting from user preferences
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    private let db = Firestore.firestore()
    private var userListener: ListenerRegistration?
    private var groupListeners: [String: ListenerRegistration] = [:]
    private var toast: ToastManager
    private weak var activityVM: ActivityHistoryViewModel?
    private weak var authViewModel: AuthenticationViewModel?
    private weak var myLibraryVM: MyLibraryViewModel?
    private let creditService = CreditService.shared
    private let notificationManager = NotificationManager.shared
    
    init(toast: ToastManager, activityVM: ActivityHistoryViewModel? = nil) {
        self.toast = toast
        self.activityVM = activityVM
    }
    
    // Method to update the toast reference (useful for environment objects)
    func updateToast(_ newToast: ToastManager) {
        self.toast = newToast
    }
    
    // Inject / update the shared ActivityHistoryViewModel so completed jobs can be inserted immediately
    func updateActivityVM(_ vm: ActivityHistoryViewModel) {
        self.activityVM = vm
    }
    
    // Inject / update the AuthenticationViewModel for user data refreshes
    func updateAuthViewModel(_ vm: AuthenticationViewModel) {
        self.authViewModel = vm
    }
    
    // Inject / update the MyLibraryViewModel for idea count updates
    func updateMyLibraryViewModel(_ vm: MyLibraryViewModel) {
        self.myLibraryVM = vm
    }
    
    // MARK: - User Processing Jobs
    
    func startListeningToUserJobs() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return 
        }
        
        userListener = db.collection("processing_status")
            .whereField("user_id", isEqualTo: userId)
            // This will include both user-only jobs (group_id == null) and group jobs (group_id != null)
            // Temporarily remove ordering to avoid index requirement
            // .order(by: "created_at", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    return
                }
                
                guard let snapshot = snapshot else {
                    return 
                }
                
                let jobs = snapshot.documents.compactMap { doc -> ProcessingJob? in
                    do {
                        return try doc.data(as: ProcessingJob.self)
                    } catch {
                        return nil
                    }
                }
                
                // Sort in memory by created_at descending
                let sortedJobs = jobs.sorted { job1, job2 in
                    guard let date1 = job1.createdAt, let date2 = job2.createdAt else {
                        return false
                    }
                    return date1 > date2
                }
                
                Task { @MainActor in
                    let oldUserJobsCount = self.userProcessingJobs.count
                    self.userProcessingJobs = sortedJobs
                    
                    // Also update group processing jobs to keep them in sync
                    self.updateGroupJobsFromUserJobs(sortedJobs)
                    
                    // Handle completed jobs
                    for job in sortedJobs where job.isCompleted {
                        self.handleCompletedJob(job)
                    }
                    
                    // Handle failed jobs
                    for job in sortedJobs where job.isFailed {
                        self.handleFailedJob(job)
                    }
                }
            }
    }
    
    @MainActor
    private func updateGroupJobsFromUserJobs(_ userJobs: [ProcessingJob]) {
        // Update group processing jobs based on user jobs to keep them in sync
        var newGroupJobs: [String: [ProcessingJob]] = [:]
        
        for job in userJobs {
            if let groupId = job.groupId {
                if newGroupJobs[groupId] == nil {
                    newGroupJobs[groupId] = []
                }
                newGroupJobs[groupId]?.append(job)
            }
        }
        
        // Track if we made any changes to trigger UI update
        var didUpdateAnyGroup = false
        
        // Update ALL groups that have jobs, not just the ones we're tracking
        // This ensures jobs are available when GroupDetailView starts tracking
        for (groupId, jobs) in newGroupJobs {
            let oldCount = groupProcessingJobs[groupId]?.count ?? 0
            groupProcessingJobs[groupId] = jobs
            let newCount = jobs.count
            didUpdateAnyGroup = true
        }
        
        // Also clear any tracked groups that no longer have jobs
        for groupId in groupListeners.keys {
            if newGroupJobs[groupId] == nil {
                let oldCount = groupProcessingJobs[groupId]?.count ?? 0
                groupProcessingJobs[groupId] = []
                didUpdateAnyGroup = true
            }
        }
        
        // Explicitly trigger UI update if we made changes
        if didUpdateAnyGroup {
            objectWillChange.send()
        }
    }
    
    nonisolated func stopListeningToUserJobs() {
        Task { @MainActor in
            userListener?.remove()
            userListener = nil
        }
    }
    
    // MARK: - Group Processing Jobs
    
    func startListeningToGroupJobs(groupId: String) {
        guard !groupId.isEmpty else { return }
        
        // Don't create duplicate listeners
        if groupListeners[groupId] != nil {
            return 
        }
        
        // Initialize the group jobs array if it doesn't exist
        if groupProcessingJobs[groupId] == nil {
            groupProcessingJobs[groupId] = []
        }
        
        // Just mark that we're tracking this group - no actual Firestore listener needed
        // The user listener will populate the data and updateGroupJobsFromUserJobs will sync it
        groupListeners[groupId] = nil // Placeholder to track we're monitoring this group
        
        // Immediately sync any existing jobs for this group from user jobs
        Task { @MainActor in
            updateGroupJobsFromUserJobs(userProcessingJobs)
            
            // Debug: Check if jobs were found
            let jobCount = groupProcessingJobs[groupId]?.count ?? 0
            
            // Explicitly trigger UI update
            if jobCount > 0 {
                objectWillChange.send()
            }
        }
    }
    
    nonisolated func stopListeningToGroupJobs(groupId: String) {
        // No actual listener to remove, just stop tracking this group
        Task { @MainActor in
            groupListeners.removeValue(forKey: groupId)
            groupProcessingJobs.removeValue(forKey: groupId)
        }
    }
    
    nonisolated func stopAllGroupListeners() {
        // No actual listeners to remove, just clear tracking
        Task { @MainActor in
            groupListeners.removeAll()
            groupProcessingJobs.removeAll()
        }
    }
    
    // MARK: - API Calls
    
    func processVideo(url: String) async throws -> ProcessingResponse {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProcessingError.userNotAuthenticated
        }
        
        // Pre-emptive credit check with UI handling
        if !creditService.checkCreditsForAction(creditsRequired: 1) {
            throw ProcessingError.insufficientCredits
        }
        
        // Read default visibility setting from UserDefaults
        let defaultPublishIdeas = UserDefaults.standard.bool(forKey: "defaultPublishIdeas")
        
        let endpoint = NetworkClient.shared.baseUrl + "/summarise"
        let body = ProcessingRequest(url: url, userId: userId, isPublic: defaultPublishIdeas)
        
        do {
            let response: ProcessingResponse = try await NetworkClient.shared.postJSON(url: endpoint, body: body)
            // Optimistically deduct credits on successful request
            await MainActor.run {
                creditService.deductCredits(1)
            }
            return response
        } catch {
            // Handle credit errors
            if creditService.handleInsufficientCreditsError(error) {
                throw ProcessingError.insufficientCredits
            }
            throw error
        }
    }
    
    func processVideoForGroup(url: String, groupId: String) async throws -> ProcessingResponse {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProcessingError.userNotAuthenticated
        }
        
        // Pre-emptive credit check with UI handling
        if !creditService.checkCreditsForAction(creditsRequired: 1) {
            throw ProcessingError.insufficientCredits
        }
        
        // For group ideas, always default to false (private) since groups are not public for now
        let defaultPublishIdeas = false
        
        let endpoint = NetworkClient.shared.baseUrl + "/groups/add-url"
        let body = GroupProcessingRequest(url: url, userId: userId, groupId: groupId, isPublic: defaultPublishIdeas)
        
        do {
            let response: ProcessingResponse = try await NetworkClient.shared.postJSON(url: endpoint, body: body)
            // Optimistically deduct credits on successful request
            await MainActor.run {
                creditService.deductCredits(1)
            }
            return response
        } catch {
            // Handle credit errors
            if creditService.handleInsufficientCreditsError(error) {
                throw ProcessingError.insufficientCredits
            }
            throw error
        }
    }
    
    func retryProcessing(job: ProcessingJob) async throws {
        if let groupId = job.groupId {
            _ = try await processVideoForGroup(url: job.url, groupId: groupId)
        } else {
            _ = try await processVideo(url: job.url)
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func handleCompletedJob(_ job: ProcessingJob) {
        // Only show toast for recently completed jobs (within last 10 seconds)
        guard let updatedAt = job.updatedAt,
              Date().timeIntervalSince(updatedAt) < 10 else { return }
        
        if let resultId = job.resultId {
            // Fetch the actual result and show success
            Task {
                do {
                    let result = try await NetworkClient.shared.getActivity(id: resultId)
                    await MainActor.run {
                        toast.success("✨ \(result.summary.title)")
                        
                        // Send local notification if notifications are enabled
                        if notificationsEnabled {
                            notificationManager.scheduleIdeaCompletedNotification(
                                ideaId: result.id,
                                ideaTitle: result.summary.title,
                                groupId: job.groupId
                            )
                        }
                        
                        // Refresh UI immediately by inserting into local cache.
                        if job.groupId == nil {
                            if let vm = activityVM {
                                if !vm.activities.contains(where: { $0.id == result.id }) {
                                    vm.activities.insert(result, at: 0)
                                    // Also kick off a refresh in background for full sync
                                    vm.loadActivities()
                                }
                            }
                            
                            // Update MyLibraryViewModel for personal ideas to track idea count
                            if let libraryVM = myLibraryVM {
                                libraryVM.addNewIdea(result)
                                print("📚 Updated MyLibraryViewModel with new idea - New total: \(libraryVM.totalUserIdeas)")
                            }
                        }
                        
                        // Force refresh current user data to update player level after creating new idea
                        // This ensures the level pill and roadmap reflect any level changes immediately
                        if let authVM = authViewModel {
                            authVM.forceRefreshCurrentUser()
                        }
                    }
                } catch {
                    await MainActor.run {
                        toast.success("Video processed successfully!")
                        
                        // Send notification even if we couldn't fetch the result details
                        // Use job URL or a generic title
                        let ideaTitle = "New Idea"
                        if notificationsEnabled {
                            notificationManager.scheduleIdeaCompletedNotification(
                                ideaId: job.resultId ?? UUID().uuidString,
                                ideaTitle: ideaTitle,
                                groupId: job.groupId
                            )
                        }
                        
                        // Still refresh user data even if we couldn't fetch the result
                        if let authVM = authViewModel {
                            authVM.forceRefreshCurrentUser()
                        }
                    }
                }
            }
        } else {
            toast.success("Video processed successfully!")
            
            // Send notification even without result details
            let ideaTitle = "New Idea"
            if notificationsEnabled {
                notificationManager.scheduleIdeaCompletedNotification(
                    ideaId: UUID().uuidString,
                    ideaTitle: ideaTitle,
                    groupId: job.groupId
                )
            }
            
            // Refresh user data for potential level updates
            if let authVM = authViewModel {
                authVM.forceRefreshCurrentUser()
            }
        }
    }
    
    @MainActor
    private func handleFailedJob(_ job: ProcessingJob) {
        // Only show toast for recently failed jobs (within last 10 seconds)
        guard let updatedAt = job.updatedAt,
              Date().timeIntervalSince(updatedAt) < 10 else { return }
        
        if let errorMessage = job.errorMessage, !errorMessage.isEmpty {
            toast.error(errorMessage)
        } else {
            toast.error("Failed to process video")
        }
    }
    
    func getActiveUserJobs() -> [ProcessingJob] {
        // Only return jobs that don't have a group_id (user-specific jobs)
        let activeUserJobs = userProcessingJobs.filter { $0.isActive && $0.groupId == nil }
        return activeUserJobs
    }
    
    func getActiveGroupJobs(for groupId: String) -> [ProcessingJob] {
        let activeGroupJobs = groupProcessingJobs[groupId]?.filter { $0.isActive } ?? []
        return activeGroupJobs
    }
    
    func getAllUserJobs() -> [ProcessingJob] {
        // Only return jobs that don't have a group_id (user-specific jobs)
        let allUserJobs = userProcessingJobs.filter { $0.groupId == nil }
        return allUserJobs
    }
    
    func getAllGroupJobs(for groupId: String) -> [ProcessingJob] {
        let allGroupJobs = groupProcessingJobs[groupId] ?? []
        return allGroupJobs
    }
    
    func removeProcessingJob(_ job: ProcessingJob) async throws {
        guard let jobId = job.id else {
            throw ProcessingError.invalidURL // Reusing existing error type
        }
        
        
        do {
            try await db.collection("processing_status").document(jobId).delete()
            
            // The Firestore listener should automatically update the arrays, but we also
            // prune *local* caches immediately so the UI refreshes without delay.
            await MainActor.run {
                // Remove from user jobs cache
                self.userProcessingJobs.removeAll { $0.id == jobId }

                // Remove from group cache (if any)
                if let gid = job.groupId {
                    if var list = self.groupProcessingJobs[gid] {
                        list.removeAll { $0.id == jobId }
                        if list.isEmpty {
                            self.groupProcessingJobs.removeValue(forKey: gid)
                        } else {
                            self.groupProcessingJobs[gid] = list
                        }
                    }
                }

                // Notify views that data changed so they can re-render immediately
                self.objectWillChange.send()
            }
        } catch {
            throw ProcessingError.networkError("Failed to remove processing job")
        }
    }
    
    deinit {
        // Remove user listener
        userListener?.remove()
        userListener = nil
        
        // Remove all group listeners (though they should be nil now)
        for (groupId, listener) in groupListeners {
            listener.remove()
        }
        groupListeners.removeAll()
    }
}

// MARK: - Request Models

struct ProcessingRequest: Codable {
    let url: String
    let userId: String
    let isPublic: Bool
    
    enum CodingKeys: String, CodingKey {
        case url
        case userId = "user_id"
        case isPublic = "public"
    }
}

struct GroupProcessingRequest: Codable {
    let url: String
    let userId: String
    let groupId: String
    let isPublic: Bool
    
    enum CodingKeys: String, CodingKey {
        case url
        case userId = "user_id"
        case groupId = "group_id"
        case isPublic = "public"
    }
}

// MARK: - Errors

enum ProcessingError: LocalizedError {
    case userNotAuthenticated
    case invalidURL
    case networkError(String)
    case insufficientCredits
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "You must be signed in to process videos"
        case .invalidURL:
            return "Please enter a valid URL"
        case .networkError(let message):
            return message
        case .insufficientCredits:
            return "Not enough credits to process video"
        }
    }
} 
