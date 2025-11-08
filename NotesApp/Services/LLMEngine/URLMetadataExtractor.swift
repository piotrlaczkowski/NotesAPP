import Foundation

// MARK: - URL Metadata Extraction Test Implementation

/// Standalone URL metadata extraction for testing and iteration
/// This will be integrated into the production code after testing

struct URLMetadata: Codable {
    let title: String?
    let description: String?
    let tags: [String]
    
    init(title: String? = nil, description: String? = nil, tags: [String] = []) {
        self.title = title
        self.description = description
        self.tags = tags
    }
}

struct URLMetadataExtractor {
    
    // MARK: - Prompt Builder
    
    static func buildExtractionPrompt(url: URL, content: String, metadata: ContentMetadata?) -> String {
        var prompt = """
        You are an expert assistant at summarising links to projects, papers and code repositories.
        
        Task:
        Given the following link: \(url.absoluteString)
        1. Determine the Title of the project/paper/repo.
        2. Write a short Description: one or two sentences summarising what it does, then one sentence: 'Why it is useful: …'
        3. Provide Tags: 3-8 keywords covering domain, technology, type, and language.
        
        Output exactly in this JSON format (no additional text):
        {
          "title": "<Project Title or null>",
          "description": "<Short summary plus usefulness or null>",
          "tags": [ "tag1", "tag2", ... ]
        }
        
        If you cannot find a field, use null (for title/description) or [] for tags.
        """
        
        if let metadata = metadata {
            let metadataContext = metadata.contextString()
            if !metadataContext.isEmpty {
                prompt += "\n\nAdditional context:\n\(metadataContext)"
            }
        }
        
        // Include content (truncate if too long)
        let contentToInclude = content.count > 4000 ? String(content.prefix(4000)) + "\n\n[... content truncated ...]" : content
        prompt += "\n\nContent extracted from the link:\n\(contentToInclude)"
        
        prompt += "\n\nLink: \(url.absoluteString)"
        
        return prompt
    }
    
    // MARK: - JSON Parser
    
    static func parseJSONResponse(_ response: String) -> URLMetadata? {
        // Try to extract JSON from the response
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to find JSON object in the response
        if let jsonStart = jsonString.range(of: "{"),
           let jsonEnd = jsonString.range(of: "}", options: .backwards) {
            let jsonRange = jsonStart.lowerBound..<jsonEnd.upperBound
            jsonString = String(jsonString[jsonRange])
        }
        
        // Parse JSON
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let metadata = try decoder.decode(URLMetadata.self, from: data)
            return metadata
        } catch {
            print("JSON parsing error: \(error)")
            return nil
        }
    }
    
    // MARK: - Text Fallback Parser
    
    static func parseTextResponse(_ response: String) -> URLMetadata {
        var title: String? = nil
        var description: String? = nil
        var tags: [String] = []
        
        let lines = response.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty {
                continue
            }
            
            // Try to extract title
            if title == nil {
                if trimmed.lowercased().hasPrefix("title:") {
                    title = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if trimmed.lowercased().hasPrefix("📘") || trimmed.lowercased().hasPrefix("title") {
                    title = trimmed.replacingOccurrences(of: "📘", with: "")
                        .replacingOccurrences(of: "Title:", with: "", options: .caseInsensitive)
                        .trimmingCharacters(in: .whitespaces)
                }
            }
            
            // Try to extract description
            if description == nil {
                if trimmed.lowercased().hasPrefix("description:") {
                    description = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
                } else if trimmed.lowercased().hasPrefix("🧠") {
                    description = trimmed.replacingOccurrences(of: "🧠", with: "").trimmingCharacters(in: .whitespaces)
                }
            }
            
            // Try to extract tags
            if trimmed.lowercased().hasPrefix("tags:") {
                let tagsString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                tags = tagsString.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } else if trimmed.lowercased().hasPrefix("🏷️") {
                let tagsString = trimmed.replacingOccurrences(of: "🏷️", with: "").trimmingCharacters(in: .whitespaces)
                tags = tagsString.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }
        
        return URLMetadata(title: title, description: description, tags: tags)
    }
    
    // MARK: - Main Extraction Method
    
    /// Extract metadata from a URL using LLM
    /// This is the method to test and iterate on
    static func extractMetadata(
        from url: URL,
        content: String,
        metadata: ContentMetadata?,
        llmService: LLMService
    ) async throws -> URLMetadata {
        // Build prompt
        let prompt = buildExtractionPrompt(url: url, content: content, metadata: metadata)
        
        // Call LLM
        let response = try await llmService.generateChatResponse(prompt: prompt, context: nil)
        
        // Try JSON parsing first
        if let jsonMetadata = parseJSONResponse(response) {
            return jsonMetadata
        }
        
        // Fallback to text parsing
        return parseTextResponse(response)
    }
}




