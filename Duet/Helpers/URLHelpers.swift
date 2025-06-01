import Foundation

struct URLHelpers {
    private static let cloudFrontDomain = "https://d7bydi7oj9ouw.cloudfront.net"
    
    /// Converts an S3 URL to a CloudFront CDN URL
    /// - Parameter s3Url: The original S3 URL
    /// - Returns: CloudFront URL if conversion is successful, original URL otherwise
    static func convertToCloudFrontURL(_ s3Url: String) -> String {
        guard let url = URL(string: s3Url) else {
            return s3Url // Return original if invalid URL
        }
        
        // Extract the S3 key (full path after bucket domain)
        // For URLs like: https://duet-media.s3.eu-north-1.amazonaws.com/profile-images/user123_uuid.jpg
        // We want the key: profile-images/user123_uuid.jpg
        let s3Key = String(url.path.dropFirst()) // Remove leading slash
        
        // Guard against empty keys
        guard !s3Key.isEmpty else {
            return s3Url // Return original if no valid key
        }
        
        // Construct CloudFront URL
        let cloudFrontUrl = "\(cloudFrontDomain)/\(s3Key)"
        
        return cloudFrontUrl
    }
    
    /// Converts an S3 URL to a CloudFront CDN URL, returning a URL object
    /// - Parameter s3Url: The original S3 URL string
    /// - Returns: CloudFront URL object if conversion is successful, original URL otherwise
    static func convertToCloudFrontURLObject(_ s3Url: String) -> URL? {
        let convertedString = convertToCloudFrontURL(s3Url)
        return URL(string: convertedString)
    }
} 