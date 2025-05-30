import SwiftUI

struct ProcessingJobsView: View {
    @ObservedObject var processingManager: ProcessingManager
    @EnvironmentObject private var toast: ToastManager
    @EnvironmentObject private var activityVM: ActivityHistoryViewModel
    let showOnlyActive: Bool
    
    @State private var isExpanded: Bool = false
    
    init(processingManager: ProcessingManager, showOnlyActive: Bool = false) {
        self.processingManager = processingManager
        self.showOnlyActive = showOnlyActive
    }
    
    private var jobsToShow: [ProcessingJob] {
        let jobs = if showOnlyActive {
            processingManager.getActiveUserJobs()
        } else {
            processingManager.getAllUserJobs()
        }
        print("🎬 ProcessingJobsView jobsToShow: \(jobs.count) jobs (showOnlyActive: \(showOnlyActive))")
        return jobs
    }
    
    private var activeJobCount: Int {
        let count = processingManager.getActiveUserJobs().count
        print("🎬 ProcessingJobsView activeJobCount: \(count)")
        return count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !jobsToShow.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with expand/collapse button
                    HStack {
                        Text("Processing Videos")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            if activeJobCount > 0 {
                                Text("\(activeJobCount)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.appPrimary)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.appPrimary)
                                    .rotationEffect(.degrees(isExpanded ? 0 : 0))
                            }
                        }
                    }
                    
                    // Processing job cards - stacked or expanded
                    if isExpanded {
                        // Expanded view - show all cards
                        LazyVStack(spacing: 12) {
                            ForEach(jobsToShow, id: \.id) { job in
                                ProcessingJobVideoCard(
                                    job: job,
                                    onRetry: { job in
                                        Task {
                                            do {
                                                try await processingManager.retryProcessing(job: job)
                                                await MainActor.run {
                                                    toast.success("Retrying \(job.url)")
                                                }
                                            } catch {
                                                await MainActor.run {
                                                    if let processingError = error as? ProcessingError {
                                                        toast.error(processingError.localizedDescription)
                                                    } else {
                                                        toast.error("Failed to retry processing")
                                                    }
                                                }
                                                print("❌ Retry failed: \(error)")
                                            }
                                        }
                                    },
                                    onRemove: {
                                        Task {
                                            do {
                                                try await processingManager.removeProcessingJob(job)
                                            } catch {
                                                await MainActor.run {
                                                    toast.error("Failed to remove processing job")
                                                }
                                                print("❌ Remove failed: \(error)")
                                            }
                                        }
                                    },
                                    activityData: getActivityData(for: job)
                                )
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                                    removal: .scale(scale: 0.8).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                                ))
                            }
                        }
                        .transition(.opacity)
                    } else {
                        // Collapsed view - show stacked cards
                        StackedProcessingCards(
                            jobs: Array(jobsToShow.prefix(3)),
                            onRetry: { job in
                                Task {
                                    do {
                                        try await processingManager.retryProcessing(job: job)
                                        await MainActor.run {
                                            toast.success("Retrying \(job.url)")
                                        }
                                    } catch {
                                        await MainActor.run {
                                            if let processingError = error as? ProcessingError {
                                                toast.error(processingError.localizedDescription)
                                            } else {
                                                toast.error("Failed to retry processing")
                                            }
                                        }
                                        print("❌ Retry failed: \(error)")
                                    }
                                }
                            },
                            onRemove: { job in
                                Task {
                                    do {
                                        try await processingManager.removeProcessingJob(job)
                                    } catch {
                                        await MainActor.run {
                                            toast.error("Failed to remove processing job")
                                        }
                                        print("❌ Remove failed: \(error)")
                                    }
                                }
                            },
                            getActivityData: getActivityData,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isExpanded = true
                                }
                            }
                        )
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: jobsToShow.map(\.id))
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: isExpanded)
        .shadow(
            color: Color.black.opacity(0.12),
            radius: 10,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Helper Methods
    
    private func getActivityData(for job: ProcessingJob) -> DateIdeaResponse? {
        guard job.isCompleted, let resultId = job.resultId else { return nil }
        return activityVM.activities.first { $0.id == resultId }
    }
}

// MARK: - Group Processing Jobs View

struct GroupProcessingJobsView: View {
    @ObservedObject var processingManager: ProcessingManager
    @EnvironmentObject private var toast: ToastManager
    @EnvironmentObject private var groupDetailVM: GroupDetailViewModel
    let groupId: String
    let showOnlyActive: Bool
    
