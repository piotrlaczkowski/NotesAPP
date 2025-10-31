import Foundation

actor URLContentExtractor {
    static let shared = URLContentExtractor()
    
    struct ExtractionResult {
        let content: String
        let metadata: ContentMetadata
    }
    
    func extractContent(from url: URL) async throws -> String {
        // Check if URL points to a PDF
        if url.pathExtension.lowercased() == "pdf" || url.absoluteString.lowercased().contains(".pdf") {
            if let pdfText = try? await PDFExtractor.extractText(from: url), !pdfText.isEmpty {
                return pdfText
            }
            // Fall through to web content if PDF extraction fails
        }
        
        // Handle different URL types
        if url.host?.contains("arxiv.org") == true {
            return try await extractArXivContent(url: url)
        } else if url.host?.contains("github.com") == true {
            return try await extractGitHubContent(url: url)
        } else {
            return try await extractWebContent(url: url)
        }
    }
    
    /// Enhanced extraction that returns both content and metadata
    /// This method is more efficient as it extracts both from a single fetch when possible
    func extractContentWithMetadata(from url: URL) async throws -> ExtractionResult {
        // For PDFs, extract content and return basic metadata
        if url.pathExtension.lowercased() == "pdf" || url.absoluteString.lowercased().contains(".pdf") {
            if let pdfText = try? await PDFExtractor.extractText(from: url), !pdfText.isEmpty {
                return ExtractionResult(
                    content: pdfText,
                    metadata: createBasicMetadata(from: url)
                )
            }
        }
        
        // Fetch once and extract both content and metadata
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ContentExtractionError.httpError
        }
        
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        
        // Handle PDF content type (check both content-type header and URL)
        if contentType.contains("application/pdf") || 
           contentType.contains("pdf") ||
           url.pathExtension.lowercased() == "pdf" || 
           url.absoluteString.lowercased().contains(".pdf") {
            // Try to extract text from the PDF data we already fetched
            if let pdfText = PDFExtractor.extractText(from: data), !pdfText.isEmpty {
                return ExtractionResult(
                    content: pdfText,
                    metadata: createBasicMetadata(from: url)
                )
            } else {
                // For ArXiv PDFs, suggest using the abstract page instead
                if url.host?.contains("arxiv.org") == true && url.path.contains("/pdf/") {
                    // Extract paper ID from path (e.g., /pdf/2510.17800 -> 2510.17800)
                    let paperId = url.pathComponents.last?.replacingOccurrences(of: ".pdf", with: "") ?? ""
                    if !paperId.isEmpty, let abstractURL = URL(string: "https://arxiv.org/abs/\(paperId)") {
                        throw ContentExtractionError.arxivPdfNotExtractable(suggestedURL: abstractURL)
                    }
                }
                // PDF extraction failed - provide helpful error
                throw ContentExtractionError.pdfExtractionFailed
            }
        }
        
        // Handle HTML content
        if contentType.contains("text/html") {
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
                throw ContentExtractionError.invalidData
            }
            
            // Extract content based on URL type (use already fetched HTML)
            let content: String
            if url.host?.contains("arxiv.org") == true {
                // Use HTML we already fetched for ArXiv
                var arxivContent = ""
                if let title = ContentParser.extractTitle(from: html) {
                    arxivContent += title + "\n\n"
                }
                if let abstract = extractArXivAbstract(from: html) {
                    arxivContent += "Abstract:\n\(abstract)\n\n"
                }
                let mainContent = ContentParser.extractMainContent(from: html)
                content = arxivContent + mainContent
            } else if url.host?.contains("github.com") == true {
                // Try to extract GitHub content from fetched HTML
                let mainContent = ContentParser.extractMainContent(from: html)
                if mainContent.contains("README") || mainContent.count > 200 {
                    content = mainContent
                } else {
                    // Fall back to re-fetching with GitHub-specific logic
                    content = try await extractGitHubContent(url: url)
                }
            } else {
                // Use the fetched HTML
                var extractedContent = ContentParser.extractMainContent(from: html)
                if extractedContent.isEmpty {
                    // Fallback: use title and description
                    var fallbackContent = ""
                    if let title = ContentParser.extractTitle(from: html) {
                        fallbackContent += title + "\n\n"
                    }
                    if let desc = ContentParser.extractMetaDescription(from: html) {
                        fallbackContent += desc + "\n\n"
                    }
                    fallbackContent += html
                    extractedContent = fallbackContent
                }
                content = extractedContent
            }
            
            // Extract metadata from the same HTML
            let metadata = extractMetadata(from: html, url: url, contentType: contentType)
            
            return ExtractionResult(content: content, metadata: metadata)
        } else {
            // Non-HTML content (plain text, JSON, etc.)
            let content: String
            if let text = String(data: data, encoding: .utf8) {
                content = text
            } else {
                throw ContentExtractionError.invalidData
            }
            
            return ExtractionResult(
                content: content,
                metadata: createBasicMetadata(from: url)
            )
        }
    }
    
    private func extractMetadata(from html: String, url: URL, contentType: String?) -> ContentMetadata {
        let pageTitle = ContentParser.extractTitle(from: html)
        let metaDescription = ContentParser.extractMetaDescription(from: html)
        let openGraphTitle = ContentParser.extractOpenGraphTag(from: html, property: "og:title")
        let openGraphDescription = ContentParser.extractOpenGraphTag(from: html, property: "og:description")
        let openGraphType = ContentParser.extractOpenGraphTag(from: html, property: "og:type")
        let author = ContentParser.extractAuthor(from: html)
        let publishedDate = ContentParser.extractPublishedDate(from: html)
        let keywords = ContentParser.extractKeywords(from: html)
        
        return ContentMetadata(
            url: url,
            pageTitle: pageTitle,
            metaDescription: metaDescription,
            openGraphTitle: openGraphTitle,
            openGraphDescription: openGraphDescription,
            openGraphType: openGraphType,
            author: author,
            publishedDate: publishedDate,
            keywords: keywords,
            domain: url.host,
            pathComponents: url.pathComponents.filter { $0 != "/" },
            contentType: contentType
        )
    }
    
    private func createBasicMetadata(from url: URL) -> ContentMetadata {
        return ContentMetadata(
            url: url,
            pageTitle: nil,
            metaDescription: nil,
            openGraphTitle: nil,
            openGraphDescription: nil,
            openGraphType: nil,
            author: nil,
            publishedDate: nil,
            keywords: [],
            domain: url.host,
            pathComponents: url.pathComponents.filter { $0 != "/" },
            contentType: nil
        )
    }
    
    private func extractArXivContent(url: URL) async throws -> String {
        // ArXiv paper extraction - parse HTML to get title, authors, abstract
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ContentExtractionError.httpError
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.invalidData
        }
        
        // Extract ArXiv-specific content
        var content = ""
        
        // Extract title
        if let title = extractArXivField(from: html, field: "Title") {
            content += "Title: \(title)\n\n"
        }
        
        // Extract authors
        if let authors = extractArXivField(from: html, field: "Authors") {
            content += "Authors: \(authors)\n\n"
        }
        
        // Extract abstract
        if let abstract = extractArXivAbstract(from: html) {
            content += "Abstract:\n\(abstract)\n\n"
        }
        
        // Extract main content
        let mainContent = ContentParser.extractMainContent(from: html)
        if !mainContent.isEmpty {
            content += mainContent
        }
        
        return content.isEmpty ? html : content
    }
    
    private func extractArXivField(from html: String, field: String) -> String? {
        // ArXiv uses specific HTML structure
        let pattern = "<div[^>]*class=['\"]abs-subject['\"]>.*?<span[^>]*class=['\"]descriptor['\"]>\(field):</span>([^<]+)</div>"
        if let range = html.range(of: pattern, options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive]) {
            let match = String(html[range])
            if let contentMatch = match.range(of: "</span>([^<]+)</div>", options: String.CompareOptions.regularExpression) {
                var content = String(match[contentMatch])
                content = content.replacingOccurrences(of: "</span>", with: "")
                content = content.replacingOccurrences(of: "</div>", with: "")
                return content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    private func extractArXivAbstract(from html: String) -> String? {
        // Extract abstract block
        let pattern = "<blockquote[^>]*class=['\"]abstract[^>]*>(.*?)</blockquote>"
        if let range = html.range(of: pattern, options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive]) {
            let match = String(html[range])
            let cleaned = match
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: String.CompareOptions.regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: String.CompareOptions.regularExpression)
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }
        return nil
    }
    
    private func extractGitHubContent(url: URL) async throws -> String {
        // GitHub repo - extract README using GitHub API or HTML parsing
        var content = ""
        
        // Try to construct GitHub API URL
        let pathComponents = url.pathComponents
        if pathComponents.count >= 3 {
            let owner = pathComponents[1]
            let repo = pathComponents[2]
            let apiURL = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/readme")!
            
            // Try API first
            do {
                var request = URLRequest(url: apiURL)
                request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let base64Content = json["content"] as? String,
                   let decoded = Data(base64Encoded: base64Content, options: .ignoreUnknownCharacters),
                   let readme = String(data: decoded, encoding: .utf8) {
                    content = "GitHub Repository: \(owner)/\(repo)\n\n"
                    content += readme
                    return content
                }
            } catch {
                // Fall back to HTML parsing
            }
        }
        
        // Fallback: Parse HTML for README
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ContentExtractionError.httpError
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.invalidData
        }
        
        // Extract README from HTML
        if let readmeMatch = html.range(of: "<div[^>]*id=['\"]readme['\"][^>]*>(.*?)</div>", options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive]) {
            let readmeHTML = String(html[readmeMatch])
            let readme = ContentParser.extractMainContent(from: readmeHTML)
            if !readme.isEmpty {
                content = "GitHub Repository README:\n\n\(readme)"
                return content
            }
        }
        
        // Last resort: extract main content
        content = ContentParser.extractMainContent(from: html)
        return content.isEmpty ? html : content
    }
    
    private func extractWebContent(url: URL) async throws -> String {
        // General web content extraction
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContentExtractionError.httpError
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ContentExtractionError.httpError
        }
        
        // Detect content type
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        
        if contentType.contains("text/html") {
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
                throw ContentExtractionError.invalidData
            }
            
            // Use ContentParser to extract main content
            let mainContent = ContentParser.extractMainContent(from: html)
            
            // Build comprehensive content
            var content = ""
            
            if let title = ContentParser.extractTitle(from: html) {
                content += "\(title)\n\n"
            }
            
            if let description = ContentParser.extractMetaDescription(from: html) {
                content += "\(description)\n\n"
            }
            
            if !mainContent.isEmpty {
                content += mainContent
            } else {
                // Fallback to raw HTML extraction
                content = html
            }
            
            return content
        } else if contentType.contains("application/json") || contentType.contains("text/plain") {
            // Plain text or JSON content
            if let text = String(data: data, encoding: .utf8) {
                return text
            }
            throw ContentExtractionError.invalidData
        } else {
            // Unknown content type, try UTF-8
            if let text = String(data: data, encoding: .utf8) {
                return text
            }
            throw ContentExtractionError.invalidData
        }
    }
}

enum ContentExtractionError: LocalizedError {
    case invalidData
    case httpError
    case parsingError
    case pdfExtractionFailed
    case arxivPdfNotExtractable(suggestedURL: URL)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Unable to decode the content. The data format may not be supported."
        case .httpError:
            return "Failed to fetch the content from the URL. Please check your internet connection and try again."
        case .parsingError:
            return "Unable to parse the content. The page structure may be unsupported."
        case .pdfExtractionFailed:
            return "Unable to extract text from the PDF. The PDF may be encrypted, corrupted, or image-based (scanned)."
        case .arxivPdfNotExtractable(let suggestedURL):
            return "ArXiv PDF extraction failed. Try using the abstract page instead: \(suggestedURL.absoluteString)"
        }
    }
}

