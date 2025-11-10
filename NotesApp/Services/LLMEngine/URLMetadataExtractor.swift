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
        Extract metadata from: \(url.absoluteString)
        
        Return ONLY a JSON object with:
        - title: Exact project/repository/paper name
        - description: Brief overview of what it is and what it does. Include why it's useful with specific details if available.
        - tags: 5-10 relevant keywords
        
        IMPORTANT: The description field must contain ONLY actual information about the resource, NOT any instructions or prompt text.
        
        {
          "title": "...",
          "description": "...",
          "tags": [...]
        }
        """
        
        if let metadata = metadata {
            let metadataContext = metadata.contextString()
            if !metadataContext.isEmpty {
                prompt += "\n\nAdditional context:\n\(metadataContext)"
            }
        }
        
        // Include more content for deeper analysis (increased from 4000 to 6000)
        let maxContentLength = 6000
        let contentToInclude: String
        if content.count > maxContentLength {
            let beginning = String(content.prefix(maxContentLength * 2 / 3))
            let end = String(content.suffix(maxContentLength / 3))
            contentToInclude = "\(beginning)\n\n[... content truncated ...]\n\n\(end)"
        } else {
            contentToInclude = content
        }
        
        prompt += """
        
        Content:
        \(contentToInclude)
        """
        
        return prompt
    }
    
    // MARK: - JSON Parser
    
    static func parseJSONResponse(_ response: String) -> URLMetadata? {
        // Try to extract JSON from the response
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common prompt prefixes that might leak through (more aggressive)
        let promptPrefixes = [
            "You are an expert",
            "Extract comprehensive metadata",
            "Extract metadata from:",
            "CRITICAL:",
            "CRITICAL INSTRUCTIONS:",
            "Remember:",
            "Output exactly",
            "Return ONLY",
            "Output ONLY valid JSON",
            "Do not include",
            "Do not repeat",
            "* What the resource is",
            "What the resource is",
            "A detailed overview",
            "A value proposition section",
            "Return JSON with:",
            "1. title:",
            "2. description:",
            "3. tags:"
        ]
        
        for prefix in promptPrefixes {
            if let range = jsonString.range(of: prefix, options: .caseInsensitive) {
                // Find the first { after this prefix
                if let jsonStart = jsonString.range(of: "{", range: range.upperBound..<jsonString.endIndex) {
                    jsonString = String(jsonString[jsonStart.lowerBound...])
                    break
                }
            }
        }
        
        // Also check if the entire response starts with prompt text before any JSON
        if !jsonString.hasPrefix("{") {
            // Try to find the first { which should be the start of JSON
            if let jsonStart = jsonString.range(of: "{") {
                jsonString = String(jsonString[jsonStart.lowerBound...])
            }
        }
        
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
        
        // Try to find JSON object in the response (look for the first { and matching })
        if let jsonStart = jsonString.range(of: "{"),
           let jsonEnd = findMatchingBrace(in: jsonString, startIndex: jsonStart.lowerBound) {
            let jsonRange = jsonStart.lowerBound..<jsonEnd
            jsonString = String(jsonString[jsonRange])
        }
        
        // Clean up any remaining prompt text
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse JSON
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            var metadata = try decoder.decode(URLMetadata.self, from: data)
            
            // Clean up description field - remove prompt text that leaked through
            if let description = metadata.description {
                let cleaned = cleanDescription(description)
                metadata = URLMetadata(title: metadata.title, description: cleaned, tags: metadata.tags)
            }
            
            return metadata
        } catch {
            print("JSON parsing error: \(error)")
            print("Attempted to parse: \(jsonString.prefix(500))")
            return nil
        }
    }
    
    // Clean description field to remove prompt text
    private static func cleanDescription(_ description: String) -> String? {
        var cleaned = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // First, try to find where actual content starts (after prompt text)
        // Look for common separators that indicate content start
        let contentSeparators = [
            "Why it is useful:",
            "Why it's useful:",
            "This",
            "The",
            "It",
            "NeuralForecast",
            "neuralforecast",
            "GAIA",
            "gaia",
            "Granite",
            "granite",
            "Enterprise",
            "enterprise",
            "Firecrawl",
            "firecrawl",
            "eCeLLM",
            "Mercury",
            "LEANN"
        ]
        
        // Find the earliest content separator
        var earliestContentIndex: String.Index? = nil
        for separator in contentSeparators {
            if let range = cleaned.range(of: separator, options: .caseInsensitive) {
                if earliestContentIndex == nil || range.lowerBound < earliestContentIndex! {
                    earliestContentIndex = range.lowerBound
                }
            }
        }
        
        // If we found a content start point, use everything from there
        if let contentStart = earliestContentIndex {
            let beforeContent = String(cleaned[..<contentStart]).lowercased()
            // Only skip if what comes before is clearly prompt text
            if beforeContent.contains("you are an expert") || 
               beforeContent.contains("extract comprehensive") ||
               beforeContent.contains("critical:") ||
               beforeContent.contains("required:") {
                cleaned = String(cleaned[contentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remove common prompt phrases (but be more careful - only remove if they're at the start)
        let promptPhrases = [
            "You are an expert technical analyst specializing in extracting deep insights about projects, research papers, and code repositories.",
            "You are an expert technical analyst specializing in extracting deep insights",
            "You are an expert technical analyst",
            "Extract comprehensive metadata from this URL",
            "Extract comprehensive metadata",
            "Why it is useful: Why it is useful:",
            "Why it is useful:",
            "* What the resource is and what it does",
            "What the resource is and what it does",
            "* The core technology, approach, or methodology",
            "The core technology, approach, or methodology",
            "* Key features and capabilities",
            "Key features and capabilities",
            "* What problem it solves or what gap it fills",
            "What problem it solves or what gap it fills",
            "- A value proposition section starting with",
            "A value proposition section starting with",
            "that details:",
            "A detailed overview",
            "A value proposition section",
            "CRITICAL: Extract ACTUAL",
            "FORBIDDEN generic phrases",
            "REQUIRED: Extract",
            "Example format:",
            "If you cannot find",
            "NEVER use vague statements",
            "about projects, research papers, and code repositories",
            "specializing in extracting deep insights about projects"
        ]
        
        // Remove prompt phrases, but only if they appear at the start or as whole phrases
        for phrase in promptPhrases {
            let lowerCleaned = cleaned.lowercased()
            let lowerPhrase = phrase.lowercased()
            
            // Remove if at start
            if lowerCleaned.hasPrefix(lowerPhrase) {
                cleaned = String(cleaned.dropFirst(phrase.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            // Remove if appears as a whole phrase (with word boundaries)
            else if let range = cleaned.range(of: phrase, options: .caseInsensitive) {
                let before = String(cleaned[..<range.lowerBound])
                let after = String(cleaned[range.upperBound...])
                // Check if it's a whole phrase (surrounded by spaces/punctuation)
                let charBefore = before.isEmpty ? " " : before.last!
                let charAfter = after.isEmpty ? " " : after.first!
                if charBefore.isWhitespace || charBefore.isPunctuation,
                   charAfter.isWhitespace || charAfter.isPunctuation {
                    cleaned = (before + after).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // Remove instruction patterns at the start
        cleaned = cleaned.replacingOccurrences(of: #"^\s*[-*•]\s*"#, with: "", options: [.regularExpression, .anchored])
        cleaned = cleaned.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: [.regularExpression, .anchored])
        
        // Remove example text in brackets
        cleaned = cleaned.replacingOccurrences(of: #"\[Specific metrics[^\]]*\]"#, with: "", options: [.regularExpression, .caseInsensitive])
        cleaned = cleaned.replacingOccurrences(of: #"\[NOT generic statements[^\]]*\]"#, with: "", options: [.regularExpression, .caseInsensitive])
        cleaned = cleaned.replacingOccurrences(of: #"\[ACTUAL[^\]]*\]"#, with: "", options: [.regularExpression, .caseInsensitive])
        cleaned = cleaned.replacingOccurrences(of: #"\[.*?97%.*?storage.*?\]"#, with: "", options: [.regularExpression, .caseInsensitive])
        
        // Clean up multiple spaces and newlines
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\n\s*\n"#, with: " ", options: .regularExpression)
        
        // Remove leading/trailing whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If we have substantial content (even if it contains some prompt text), try to extract the useful parts
        if cleaned.count > 50 {
            // Try to extract content after "Why it is useful:" if present
            if let usefulRange = cleaned.range(of: "Why it is useful:", options: .caseInsensitive) {
                let usefulPart = String(cleaned[usefulRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if usefulPart.count > 30 {
                    // Clean the useful part
                    var cleanedUseful = usefulPart
                    // Remove example brackets
                    cleanedUseful = cleanedUseful.replacingOccurrences(of: #"\[.*?\]"#, with: "", options: [.regularExpression, .caseInsensitive])
                    cleanedUseful = cleanedUseful.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanedUseful.count > 20 {
                        return cleanedUseful
                    }
                }
            }
            
            // If we have substantial content, return it even if it might have some prompt remnants
            // Better to have something than nothing
            return cleaned
        }
        
        // For shorter content, be more strict
        if cleaned.count < 20 || isPromptText(cleaned) {
            return nil
        }
        
        return cleaned.isEmpty ? nil : cleaned
    }
    
    // Helper to detect if text looks like prompt instructions
    private static func isPromptText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let promptKeywords = [
            "do not include",
            "do not repeat",
            "do not use",
            "forbidden",
            "required:",
            "critical:",
            "example format",
            "if you cannot find",
            "never use",
            "output exactly",
            "return only",
            "remember:",
            "the description field must",
            "you are an expert technical analyst"
        ]
        
        // If text contains multiple prompt keywords AND is short, it's likely prompt text
        let keywordCount = promptKeywords.filter { lowercased.contains($0) }.count
        // Be more lenient - only reject if it's clearly just instructions
        return keywordCount >= 3 || (keywordCount >= 2 && text.count < 50)
    }
    
    // Helper to find where actual content starts (after prompt text)
    private static func findContentStart(in text: String) -> String.Index? {
        // Look for common content start patterns
        let contentStarters = [
            "neuralforecast",
            "gaia",
            "granite",
            "enterprise",
            "firecrawl",
            "eCeLLM",
            "Mercury",
            "LEANN",
            "This",
            "The",
            "A ",
            "An ",
            "It ",
            "NeuralForecast",
            "GAIA"
        ]
        
        for starter in contentStarters {
            if let range = text.range(of: starter, options: .caseInsensitive) {
                // Check if this looks like actual content (not in a bullet point or instruction)
                let beforeStart = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if beforeStart.isEmpty || beforeStart.hasSuffix(":") || beforeStart.hasSuffix("-") {
                    return range.lowerBound
                }
            }
        }
        
        return nil
    }
    
    // Helper to find matching closing brace
    private static func findMatchingBrace(in string: String, startIndex: String.Index) -> String.Index? {
        var depth = 0
        var index = startIndex
        
        while index < string.endIndex {
            let char = string[index]
            if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    return string.index(after: index)
                }
            }
            index = string.index(after: index)
        }
        
        return nil
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





