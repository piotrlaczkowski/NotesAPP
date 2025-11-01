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
        
        // Route to specialized extractors based on domain
        if url.host?.contains("arxiv.org") == true {
            return try await extractArXivContent(url: url)
        } else if url.host?.contains("github.com") == true {
            return try await extractGitHubContent(url: url)
        } else if url.host?.contains("medium.com") == true {
            return try await extractMediumContent(url: url)
        } else if url.host?.contains("twitter.com") == true || url.host?.contains("x.com") == true {
            return try await extractTwitterContent(url: url)
        } else if url.host?.contains("youtube.com") == true || url.host?.contains("youtu.be") == true {
            return try await extractYouTubeContent(url: url)
        } else if url.host?.contains("linkedin.com") == true {
            return try await extractLinkedInContent(url: url)
        } else if url.host?.contains("stackoverflow.com") == true || url.host?.contains("stackexchange.com") == true {
            return try await extractStackOverflowContent(url: url)
        } else if url.host?.contains("producthunt.com") == true {
            return try await extractProductHuntContent(url: url)
        } else if url.host?.contains("reddit.com") == true {
            return try await extractRedditContent(url: url)
        } else if url.host?.contains("wikipedia.org") == true {
            return try await extractWikipediaContent(url: url)
        } else if url.host?.contains("substack.com") == true {
            return try await extractSubstackContent(url: url)
        } else if url.host?.contains("notion.so") == true {
            return try await extractNotionContent(url: url)
        } else if url.host?.contains("docs.google.com") == true {
            return try await extractGoogleDocsContent(url: url)
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
        
        // Wrap in timeout to prevent indefinite hangs (35 second absolute timeout)
        let (data, response): (Data, URLResponse) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            // Network request task
            group.addTask {
                try await URLSession.shared.data(for: request)
            }
            
            // Timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: 35_000_000_000) // 35 seconds
                throw URLError(.timedOut)
            }
            
            // Wait for whichever completes first
            guard let result = try await group.next() else {
                throw URLError(.unknown)
            }
            
            group.cancelAll() // Cancel remaining tasks
            return result
        }
        
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
            
            // Try API first for comprehensive data
            do {
                // Fetch multiple API endpoints for comprehensive data
                var repositoryInfo = ""
                
                // 1. Get repository metadata
                let repoAPIURL = URL(string: "https://api.github.com/repos/\(owner)/\(repo)")!
                var request = URLRequest(url: repoAPIURL)
                request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
                
                if let (data, response) = try? await URLSession.shared.data(for: request),
                   let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    // Extract repository information
                    if let description = json["description"] as? String, !description.isEmpty {
                        repositoryInfo += "Repository: \(owner)/\(repo)\n"
                        repositoryInfo += "Description: \(description)\n\n"
                    } else {
                        repositoryInfo += "Repository: \(owner)/\(repo)\n\n"
                    }
                    
                    // Add topics if available
                    if let topics = json["topics"] as? [String], !topics.isEmpty {
                        repositoryInfo += "Topics: \(topics.joined(separator: ", "))\n\n"
                    }
                    
                    // Add stars and language info
                    if let stars = json["stargazers_count"] as? Int {
                        repositoryInfo += "⭐ Stars: \(stars)\n"
                    }
                    if let language = json["language"] as? String {
                        repositoryInfo += "Language: \(language)\n"
                    }
                    repositoryInfo += "\n"
                }
                
                // 2. Get README content
                let readmeAPIURL = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/readme")!
                var readmeRequest = URLRequest(url: readmeAPIURL)
                readmeRequest.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")
                
                if let (readmeData, readmeResponse) = try? await URLSession.shared.data(for: readmeRequest),
                   let httpResponse = readmeResponse as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode),
                   let readme = String(data: readmeData, encoding: .utf8) {
                    content = repositoryInfo + "README:\n\n" + readme
                    return content
                }
            }
        }
        
        // Fallback: Parse HTML for README and description
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ContentExtractionError.httpError
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.invalidData
        }
        
        // Extract repository title and description from HTML
        var htmlContent = "GitHub Repository\n\n"
        
        // Try to extract the repository description from meta tags
        if let description = extractMetaTagContent(from: html, property: "og:description") {
            htmlContent += "Description: \(description)\n\n"
        }
        
        // Extract README content - look for common readme patterns
        let readmePatterns = [
            "<div[^>]*data-testid=['\"]readme['\"][^>]*>([\\s\\S]*?)</div>",
            "<article[^>]*class=['\"]markdown-body['\"][^>]*>([\\s\\S]*?)</article>",
            "<div[^>]*id=['\"]readme['\"][^>]*>([\\s\\S]*?)</div>",
            "<section[^>]*class=['\"]Box-row['\"][^>]*>([\\s\\S]*?)</section>"
        ]
        
        var readmeFound = false
        for pattern in readmePatterns {
            if let range = html.range(of: pattern, options: [String.CompareOptions.regularExpression, String.CompareOptions.caseInsensitive]) {
                let readmeHTML = String(html[range])
                let readme = ContentParser.extractMainContent(from: readmeHTML)
                if !readme.isEmpty && readme.count > 100 {
                    htmlContent += "README:\n\n" + readme
                    readmeFound = true
                    break
                }
            }
        }
        
        // If no README found, try to extract main content
        if !readmeFound {
            let mainContent = ContentParser.extractMainContent(from: html)
            if !mainContent.isEmpty {
                htmlContent += "Content:\n\n" + mainContent
            } else {
                // Last resort: extract relevant sections from HTML
                if let aboutMatch = html.range(of: "About", options: String.CompareOptions.caseInsensitive) {
                    let startIndex = html.index(aboutMatch.lowerBound, offsetBy: -500, limitedBy: html.startIndex) ?? html.startIndex
                    let endIndex = html.index(aboutMatch.upperBound, offsetBy: 2000, limitedBy: html.endIndex) ?? html.endIndex
                    let section = String(html[startIndex..<endIndex])
                    htmlContent += ContentParser.extractMainContent(from: section)
                }
            }
        }
        
        return htmlContent.isEmpty ? html : htmlContent
    }
    
    private func extractMediumContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.httpError
        }
        
        var content = "Medium Article\n\n"
        
        if let title = ContentParser.extractTitle(from: html) {
            content += "Title: \(title)\n\n"
        }
        
        if let author = ContentParser.extractAuthor(from: html) {
            content += "Author: \(author)\n\n"
        }
        
        if let date = ContentParser.extractPublishedDate(from: html) {
            content += "Published: \(date)\n\n"
        }
        
        // Extract article content
        let articlePatterns = [
            "<article[^>]*>(.*?)</article>",
            "<div[^>]*class=['\"][^'\"]*article-content[^'\"]*['\"][^>]*>(.*?)</div>",
            "<div[^>]*id=['\"]root['\"][^>]*>(.*?)</div>"
        ]
        
        for pattern in articlePatterns {
            if let range = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let articleHTML = String(html[range])
                let articleContent = ContentParser.extractMainContent(from: articleHTML)
                if !articleContent.isEmpty && articleContent.count > 200 {
                    content += articleContent
                    return content
                }
            }
        }
        
        return content + ContentParser.extractMainContent(from: html)
    }
    
    private func extractTwitterContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.httpError
        }
        
        var content = "Tweet/Post\n\n"
        
        if let title = ContentParser.extractTitle(from: html) {
            content += title + "\n\n"
        }
        
        if let description = ContentParser.extractMetaDescription(from: html) {
            content += description + "\n\n"
        }
        
        // Extract tweet text from meta tags
        if let ogDescription = ContentParser.extractOpenGraphTag(from: html, property: "og:description") {
            content += ogDescription
        } else {
            content += ContentParser.extractMainContent(from: html)
        }
        
        return content
    }
    
    private func extractYouTubeContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.httpError
        }
        
        var content = "🎥 YouTube Video\n\n"
        
        if let title = ContentParser.extractTitle(from: html) {
            content += "Title: \(title)\n\n"
        }
        
        if let description = ContentParser.extractMetaDescription(from: html) {
            content += "Description: \(description)\n\n"
        }
        
        // Extract channel and duration from structured data
        if let channelMatch = html.range(of: "\"author\":\\{\"name\":\"([^\"]+)\"", options: .regularExpression) {
            let match = String(html[channelMatch])
            if let nameRange = match.range(of: "\"name\":\"([^\"]+)\"", options: .regularExpression) {
                let name = String(match[nameRange]).replacingOccurrences(of: "\"name\":\"", with: "").replacingOccurrences(of: "\"", with: "")
                content += "Channel: \(name)\n\n"
            }
        }
        
        // Add full description
        content += ContentParser.extractMainContent(from: html)
        
        return content
    }
    
    private func extractLinkedInContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.httpError
        }
        
        var content = "💼 LinkedIn\n\n"
        
        if let title = ContentParser.extractTitle(from: html) {
            content += title + "\n\n"
        }
        
        if let description = ContentParser.extractMetaDescription(from: html) {
            content += description + "\n\n"
        }
        
        content += ContentParser.extractMainContent(from: html)
        return content
    }
    
    private func extractStackOverflowContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.httpError
        }
        
        var content = "❓ Stack Overflow\n\n"
        
        if let title = ContentParser.extractTitle(from: html) {
            content += "Question: \(title)\n\n"
        }
        
        // Extract question and top answers
        let questionPatterns = [
            "<div[^>]*class=['\"]s-prose[^'\"]*['\"][^>]*>(.*?)</div>",
            "<div[^>]*id=['\"]question-header['\"][^>]*>(.*?)</div>"
        ]
        
        for pattern in questionPatterns {
            if let range = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let questionHTML = String(html[range])
                let questionContent = ContentParser.extractMainContent(from: questionHTML)
                if !questionContent.isEmpty {
                    content += "Q: \(questionContent)\n\n"
                    break
                }
            }
        }
        
        // Extract top answer
        if let answerMatch = html.range(of: "<div[^>]*class=['\"]answer['\"][^>]*>(.*?)</div>", options: [.regularExpression, .caseInsensitive]) {
            let answerHTML = String(html[answerMatch])
            let answerContent = ContentParser.extractMainContent(from: answerHTML)
            if !answerContent.isEmpty {
                content += "A: \(answerContent)\n"
            }
        }
        
        return content
    }
    
    private func extractProductHuntContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.httpError
        }
        
        var content = "🚀 Product Hunt\n\n"
        
        if let title = ContentParser.extractTitle(from: html) {
            content += "Product: \(title)\n\n"
        }
        
        if let description = ContentParser.extractMetaDescription(from: html) {
            content += "Description: \(description)\n\n"
        }
        
        content += ContentParser.extractMainContent(from: html)
        return content
    }
    
    private func extractRedditContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.httpError
        }
        
        var content = "🔗 Reddit Post\n\n"
        
        if let title = ContentParser.extractTitle(from: html) {
            content += "Title: \(title)\n\n"
        }
        
        if let description = ContentParser.extractMetaDescription(from: html) {
            content += description + "\n\n"
        }
        
        content += ContentParser.extractMainContent(from: html)
        return content
    }
    
    private func extractWikipediaContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.httpError
        }
        
        var content = "📚 Wikipedia\n\n"
        
        if let title = ContentParser.extractTitle(from: html) {
            content += "Article: \(title)\n\n"
        }
        
        // Extract main Wikipedia content
        if let mainMatch = html.range(of: "<div[^>]*id=['\"]mw-content-text['\"][^>]*>(.*?)</div>", options: [.regularExpression, .caseInsensitive]) {
            let mainHTML = String(html[mainMatch])
            let mainContent = ContentParser.extractMainContent(from: mainHTML)
            if !mainContent.isEmpty {
                content += mainContent
                return content
            }
        }
        
        content += ContentParser.extractMainContent(from: html)
        return content
    }
    
    private func extractSubstackContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.httpError
        }
        
        var content = "📰 Substack Article\n\n"
        
        if let title = ContentParser.extractTitle(from: html) {
            content += "Title: \(title)\n\n"
        }
        
        if let author = ContentParser.extractAuthor(from: html) {
            content += "Author: \(author)\n\n"
        }
        
        if let date = ContentParser.extractPublishedDate(from: html) {
            content += "Published: \(date)\n\n"
        }
        
        content += ContentParser.extractMainContent(from: html)
        return content
    }
    
    private func extractNotionContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.httpError
        }
        
        var content = "📝 Notion Page\n\n"
        
        if let title = ContentParser.extractTitle(from: html) {
            content += title + "\n\n"
        }
        
        content += ContentParser.extractMainContent(from: html)
        return content
    }
    
    private func extractGoogleDocsContent(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.httpError
        }
        
        var content = "📄 Google Docs\n\n"
        
        if let title = ContentParser.extractTitle(from: html) {
            content += title + "\n\n"
        }
        
        content += ContentParser.extractMainContent(from: html)
        return content
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
    
    private func extractMetaTagContent(from html: String, property: String) -> String? {
        // Extract Open Graph or meta tag content
        let patterns = [
            "<meta[^>]*property=['\"]og:\(property)['\"][^>]*content=['\"]([^'\"]*)['\"]",
            "<meta[^>]*content=['\"]([^'\"]*)['\"][^>]*property=['\"]og:\(property)['\"]"
        ]
        
        for pattern in patterns {
            if let range = html.range(of: pattern, options: String.CompareOptions.regularExpression) {
                let match = String(html[range])
                if let contentRange = match.range(of: "content=['\"]([^'\"]*)['\"]", options: String.CompareOptions.regularExpression) {
                    let content = String(match[contentRange])
                    let cleaned = content.replacingOccurrences(of: "content=['\"]", with: "").replacingOccurrences(of: "['\"]", with: "")
                    return cleaned.isEmpty ? nil : cleaned
                }
            }
        }
        return nil
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

