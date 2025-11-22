import Foundation

// MARK: - URL Metadata Extraction Test Implementation

/// Standalone URL metadata extraction for testing and iteration
/// This will be integrated into the production code after testing

struct URLMetadata: Codable {
    let title: String?
    let summary: String?
    let tags: [String]
    let category: String?
    let whatIsIt: String?
    let whyAdvantageous: String?
    
    // Legacy support for description field if needed, but we prefer specific fields
    var description: String? { summary }
    
    init(title: String? = nil, summary: String? = nil, tags: [String] = [], category: String? = nil, whatIsIt: String? = nil, whyAdvantageous: String? = nil) {
        self.title = title
        self.summary = summary
        self.tags = tags
        self.category = category
        self.whatIsIt = whatIsIt
        self.whyAdvantageous = whyAdvantageous
    }
}

struct URLMetadataExtractor {
    
    // MARK: - Prompt Builder
    
    static func buildExtractionPrompt(url: URL, content: String, metadata: ContentMetadata?) -> String {
        // Detect content type for better context
        let isArxiv = url.absoluteString.contains("arxiv.org")
        let isGitHub = url.absoluteString.contains("github.com")
        let isPaper = isArxiv || url.absoluteString.contains("paper") || content.lowercased().contains("abstract")
        
        var prompt = """
        You are an expert assistant specialized in reading and extracting information from web content, including research papers, blog posts, documentation pages, and technical articles.
        
        You will be given content from a URL. Your job is to:
        1. Read and understand the text, focusing on the main body
        2. Use both the page content and URL metadata to understand context
        3. Produce a concise, high-value analysis that is useful for a technically literate reader
        
        URL: \(url.absoluteString)
        
        """
        
        // Add context-specific guidance
        if isPaper {
            prompt += """
            This appears to be a RESEARCH PAPER. Focus on:
            - The problem being addressed and why it matters
            - The proposed approach or method (high-level, not implementation details)
            - Key findings, results, or contributions
            - How it differs from or improves upon previous work
            - Practical implications or applications
            
            """
        } else if isGitHub {
            prompt += """
            This appears to be a CODE REPOSITORY. Focus on:
            - What the library/framework/tool does
            - Key features and capabilities
            - What problems it solves or what it enables
            - Who would use it and for what purposes
            - How it compares to alternatives (if mentioned)
            
            """
        }
        
        prompt += """
        YOUR TASKS:
        
        Using the content and context of the page, extract and generate the following:
        
        1. TITLE
           - Extract the exact, official title of the resource
           - For papers: The paper title
           - For repos: The repository name
           - For articles: The article headline
        
        2. SUMMARY (CRITICAL - This is NOT just copying the abstract!)
           - Write a SYNTHESIZED summary in YOUR OWN WORDS (3-5 sentences)
           - Explain the MAIN IDEAS at a high level
           - Focus on: What is being proposed/explained, HOW it works conceptually, and WHY it matters
           - For research papers: Problem → Method → Key findings → Significance
           - For tools/libraries: What it does → How it helps → Why use it
           - DO NOT just copy-paste the abstract or introduction
           - ANALYZE and SYNTHESIZE the information
        
        3. WHAT IS IT?
           - Explain clearly what this resource is (1-2 sentences)
           - Specify the TYPE: research paper, blog post, documentation, library, framework, tool, etc.
           - Identify the DOMAIN/TOPIC: e.g., "large language models", "computer vision", "distributed systems"
           - Mention KEY CONCEPTS or techniques: e.g., "mixture of experts", "attention mechanism", "RAG"
           - For papers: State the problem being addressed and the proposed approach
        
        4. WHY IS THIS USEFUL? (CRITICAL - Be SPECIFIC and CONCRETE!)
           - Explain the PRACTICAL VALUE in 2-4 points
           - WHO BENEFITS: Which profiles (ML researchers, data scientists, engineers, specific domain practitioners)?
           - USE CASES: What can someone DO with these ideas/techniques/results?
           - CONCRETE SCENARIOS: Give 2-3 realistic examples where this would be directly useful
           - SPECIFIC ADVANTAGES: What makes this better/different/novel?
           - Include any mentioned metrics, benchmarks, or performance improvements
           - AVOID generic phrases like "innovative", "state-of-the-art", "comprehensive"
           - BE CONCRETE: "Reduces memory usage by 50%", "Enables offline processing", "First to combine X with Y"
        
        5. CATEGORY
           - Choose ONE: Research Paper, Code Repository, Article, Tool, Documentation, Tutorial, Other
        
        6. TAGS
           - Provide 5-8 relevant keywords
           - Include: domain (e.g., machine-learning, nlp), technologies (e.g., transformers, pytorch), concepts (e.g., attention, rag)
        
        OUTPUT FORMAT (JSON only, no markdown, no code blocks):
        {
          "title": "exact title here",
          "summary": "YOUR SYNTHESIZED summary in your own words - NOT a copy of the abstract",
          "whatIsIt": "clear explanation of what this resource is, its type, domain, and key concepts",
          "whyAdvantageous": "specific, concrete practical value with use cases, who benefits, and realistic scenarios",
          "category": "Category Name",
          "tags": ["tag1", "tag2", "tag3", "tag4", "tag5"]
        }
        
        CRITICAL INSTRUCTIONS:
        - ANALYZE and SYNTHESIZE - do not just extract or copy text
        - Your summary should demonstrate UNDERSTANDING, not just information retrieval
        - Be SPECIFIC and CONCRETE in the "whyAdvantageous" field
        - Focus on PRACTICAL VALUE and REAL-WORLD APPLICATIONS
        - Avoid marketing language and generic superlatives
        
        """
        
        // Add metadata context
        if let metadata = metadata {
            let metadataContext = metadata.contextString()
            if !metadataContext.isEmpty {
                prompt += "\nMETADATA:\n\(metadataContext)\n\n"
            }
        }
        
        // Provide substantial content for analysis
        let maxContentLength = isPaper ? 8000 : 5000
        let contentToInclude: String
        if content.count > maxContentLength {
            if isPaper {
                // For papers: Prioritize abstract, introduction, and conclusion
                let beginning = String(content.prefix(maxContentLength * 3 / 4))
                let end = String(content.suffix(maxContentLength / 4))
                contentToInclude = "\(beginning)\n\n[... middle sections truncated ...]\n\n\(end)"
            } else {
                let beginning = String(content.prefix(maxContentLength * 2 / 3))
                let end = String(content.suffix(maxContentLength / 3))
                contentToInclude = "\(beginning)\n\n[... content truncated ...]\n\n\(end)"
            }
        } else {
            contentToInclude = content
        }
        
        prompt += """
        CONTENT TO ANALYZE:
        \(contentToInclude)
        
        Now, analyze this content deeply and produce the JSON output.
        Remember:
        - SYNTHESIZE the summary in your own words
        - Be SPECIFIC about practical value
        - Focus on UNDERSTANDING and ANALYSIS, not just extraction
        
        Return ONLY the JSON object:
        """
        
        return prompt
    }
    
