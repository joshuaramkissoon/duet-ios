import Foundation
import FirebaseFirestore

struct ProcessingJob: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let url: String
    let groupId: String?
    var status: String // downloading, processing, completed, failed
    var progressMessage: String
    var errorMessage: String?
    var resultId: String?
    var retryable: Bool
    var thumbnailB64: String? // Base64 encoded thumbnail
    var title: String? // Video title when completed
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case url
        case groupId = "group_id"
        case status
        case progressMessage = "progress_message"
        case errorMessage = "error_message"
        case resultId = "result_id"
        case retryable
        case thumbnailB64 = "thumbnail_b64"
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var isActive: Bool {
        status == "downloading" || status == "processing"
    }
    
    var isCompleted: Bool {
        status == "completed"
    }
    
    var isFailed: Bool {
        status == "failed"
    }
    
    var canRetry: Bool {
        isFailed && retryable
    }
    
    var displayUrl: String {
        let cleanUrl = url
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        
        if cleanUrl.count > 80 {
            let start = cleanUrl.prefix(20)
            let end = cleanUrl.suffix(20)
            return "\(start)...\(end)"
        }
        
        return cleanUrl
    }
    
    var processingDuration: TimeInterval {
        guard let createdAt = createdAt else { return 0 }
        
        if isActive {
            return Date().timeIntervalSince(createdAt)
        } else if let updatedAt = updatedAt {
            return updatedAt.timeIntervalSince(createdAt)
        } else {
            return 0
        }
    }
}

struct ProcessingResponse: Codable {
    let processingId: String
    let message: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case processingId = "processing_id"
        case message
        case status
    }
} 