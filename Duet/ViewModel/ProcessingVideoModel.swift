//
//  ProcessingVideoModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 23/05/2025.
//

import Foundation

struct ProcessingVideo: Identifiable, Equatable {
    let id = UUID()
    let url: String
    let startTime: Date
    var endTime: Date? = nil
    var status: ProcessingStatus
    
    enum ProcessingStatus: Equatable {
        static func == (lhs: ProcessingStatus, rhs: ProcessingStatus) -> Bool {
            switch (lhs, rhs) {
            case (.processing, .processing):
                return true
            case (.completed(let lhsResponse), .completed(let rhsResponse)):
                return lhsResponse.summary.id == rhsResponse.summary.id
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
        
        case processing
        case completed(DateIdeaResponse)
        case failed(String)
    }
    
    var displayUrl: String {
        // Clean up URL for display
        let cleanUrl = url.replacingOccurrences(of: "https://", with: "")
                         .replacingOccurrences(of: "http://", with: "")
        
        // Truncate if too long
        if cleanUrl.count > 40 {
            let start = cleanUrl.prefix(20)
            let end = cleanUrl.suffix(15)
            return "\(start)...\(end)"
        }
        return cleanUrl
    }
    
    var processingDuration: TimeInterval {
        if case .processing = status {
            Date().timeIntervalSince(startTime)
        }
        else {
            (endTime ?? Date()).timeIntervalSince(startTime)
        }
    }
}