    // MARK: - JSON Parser
    
    static func parseJSONResponse(_ response: String) -> URLMetadata? {
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let jsonStart = jsonString.range(of: "{"),
           let jsonEnd = jsonString.range(of: "}", options: .backwards) {
            let jsonRange = jsonStart.lowerBound..<jsonEnd.upperBound
            jsonString = String(jsonString[jsonRange])
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(URLMetadata.self, from: data)
        } catch {
            // Try manual parsing if Codable fails
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let title = json["title"] as? String
                let summary = (json["summary"] as? String) ?? (json["description"] as? String)
                let tags = json["tags"] as? [String] ?? []
                let category = json["category"] as? String
                let whatIsIt = json["whatIsIt"] as? String
                let whyAdvantageous = json["whyAdvantageous"] as? String
                
                return URLMetadata(
                    title: title,
                    summary: summary,
                    tags: tags,
                    category: category,
                    whatIsIt: whatIsIt,
                    whyAdvantageous: whyAdvantageous
                )
            }
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
        var summary: String? = nil
        var tags: [String] = []
        var category: String? = nil
        var whatIsIt: String? = nil
        var whyAdvantageous: String? = nil
        
        let lines = response.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty {
                continue
            }
            
            let lower = trimmed.lowercased()
            
            if title == nil && (lower.hasPrefix("title:") || lower.hasPrefix("1. title:")) {
                title = getValue(from: trimmed, prefix: "title:")
            }
            
            if summary == nil && (lower.hasPrefix("summary:") || lower.hasPrefix("2. summary:")) {
                summary = getValue(from: trimmed, prefix: "summary:")
            }
            
            if whatIsIt == nil && (lower.hasPrefix("what is it:") || lower.hasPrefix("3. what is it:")) {
                whatIsIt = getValue(from: trimmed, prefix: "what is it:")
            }
            
            if whyAdvantageous == nil && (lower.hasPrefix("why it is useful:") || lower.hasPrefix("4. why it is useful:")) {
                whyAdvantageous = getValue(from: trimmed, prefix: "why it is useful:")
            }
            
            if category == nil && (lower.hasPrefix("category:") || lower.hasPrefix("5. category:")) {
                category = getValue(from: trimmed, prefix: "category:")
            }
            
            if lower.hasPrefix("tags:") || lower.hasPrefix("6. tags:") {
                let tagsString = getValue(from: trimmed, prefix: "tags:") ?? ""
                tags = tagsString.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }
        
        return URLMetadata(
            title: title,
            summary: summary,
            tags: tags,
            category: category,
            whatIsIt: whatIsIt,
            whyAdvantageous: whyAdvantageous
        )
    }
    
    private static func getValue(from line: String, prefix: String) -> String? {
        if let range = line.range(of: prefix, options: .caseInsensitive) {
            return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return nil
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





