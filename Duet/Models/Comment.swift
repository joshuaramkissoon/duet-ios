import Foundation
import FirebaseFirestore

struct Comment: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let content: String
    let createdAt: Date
    let parentCommentId: String?
    
    // Enriched user data (not stored in Firestore)
    var author: User?

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case content
        case createdAt
        case parentCommentId
        // Note: author is not in CodingKeys since it's not stored in Firestore
    }
} 
