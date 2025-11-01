import Foundation

struct ContentParser {
    // MARK: - Main Content Extraction
    
    static func extractMainContent(from html: String) -> String {
        // Remove script, style, and other non-content tags
        let cleaned = html
            .replacingOccurrences(of: "<script[^>]*>.*?</script>", with: "", options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive])
            .replacingOccurrences(of: "<style[^>]*>.*?</style>", with: "", options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive])
            .replacingOccurrences(of: "<noscript[^>]*>.*?</noscript>", with: "", options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive])
            .replacingOccurrences(of: "<svg[^>]*>.*?</svg>", with: "", options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive])
        
        // Try to extract article content from common article tags
        let articlePatterns = [
            "<article[^>]*>(.*?)</article>",
            "<main[^>]*>(.*?)</main>",
            "<div[^>]*class=['\"][^'\"]*article[^'\"]*['\"][^>]*>(.*?)</div>",
            "<div[^>]*class=['\"][^'\"]*content[^'\"]*['\"][^>]*>(.*?)</div>",
            "<div[^>]*id=['\"][^'\"]*content[^'\"]*['\"][^>]*>(.*?)</div>",
            "<body[^>]*>(.*?)</body>"
        ]
        
        var extractedContent = cleaned
        
        for pattern in articlePatterns {
            if let range = cleaned.range(of: pattern, options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive]) {
                let match = String(cleaned[range])
                if match.count > 100 { // Only use if substantial content
                    extractedContent = match
                    break
                }
            }
        }
        
        // Remove HTML tags
        var text = extractedContent
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: String.CompareOptions.regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ", options: String.CompareOptions.caseInsensitive)
            .replacingOccurrences(of: "&amp;", with: "&", options: String.CompareOptions.caseInsensitive)
            .replacingOccurrences(of: "&lt;", with: "<", options: String.CompareOptions.caseInsensitive)
            .replacingOccurrences(of: "&gt;", with: ">", options: String.CompareOptions.caseInsensitive)
            .replacingOccurrences(of: "&quot;", with: "\"", options: String.CompareOptions.caseInsensitive)
            .replacingOccurrences(of: "&#39;", with: "'", options: String.CompareOptions.caseInsensitive)
            .replacingOccurrences(of: "&apos;", with: "'", options: String.CompareOptions.caseInsensitive)
        
        // Remove common noise patterns that appear in extracted content
        let noisePatterns = [
            "Skip to content",
            "Skip to main content",
            "Jump to navigation",
            "Cookie consent",
            "Accept cookies",
            "We use cookies",
            "Subscribe to newsletter",
            "Newsletter signup",
            "Related articles",
            "Share this article",
            "Advertisement",
            "Ad:",
            "Loading...",
            "Please enable JavaScript",
            "Enable cookies",
            "This website uses cookies"
        ]
        
        for pattern in noisePatterns {
            text = text.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        
        // Remove navigation menus (usually repetitive short phrases)
        let lines = text.components(separatedBy: .newlines)
        let filteredLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove very short lines that are likely navigation items
            if trimmed.count < 10 { return false }
            // Remove lines that look like navigation (repetitive patterns)
            let lowercased = trimmed.lowercased()
            if lowercased == "home" || lowercased == "menu" || lowercased == "search" {
                return false
            }
            return true
        }
        text = filteredLines.joined(separator: "\n")
        
        // Clean up whitespace
        text = text
            .replacingOccurrences(of: "\\s+", with: " ", options: String.CompareOptions.regularExpression)
            .replacingOccurrences(of: "\\n\\s*\\n", with: "\n\n", options: String.CompareOptions.regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // Remove empty paragraphs
        let paragraphs = text.components(separatedBy: "\n\n")
        let meaningfulParagraphs = paragraphs.filter { paragraph in
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count >= 20 // Keep paragraphs with substantial content
        }
        text = meaningfulParagraphs.joined(separator: "\n\n")
        
        // Limit content size (keep most important content)
        if text.count > 15000 {
            // Try to keep first substantial paragraphs (usually most important)
            let allParagraphs = text.components(separatedBy: "\n\n")
            var selectedParagraphs: [String] = []
            var totalLength = 0
            
            for paragraph in allParagraphs {
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                if totalLength + trimmed.count <= 15000 {
                    selectedParagraphs.append(paragraph)
                    totalLength += trimmed.count
                } else {
                    break
                }
            }
            
            text = selectedParagraphs.joined(separator: "\n\n")
            if text.count < 15000 {
                text += "..."
            } else {
                text = String(text.prefix(15000)) + "..."
            }
        }
        
        return text
    }
    
    // MARK: - Title Extraction
    
    static func extractTitle(from html: String) -> String? {
        // Try og:title first (most reliable)
        if let ogTitle = extractMetaProperty(from: html, property: "og:title") {
            return decodeHTMLEntities(in: ogTitle)
        }
        
        // Try twitter:title
        if let twitterTitle = extractMetaProperty(from: html, property: "twitter:title") {
            return decodeHTMLEntities(in: twitterTitle)
        }
        
        // Try <title> tag
        if let titleMatch = html.range(of: "<title[^>]*>(.*?)</title>", options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive]) {
            let fullMatch = String(html[titleMatch])
            if let contentMatch = fullMatch.range(of: ">(.*?)<", options: String.CompareOptions.regularExpression) {
                var title = String(fullMatch[contentMatch])
                title = String(title.dropFirst().dropLast()) // Remove > and <
                return decodeHTMLEntities(in: title.trimmingCharacters(in: CharacterSet.whitespaces))
            }
        }
        
        // Try h1 tag
        if let h1Match = html.range(of: "<h1[^>]*>(.*?)</h1>", options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive]) {
            let fullMatch = String(html[h1Match])
            if let contentMatch = fullMatch.range(of: ">(.*?)<", options: String.CompareOptions.regularExpression) {
                var title = String(fullMatch[contentMatch])
                title = String(title.dropFirst().dropLast())
                let decoded = decodeHTMLEntities(in: title.trimmingCharacters(in: .whitespaces))
                if !decoded.isEmpty && decoded.count < 200 {
                    return decoded
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Meta Description Extraction
    
    static func extractMetaDescription(from html: String) -> String? {
        // Try og:description
        if let ogDesc = extractMetaProperty(from: html, property: "og:description") {
            return decodeHTMLEntities(in: ogDesc)
        }
        
        // Try twitter:description
        if let twitterDesc = extractMetaProperty(from: html, property: "twitter:description") {
            return decodeHTMLEntities(in: twitterDesc)
        }
        
        // Try standard meta description
        if let desc = extractMetaContent(from: html, name: "description") {
            return decodeHTMLEntities(in: desc)
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    private static func extractMetaProperty(from html: String, property: String) -> String? {
        let pattern = "<meta[^>]*property=['\"]\(property)['\"][^>]*content=['\"]([^'\"]+)['\"]"
        if let range = html.range(of: pattern, options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive]) {
            let match = String(html[range])
            if let contentMatch = match.range(of: "content=['\"]([^'\"]+)['\"]", options: String.CompareOptions.regularExpression) {
                var content = String(match[contentMatch])
                content = content.replacingOccurrences(of: "content=\"", with: "")
                content = content.replacingOccurrences(of: "content='", with: "")
                content = String(content.dropLast())
                return content.trimmingCharacters(in: CharacterSet.whitespaces)
            }
        }
        return nil
    }
    
    private static func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = "<meta[^>]*name=['\"]\(name)['\"][^>]*content=['\"]([^'\"]+)['\"]"
        if let range = html.range(of: pattern, options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive]) {
            let match = String(html[range])
            if let contentMatch = match.range(of: "content=['\"]([^'\"]+)['\"]", options: String.CompareOptions.regularExpression) {
                var content = String(match[contentMatch])
                content = content.replacingOccurrences(of: "content=\"", with: "")
                content = content.replacingOccurrences(of: "content='", with: "")
                content = String(content.dropLast())
                return content.trimmingCharacters(in: CharacterSet.whitespaces)
            }
        }
        return nil
    }
    
    private static func decodeHTMLEntities(in text: String) -> String {
        return text
            .replacingOccurrences(of: "&nbsp;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&amp;", with: "&", options: .caseInsensitive)
            .replacingOccurrences(of: "&lt;", with: "<", options: .caseInsensitive)
            .replacingOccurrences(of: "&gt;", with: ">", options: .caseInsensitive)
            .replacingOccurrences(of: "&quot;", with: "\"", options: .caseInsensitive)
            .replacingOccurrences(of: "&#39;", with: "'", options: .caseInsensitive)
            .replacingOccurrences(of: "&apos;", with: "'", options: .caseInsensitive)
            .replacingOccurrences(of: "&hellip;", with: "...", options: .caseInsensitive)
            .replacingOccurrences(of: "&mdash;", with: "—", options: .caseInsensitive)
            .replacingOccurrences(of: "&ndash;", with: "–", options: .caseInsensitive)
    }
    
    // MARK: - OpenGraph Tag Extraction
    
    static func extractOpenGraphTag(from html: String, property: String) -> String? {
        return extractMetaProperty(from: html, property: property)
    }
    
    // MARK: - Author Extraction
    
    static func extractAuthor(from html: String) -> String? {
        // Try various author meta tags
        if let author = extractMetaProperty(from: html, property: "article:author") {
            return decodeHTMLEntities(in: author)
        }
        if let author = extractMetaContent(from: html, name: "author") {
            return decodeHTMLEntities(in: author)
        }
        if let author = extractMetaContent(from: html, name: "article:author") {
            return decodeHTMLEntities(in: author)
        }
        
        // Try JSON-LD structured data
        if let jsonLdAuthor = extractJSONLDAuthor(from: html) {
            return jsonLdAuthor
        }
        
        return nil
    }
    
    // MARK: - Published Date Extraction
    
    static func extractPublishedDate(from html: String) -> String? {
        // Try various date meta tags
        if let date = extractMetaProperty(from: html, property: "article:published_time") {
            return date
        }
        if let date = extractMetaContent(from: html, name: "date") {
            return date
        }
        if let date = extractMetaContent(from: html, name: "pubdate") {
            return date
        }
        
        // Try JSON-LD structured data
        if let jsonLdDate = extractJSONLDPublishedDate(from: html) {
            return jsonLdDate
        }
        
        return nil
    }
    
    // MARK: - Keywords Extraction
    
    static func extractKeywords(from html: String) -> [String] {
        var keywords: [String] = []
        
        // Extract meta keywords
        if let metaKeywords = extractMetaContent(from: html, name: "keywords") {
            keywords.append(contentsOf: metaKeywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        }
        
        // Extract OpenGraph tags
        if let ogTags = extractMetaProperty(from: html, property: "article:tag") {
            keywords.append(ogTags)
        }
        
        return keywords.filter { !$0.isEmpty }
    }
    
    // MARK: - JSON-LD Extraction
    
    private static func extractJSONLDAuthor(from html: String) -> String? {
        let pattern = "<script[^>]*type=['\"]application/ld\\+json['\"][^>]*>(.*?)</script>"
        if let range = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let jsonString = String(html[range])
            if let jsonData = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                // Try various author fields
                if let author = json["author"] as? [String: Any],
                   let name = author["name"] as? String {
                    return name
                }
                if let author = json["author"] as? String {
                    return author
                }
            }
        }
        return nil
    }
    
    private static func extractJSONLDPublishedDate(from html: String) -> String? {
        let pattern = "<script[^>]*type=['\"]application/ld\\+json['\"][^>]*>(.*?)</script>"
        if let range = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let jsonString = String(html[range])
            if let jsonData = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                if let datePublished = json["datePublished"] as? String {
                    return datePublished
                }
                if let datePublished = json["datepublished"] as? String {
                    return datePublished
                }
            }
        }
        return nil
    }
}

