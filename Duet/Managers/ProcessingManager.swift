import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class ProcessingManager: ObservableObject {
    @Published var userProcessingJobs: [ProcessingJob] = []
    @Published var groupProcessingJobs: [String: [ProcessingJob]] = [:] // groupId -> jobs
    
    private let db = Firestore.firestore()
    private var userListener: ListenerRegistration?
    private var groupListeners: [String: ListenerRegistration] = [:]
    private var toast: ToastManager
    private weak var activityVM: ActivityHistoryViewModel?
    
    init(toast: ToastManager, activityVM: ActivityHistoryViewModel? = nil) {
        self.toast = toast
        self.activityVM = activityVM
        print("🆕 ProcessingManager created - \(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    // Method to update the toast reference (useful for environment objects)
    func updateToast(_ newToast: ToastManager) {
        self.toast = newToast
    }
    
    // Inject / update the shared ActivityHistoryViewModel so completed jobs can be inserted immediately
    func updateActivityVM(_ vm: ActivityHistoryViewModel) {
        self.activityVM = vm
    }
    
    // MARK: - User Processing Jobs
    
    func startListeningToUserJobs() {
        guard let userId = Auth.auth().currentUser?.uid else { 
            print("❌ No authenticated user for processing jobs listener")
            return 
        }
        
        print("🔄 Starting to listen for processing jobs for user: \(userId)")
        
        userListener = db.collection("processing_status")
            .whereField("user_id", isEqualTo: userId)
            // This will include both user-only jobs (group_id == null) and group jobs (group_id != null)
            // Temporarily remove ordering to avoid index requirement
            // .order(by: "created_at", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ User processing listener error: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else { 
                    print("❌ No snapshot in processing_status listener")
                    return 
                }
                
                print("📄 Received snapshot with \(snapshot.documents.count) documents")
                print("📄 Document changes: \(snapshot.documentChanges.count)")
                
                // Debug document changes
                for change in snapshot.documentChanges {
                    switch change.type {
                    case .added:
                        print("📄 Document added: \(change.document.documentID)")
                    case .modified:
                        print("📄 Document modified: \(change.document.documentID)")
                    case .removed:
                        print("📄 Document removed: \(change.document.documentID)")
                    }
                }
                
                let jobs = snapshot.documents.compactMap { doc -> ProcessingJob? in
                    do {
                        let job = try doc.data(as: ProcessingJob.self)
                        print("✅ Parsed user job: \(job.id ?? "unknown") - \(job.status) - \(job.url) - group: \(job.groupId ?? "none")")
                        print("📝 Progress message: '\(job.progressMessage)' (isEmpty: \(job.progressMessage.isEmpty))")
                        return job
                    } catch {
                        print("❌ Failed to parse processing job: \(error)")
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
                
                print("🎯 Total parsed user jobs (including group jobs): \(sortedJobs.count)")
                
                Task { @MainActor in
                    let oldUserJobsCount = self.userProcessingJobs.count
                    self.userProcessingJobs = sortedJobs
                    print("📱 Updated userProcessingJobs: \(oldUserJobsCount) -> \(self.userProcessingJobs.count)")
                    
                    // Debug: Show breakdown of jobs
                    let userOnlyJobs = sortedJobs.filter { $0.groupId == nil }
                    let groupJobs = sortedJobs.filter { $0.groupId != nil }
                    print("📊 Job breakdown - User-only: \(userOnlyJobs.count), Group jobs: \(groupJobs.count)")
                    
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
        print("🔄 updateGroupJobsFromUserJobs called with \(userJobs.count) user jobs")
        print("🔄 Currently tracking groups: \(Array(groupListeners.keys))")
        
        // Update group processing jobs based on user jobs to keep them in sync
        var newGroupJobs: [String: [ProcessingJob]] = [:]
        
        for job in userJobs {
            if let groupId = job.groupId {
                if newGroupJobs[groupId] == nil {
                    newGroupJobs[groupId] = []
                }
                newGroupJobs[groupId]?.append(job)
                print("🔄 Found job for group \(groupId): \(job.id ?? "unknown") - \(job.status)")
            }
        }
        
        print("🔄 Found jobs for groups: \(newGroupJobs.keys.sorted())")
        
        // Track if we made any changes to trigger UI update
        var didUpdateAnyGroup = false
        
        // Update ALL groups that have jobs, not just the ones we're tracking
        // This ensures jobs are available when GroupDetailView starts tracking
        for (groupId, jobs) in newGroupJobs {
            let oldCount = groupProcessingJobs[groupId]?.count ?? 0
            groupProcessingJobs[groupId] = jobs
            let newCount = jobs.count
            print("📱 Synced group processing jobs for \(groupId): \(oldCount) -> \(newCount) jobs")
            print("📱   Jobs synced: \(jobs.map { "\($0.id ?? "unknown")-\($0.status)" }.joined(separator: ", "))")
            didUpdateAnyGroup = true
        }
        
        // Also clear any tracked groups that no longer have jobs
        for groupId in groupListeners.keys {
            if newGroupJobs[groupId] == nil {
                let oldCount = groupProcessingJobs[groupId]?.count ?? 0
                groupProcessingJobs[groupId] = []
                print("📱 Cleared group processing jobs for \(groupId): \(oldCount) -> 0 jobs")
                didUpdateAnyGroup = true
            }
        }
        
        // Explicitly trigger UI update if we made changes
        if didUpdateAnyGroup {
            print("🔄 Triggering objectWillChange for group processing jobs update")
            objectWillChange.send()
        }
    }
    
    nonisolated func stopListeningToUserJobs() {
        Task { @MainActor in
            userListener?.remove()
            userListener = nil
            print("🛑 Stopped user processing jobs listener")
        }
    }
    
    // MARK: - Group Processing Jobs
    
    func startListeningToGroupJobs(groupId: String) {
        guard !groupId.isEmpty else { return }
        
        // Don't create duplicate listeners
        if groupListeners[groupId] != nil { 
            print("🔄 Already tracking group processing jobs for group: \(groupId)")
            return 
        }
        
        print("🔄 Registering group processing jobs tracking for group: \(groupId)")
        
        // Initialize the group jobs array if it doesn't exist
        if groupProcessingJobs[groupId] == nil {
            groupProcessingJobs[groupId] = []
        }
        
        // Just mark that we're tracking this group - no actual Firestore listener needed
        // The user listener will populate the data and updateGroupJobsFromUserJobs will sync it
        groupListeners[groupId] = nil // Placeholder to track we're monitoring this group
        
        print("✅ Started tracking group processing jobs for group: \(groupId)")
        
        // Immediately sync any existing jobs for this group from user jobs
        Task { @MainActor in
            print("🔄 Syncing existing jobs for newly tracked group: \(groupId)")
            updateGroupJobsFromUserJobs(userProcessingJobs)
            
            // Debug: Check if jobs were found
            let jobCount = groupProcessingJobs[groupId]?.count ?? 0
            print("📊 After sync, group \(groupId) has \(jobCount) jobs")
            
            // Explicitly trigger UI update
            if jobCount > 0 {
                print("🔄 Triggering objectWillChange for newly tracked group with jobs")
                objectWillChange.send()
            }
        }
    }
    
    nonisolated func stopListeningToGroupJobs(groupId: String) {
        // No actual listener to remove, just stop tracking this group
        Task { @MainActor in
            groupListeners.removeValue(forKey: groupId)
            groupProcessingJobs.removeValue(forKey: groupId)
            print("🛑 Stopped tracking group processing jobs for group: \(groupId)")
        }
    }
    
    nonisolated func stopAllGroupListeners() {
        // No actual listeners to remove, just clear tracking
        Task { @MainActor in
            groupListeners.removeAll()
            groupProcessingJobs.removeAll()
            print("🛑 Stopped tracking all group processing jobs")
        }
    }
    
    // MARK: - API Calls
    
    func processVideo(url: String) async throws -> ProcessingResponse {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProcessingError.userNotAuthenticated
        }
        
        let endpoint = NetworkClient.shared.baseUrl + "/summarise"
        let body = ProcessingRequest(url: url, userId: userId)
        
        return try await NetworkClient.shared.postJSON(url: endpoint, body: body)
    }
    
    func processVideoForGroup(url: String, groupId: String) async throws -> ProcessingResponse {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ProcessingError.userNotAuthenticated
        }
        
        let endpoint = NetworkClient.shared.baseUrl + "/groups/add-url"
        let body = GroupProcessingRequest(url: url, userId: userId, groupId: groupId)
        
        return try await NetworkClient.shared.postJSON(url: endpoint, body: body)
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
                        
                        // Refresh UI immediately by inserting into local cache.
                        if job.groupId == nil {
                            if let vm = activityVM {
                                if !vm.activities.contains(where: { $0.id == result.id }) {
                                    vm.activities.insert(result, at: 0)
                                    // Also kick off a refresh in background for full sync
                                    vm.loadActivities()
                                }
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        toast.success("Video processed successfully!")
                    }
                }
            }
        } else {
            toast.success("Video processed successfully!")
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
        print("🔍 getActiveUserJobs() returning \(activeUserJobs.count) jobs from \(userProcessingJobs.count) total user jobs")
        return activeUserJobs
    }
    
    func getActiveGroupJobs(for groupId: String) -> [ProcessingJob] {
        let activeGroupJobs = groupProcessingJobs[groupId]?.filter { $0.isActive } ?? []
        print("🔍 getActiveGroupJobs(\(groupId)) returning \(activeGroupJobs.count) jobs from \(groupProcessingJobs[groupId]?.count ?? 0) total group jobs")
        return activeGroupJobs
    }
    
    func getAllUserJobs() -> [ProcessingJob] {
        // Only return jobs that don't have a group_id (user-specific jobs)
        let allUserJobs = userProcessingJobs.filter { $0.groupId == nil }
        print("🔍 getAllUserJobs() returning \(allUserJobs.count) jobs from \(userProcessingJobs.count) total user jobs")
        return allUserJobs
    }
    
    func getAllGroupJobs(for groupId: String) -> [ProcessingJob] {
        let allGroupJobs = groupProcessingJobs[groupId] ?? []
        print("🔍 getAllGroupJobs(\(groupId)) returning \(allGroupJobs.count) jobs")
        print("🔍 groupProcessingJobs keys: \(Array(groupProcessingJobs.keys))")
        print("🔍 groupListeners keys: \(Array(groupListeners.keys))")
        if let jobs = groupProcessingJobs[groupId] {
            for job in jobs {
                print("🔍   - Job: \(job.id ?? "unknown") - \(job.status)")
            }
        }
        return allGroupJobs
    }
    
    func removeProcessingJob(_ job: ProcessingJob) async throws {
        guard let jobId = job.id else {
            throw ProcessingError.invalidURL // Reusing existing error type
        }
        
        print("🗑️ Attempting to remove processing job: \(jobId)")
        
        do {
            try await db.collection("processing_status").document(jobId).delete()
            print("✅ Successfully removed processing job from Firestore: \(jobId)")
            
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

                print("🔄 Locally pruned job \(jobId). Remaining user jobs: \(self.userProcessingJobs.count)")

                // Notify views that data changed so they can re-render immediately
                self.objectWillChange.send()
            }
        } catch {
            print("❌ Failed to remove processing job: \(error)")
            throw ProcessingError.networkError("Failed to remove processing job")
        }
    }
    
    deinit {
        print("🗑️ ProcessingManager deinit called")
        
        // Remove user listener
        userListener?.remove()
        userListener = nil
        
        // Remove all group listeners (though they should be nil now)
        for (groupId, listener) in groupListeners {
            listener.remove()
            print("🗑️ Removed listener for group: \(groupId)")
        }
        groupListeners.removeAll()
        
        print("🗑️ ProcessingManager cleanup completed")
    }
}

// MARK: - Request Models

struct ProcessingRequest: Codable {
    let url: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case url
        case userId = "user_id"
    }
}

struct GroupProcessingRequest: Codable {
    let url: String
    let userId: String
    let groupId: String
    
    enum CodingKeys: String, CodingKey {
        case url
        case userId = "user_id"
        case groupId = "group_id"
    }
}

// MARK: - Errors

enum ProcessingError: LocalizedError {
    case userNotAuthenticated
    case invalidURL
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "You must be signed in to process videos"
        case .invalidURL:
            return "Please enter a valid URL"
        case .networkError(let message):
            return message
        }
    }
} 