    @State private var isExpanded: Bool = false
    
    init(processingManager: ProcessingManager, groupId: String, showOnlyActive: Bool = false) {
        self.processingManager = processingManager
        self.groupId = groupId
        self.showOnlyActive = showOnlyActive
    }
    
    private var jobsToShow: [ProcessingJob] {
        let jobs = if showOnlyActive {
            processingManager.getActiveGroupJobs(for: groupId)
        } else {
            processingManager.getAllGroupJobs(for: groupId)
        }
        print("🎬 GroupProcessingJobsView jobsToShow for group \(groupId): \(jobs.count) jobs (showOnlyActive: \(showOnlyActive))")
        return jobs
    }
    
    private var activeJobCount: Int {
        let count = processingManager.getActiveGroupJobs(for: groupId).count
        print("🎬 GroupProcessingJobsView activeJobCount for group \(groupId): \(count)")
        return count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !jobsToShow.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with expand/collapse button
                    HStack {
                        Text("Processing Videos")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            if activeJobCount > 0 {
                                Text("\(activeJobCount)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.appPrimary)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.appPrimary)
                                    .rotationEffect(.degrees(isExpanded ? 0 : 0))
                            }
                        }
                    }
                    
                    // Processing job cards - stacked or expanded
                    if isExpanded {
                        // Expanded view - show all cards
                        LazyVStack(spacing: 12) {
                            ForEach(jobsToShow, id: \.id) { job in
                                ProcessingJobVideoCard(
                                    job: job,
                                    onRetry: { job in
                                        Task {
                                            do {
                                                try await processingManager.retryProcessing(job: job)
                                                await MainActor.run {
                                                    toast.success("Retrying video processing...")
                                                }
                                            } catch {
                                                await MainActor.run {
                                                    if let processingError = error as? ProcessingError {
                                                        toast.error(processingError.localizedDescription)
                                                    } else {
                                                        toast.error("Failed to retry processing")
                                                    }
                                                }
                                                print("❌ Retry failed: \(error)")
                                            }
                                        }
                                    },
                                    onRemove: {
                                        Task {
                                            do {
                                                try await processingManager.removeProcessingJob(job)
                                            } catch {
                                                await MainActor.run {
                                                    toast.error("Failed to remove processing job")
                                                }
                                                print("❌ Remove failed: \(error)")
                                            }
                                        }
                                    },
                                    activityData: getGroupActivityData(for: job)
                                )
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                                    removal: .scale(scale: 0.8).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                                ))
                            }
                        }
                        .transition(.opacity)
                    } else {
                        // Collapsed view - show stacked cards
                        StackedProcessingCards(
                            jobs: Array(jobsToShow.prefix(3)),
                            onRetry: { job in
                                Task {
                                    do {
                                        try await processingManager.retryProcessing(job: job)
                                        await MainActor.run {
                                            toast.success("Retrying video processing...")
                                        }
                                    } catch {
                                        await MainActor.run {
                                            if let processingError = error as? ProcessingError {
                                                toast.error(processingError.localizedDescription)
                                            } else {
                                                toast.error("Failed to retry processing")
                                            }
                                        }
                                        print("❌ Retry failed: \(error)")
                                    }
                                }
                            },
                            onRemove: { job in
                                Task {
                                    do {
                                        try await processingManager.removeProcessingJob(job)
                                    } catch {
                                        await MainActor.run {
                                            toast.error("Failed to remove processing job")
                                        }
                                        print("❌ Remove failed: \(error)")
                                    }
                                }
                            },
                            getActivityData: getGroupActivityData,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isExpanded = true
                                }
                            }
                        )
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: jobsToShow.map(\.id))
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: isExpanded)
        .shadow(
            color: Color.black.opacity(0.12),
            radius: 10,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Helper Methods
    
    private func getGroupActivityData(for job: ProcessingJob) -> DateIdeaResponse? {
        guard job.isCompleted, let resultId = job.resultId else { return nil }
        
        // Convert GroupIdea to DateIdeaResponse and find matching idea
        let dateIdeaResponses = groupDetailVM.ideas.map { DateIdeaResponse.fromGroupIdea($0) }
        return dateIdeaResponses.first { $0.id == resultId }
    }
}

