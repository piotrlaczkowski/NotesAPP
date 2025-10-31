import Foundation

/// Metadata extracted from a URL, used to enhance LLM analysis
struct ContentMetadata: Codable {
    let url: URL
    let pageTitle: String?
    let metaDescription: String?
    let openGraphTitle: String?
    let openGraphDescription: String?
    let openGraphType: String?
    let author: String?
    let publishedDate: String?
    let keywords: [String]
    let domain: String?
    let pathComponents: [String]
    let contentType: String?
    
    /// Combined context string for LLM analysis
    func contextString() -> String {
        var context = ""
        
        if let domain = domain {
            context += "Domain: \(domain)\n"
        }
        
        if !pathComponents.isEmpty {
            context += "Path: \(pathComponents.joined(separator: "/"))\n"
        }
        
        if let pageTitle = pageTitle {
            context += "Page Title: \(pageTitle)\n"
        }
        
        if let ogTitle = openGraphTitle, ogTitle != pageTitle {
            context += "OpenGraph Title: \(ogTitle)\n"
        }
        
        if let metaDesc = metaDescription {
            context += "Meta Description: \(metaDesc)\n"
        }
        
        if let ogDesc = openGraphDescription, ogDesc != metaDescription {
            context += "OpenGraph Description: \(ogDesc)\n"
        }
        
        if let ogType = openGraphType {
            context += "Content Type: \(ogType)\n"
        }
        
        if let author = author {
            context += "Author: \(author)\n"
        }
        
        if let date = publishedDate {
            context += "Published: \(date)\n"
        }
        
        if !keywords.isEmpty {
            context += "Keywords: \(keywords.joined(separator: ", "))\n"
        }
        
        if let contentType = contentType {
            context += "Content-Type: \(contentType)\n"
        }
        
        return context
    }
}