// MARK: - Stacked Processing Cards Component

struct StackedProcessingCards: View {
    let jobs: [ProcessingJob]
    let onRetry: (ProcessingJob) -> Void
    let onRemove: (ProcessingJob) -> Void
    let getActivityData: (ProcessingJob) -> DateIdeaResponse?
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // Background cards (stacked effect)
            ForEach(Array(jobs.enumerated().reversed()), id: \.element.id) { index, job in
                ProcessingJobVideoCard(
                    job: job,
                    onRetry: onRetry,
                    onRemove: { onRemove(job) },
                    activityData: getActivityData(job),
                    isStacked: true,
                    stackIndex: index
                )
                .offset(x: CGFloat(index * 6), y: CGFloat(index * -8))
                .scaleEffect(1.0 - CGFloat(index) * 0.03)
                .zIndex(Double(jobs.count - index))
                .opacity(index == 0 ? 1.0 : 0.85 - CGFloat(index) * 0.15)
            }
            
            // Subtle tap hint overlay (only if more than 1 job)
            if jobs.count > 1 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Tap to expand")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                            .opacity(0.7)
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - ProcessingJobVideoCard (following ProcessingVideoCard pattern)

struct ProcessingJobVideoCard: View {
    @EnvironmentObject private var toast: ToastManager
    let job: ProcessingJob
    let onRetry: (ProcessingJob) -> Void
    let onRemove: () -> Void
    let activityData: DateIdeaResponse?
    var isStacked: Bool = false
    var stackIndex: Int = 0
    
    @State private var animationOffset: CGFloat = 0
    
    private var urlText: some View {
        Text(cleanUrl)
            .font(.system(.footnote, design: .monospaced))
            .fontWeight(.medium)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.primary)
    }
    
    private var cardContent: some View {
        VStack(spacing: 0) {
            // Main content row
            HStack(spacing: 14) {
                // Status indicator - show for processing jobs even when stacked
                if job.isActive || (isStacked && (job.status == "processing" || job.status == "downloading" || job.status == "failed")) {
                    statusIndicator
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if job.isCompleted {
                        // For completed: Show thumbnail and title from Firestore
                        HStack(spacing: 12) {
                            // Thumbnail from Firestore
                            if let thumbnailB64 = job.thumbnailB64 {
                                Base64ImageView(base64String: thumbnailB64, thumbWidth: 80)
                            } else {
                                PlaceholderImageView(thumbWidth: 80)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                // Title from Firestore
                                if let title = job.title {
                                    Text(title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .lineLimit(isStacked ? 2 : 3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .foregroundStyle(.primary)
                                } else {
                                    // Fallback to URL if no title
                                    urlText
                                }
                                
                                // Status and timing row
                                if !isStacked {
                                    HStack {
                                        statusText
                                        
                                        Spacer()
                                        
                                        processingTimer
                                    }
                                }
                            }
                        }
                    } else {
                        // For processing/failed: URL first (original layout)
                        urlText
                        
                        // Status and timing row
                        if !isStacked {
                            HStack {
                                statusText
                                
                                Spacer()
                                
                                if !job.isActive {
                                    processingTimer
                                }
                            }
                        }
                    }
                }
                
                // Action button (only show on top card when stacked)
                if !isStacked || stackIndex == 0 {
                    actionButton
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
        }
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(
            color: Color.black.opacity(0.12),
            radius: 10,
            x: 0,
            y: 4
        )
        .onAppear {
            if job.isActive && !isStacked {
                startLoadingAnimation()
            }
        }
    }
    
    var body: some View {
        Group {
            if job.isCompleted, let activityData = activityData, !isStacked {
                NavigationLink(destination: DateIdeaDetailView(
                    dateIdea: activityData,
                    viewModel: DateIdeaViewModel(toast: toast, videoUrl: activityData.cloudFrontVideoURL)
                )) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }
    
    // MARK: - Status Indicator
    
    @ViewBuilder
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 40, height: 40)
            
            switch job.status {
            case "downloading", "processing":
                LoadingSpinner(color: statusColor)
                    .frame(width: 20, height: 20)
                
            case "completed":
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(statusColor)
                
            case "failed":
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(statusColor)
                
            default:
                Image(systemName: "questionmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Status Text
    
    @ViewBuilder
    private var statusText: some View {
        switch job.status {
        case "downloading":
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Downloading")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Animated dots
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 3, height: 3)
                                .opacity(animationOffset == CGFloat(index) ? 1.0 : 0.3)
                        }
                    }
                }
            }
            
        case "processing":
            HStack(spacing: 4) {
                // Show progress message instead of "Processing" if available
                if !job.progressMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(job.progressMessage.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Processing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Animated dots
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 3, height: 3)
                            .opacity(animationOffset == CGFloat(index) ? 1.0 : 0.3)
                    }
                }
            }
            
        case "completed":
            HStack {
                Image(systemName: "link")
                    .resizable()
                    .frame(width: 12, height: 12)
                Text(cleanUrl)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            
        case "failed":
            VStack(alignment: .leading, spacing: 2) {
                Text("Failed to process")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                
                if let errorMessage = job.errorMessage, !errorMessage.isEmpty && errorMessage != "Failed to process" {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
        default:
            Text(job.progressMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Processing Timer
    
    @ViewBuilder
    private var processingTimer: some View {
        Text(formatDuration(job.processingDuration))
            .font(.caption2.monospacedDigit())
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
    }
    
    // MARK: - Action Button
    
    @ViewBuilder
    private var actionButton: some View {
        VStack(spacing: 8) {
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.gray.opacity(0.5))
            }
            
            // Retry button for failed retryable jobs
            if job.canRetry {
                Button(action: { onRetry(job) }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.appPrimary)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch job.status {
        case "downloading": return .blue
        case "processing": return .appPrimary
        case "completed": return Color(hex: "#456455")
        case "failed": return .red
        default: return .gray
        }
    }
    
    private var cardBackground: some View {
        switch job.status {
        case "downloading", "processing":
            return Color.white
        case "completed":
            return Color(hex: "#E8F5E8") // Light green, non-transparent
        case "failed":
            return Color(hex: "#FFE8E8") // Light red, non-transparent
        default:
            return Color.gray.opacity(0.05)
        }
    }
    
    // Clean URL without truncation but still readable
    private var cleanUrl: String {
        let displayUrl = job.url
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        
        // Only truncate if extremely long (>80 chars)
        if displayUrl.count > 80 {
            let start = displayUrl.prefix(20)
            let end = displayUrl.suffix(20)
            return "\(start)...\(end)"
        }
        
        return displayUrl
    }
    
    // MARK: - Helper Methods
    
    private func startLoadingAnimation() {
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            animationOffset = 2
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes):\(String(format: "%02d", remainingSeconds))"
        }
    }
}

// MARK: - Preview

#Preview {
    let toast = ToastManager()
    let processingManager = ProcessingManager(toast: toast)
    
    // Add sample processing jobs
    processingManager.userProcessingJobs = [
        ProcessingJob(
            id: "1",
            userId: "user1",
            url: "https://www.tiktok.com/@user/video/1234567890",
            groupId: nil,
            status: "processing",
            progressMessage: "Analyzing video content...",
            errorMessage: nil,
            resultId: nil,
            retryable: false,
            thumbnailB64: nil,
            title: nil,
            createdAt: Date().addingTimeInterval(-30),
            updatedAt: Date()
        ),
        ProcessingJob(
            id: "2",
            userId: "user1",
            url: "https://www.youtube.com/watch?v=invalidvideo",
            groupId: nil,
            status: "failed",
            progressMessage: "",
            errorMessage: "Video processing failed due to temporary server issue",
            resultId: nil,
            retryable: true,
            thumbnailB64: nil,
            title: nil,
            createdAt: Date().addingTimeInterval(-120),
            updatedAt: Date().addingTimeInterval(-60)
        ),
        ProcessingJob(
            id: "3",
            userId: "user1",
            url: "https://www.instagram.com/reel/ABC123DEF456/",
            groupId: nil,
            status: "completed",
            progressMessage: "",
            errorMessage: nil,
            resultId: "result_123",
            retryable: false,
            thumbnailB64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIW2P8z/C/HwAGgwJ/lxQh8QAAAABJRU5ErkJggg==",
            title: "Romantic Sunset Picnic",
            createdAt: Date().addingTimeInterval(-180),
            updatedAt: Date().addingTimeInterval(-120)
        )
    ]
    
    return ProcessingJobsView(processingManager: processingManager)
        .environmentObject(toast)
        .environmentObject(ActivityHistoryViewModel())
        .padding()
        .withAppBackground()
} 
