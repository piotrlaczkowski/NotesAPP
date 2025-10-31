import Foundation

// Placeholder implementation - will integrate with actual MLC-LLM framework
class MLCLLMService: LLMService {
    private var modelPath: String?
    private(set) var isModelLoaded = false
    
    func loadModel(modelPath: String) async throws {
        self.modelPath = modelPath
        // TODO: Implement actual model loading with MLC-LLM
        // This will require integrating the MLC-LLM Swift framework
        isModelLoaded = true
    }
    
    func analyzeContent(content: String, metadata: ContentMetadata? = nil) async throws -> NoteAnalysis {
        guard isModelLoaded else {
            throw LLMError(message: "Model not loaded")
        }
        
        // Build enriched context from content and metadata
        let enrichedContext = buildEnrichedContext(content: content, metadata: metadata)
        
        // TODO: Implement actual LLM inference using enrichedContext
        // For now, return enhanced analysis with heuristics using all available information
        let title = extractTitle(from: content, metadata: metadata)
        let summary = generateEnhancedSummary(from: content, metadata: metadata)
        let tags = extractTags(from: content, metadata: metadata)
        let category = extractCategory(from: content, metadata: metadata)
        let whatIsIt = analyzeWhatItIs(from: content, metadata: metadata)
        let whyAdvantageous = analyzeWhyAdvantageous(from: content, category: category, metadata: metadata)
        
        return NoteAnalysis(
            title: title,
            summary: summary,
            tags: tags,
            category: category,
            whatIsIt: whatIsIt,
            whyAdvantageous: whyAdvantageous
        )
    }
    
    private func buildEnrichedContext(content: String, metadata: ContentMetadata?) -> String {
        var context = ""
        
        if let metadata = metadata {
            context += metadata.contextString()
            context += "\n\n"
        }
        
        context += "Content:\n\(content)"
        
        return context
    }
    
    func generateSummary(content: String) async throws -> String {
        guard isModelLoaded else {
            throw LLMError(message: "Model not loaded")
        }
        
        // TODO: Implement actual summary generation
        return String(content.prefix(200))
    }
    
    func suggestTags(content: String) async throws -> [String] {
        guard isModelLoaded else {
            throw LLMError(message: "Model not loaded")
        }
        
        // TODO: Implement actual tag suggestion
        return extractTags(from: content, metadata: nil)
    }
    
    func generateTitle(content: String) async throws -> String {
        guard isModelLoaded else {
            throw LLMError(message: "Model not loaded")
        }
        
        // TODO: Implement actual title generation
        return extractTitle(from: content, metadata: nil)
    }
    
    // Enhanced helper methods that use metadata for better analysis
    private func extractTitle(from content: String, metadata: ContentMetadata?) -> String {
        // Prefer metadata titles (most accurate)
        if let ogTitle = metadata?.openGraphTitle, !ogTitle.isEmpty {
            return String(ogTitle.prefix(100))
        }
        if let pageTitle = metadata?.pageTitle, !pageTitle.isEmpty {
            return String(pageTitle.prefix(100))
        }
        
        // Fallback to content extraction
        let lines = content.components(separatedBy: .newlines)
        let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        return firstLine.isEmpty ? (metadata?.domain ?? "Untitled") : String(firstLine.prefix(100))
    }
    
    private func generateEnhancedSummary(from content: String, metadata: ContentMetadata?) -> String {
        // Prefer metadata descriptions (most accurate)
        if let ogDesc = metadata?.openGraphDescription, !ogDesc.isEmpty {
            return String(ogDesc.prefix(300))
        }
        if let metaDesc = metadata?.metaDescription, !metaDesc.isEmpty {
            return String(metaDesc.prefix(300))
        }
        
        // Extract first meaningful paragraph from content
        let paragraphs = content.components(separatedBy: "\n\n")
        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 50 && !trimmed.hasPrefix("#") {
                return String(trimmed.prefix(300))
            }
        }
        return String(content.prefix(250))
    }
    
    private func extractTags(from content: String, metadata: ContentMetadata?) -> [String] {
        var tags: Set<String> = []
        
        // Add metadata keywords first (most reliable)
        if let metadata = metadata, !metadata.keywords.isEmpty {
            tags.formUnion(metadata.keywords)
        }
        
        let lowercased = content.lowercased()
        let metadataLowercased = metadata?.contextString().lowercased() ?? ""
        let combinedContext = (lowercased + " " + metadataLowercased).lowercased()
        
        // Domain-specific keyword detection using combined context
        if combinedContext.contains("arxiv") || combinedContext.contains("paper") || combinedContext.contains("research") || combinedContext.contains("abstract") {
            tags.insert("research")
            tags.insert("academic")
        }
        if combinedContext.contains("github") || combinedContext.contains("repository") || combinedContext.contains("code") {
            tags.insert("code")
            tags.insert("development")
        }
        if combinedContext.contains("machine learning") || combinedContext.contains("ai") || combinedContext.contains("neural") || combinedContext.contains("deep learning") {
            tags.insert("ai")
            tags.insert("machine-learning")
        }
        if combinedContext.contains("tutorial") || combinedContext.contains("guide") || combinedContext.contains("how to") {
            tags.insert("tutorial")
        }
        if combinedContext.contains("news") || combinedContext.contains("article") || combinedContext.contains("blog") {
            tags.insert("news")
        }
        if combinedContext.contains("documentation") || combinedContext.contains("api") || combinedContext.contains("reference") {
            tags.insert("documentation")
        }
        
        // Use domain hints
        if let domain = metadata?.domain {
            if domain.contains("arxiv") {
                tags.insert("research")
            } else if domain.contains("github") {
                tags.insert("code")
            } else if domain.contains("medium") || domain.contains("substack") {
                tags.insert("article")
            }
        }
        
        return Array(tags).isEmpty ? ["information"] : Array(tags.prefix(8))
    }
    
    private func extractCategory(from content: String, metadata: ContentMetadata?) -> String? {
        // Use OpenGraph type if available (most accurate)
        if let ogType = metadata?.openGraphType {
            switch ogType.lowercased() {
            case "article", "article:article":
                return "Article"
            case "website":
                // Check domain for more specificity
                if let domain = metadata?.domain {
                    if domain.contains("arxiv") {
                        return "Research Paper"
                    } else if domain.contains("github") {
                        return "Code Repository"
                    }
                }
                return "Article"
            default:
                break
            }
        }
        
        let lowercased = content.lowercased()
        let metadataLowercased = metadata?.contextString().lowercased() ?? ""
        let combinedContext = (lowercased + " " + metadataLowercased).lowercased()
        
        // Category detection using combined context
        if combinedContext.contains("arxiv") || combinedContext.contains("abstract") || combinedContext.contains("doi") {
            return "Research Paper"
        }
        if combinedContext.contains("github") || combinedContext.contains("repository") || combinedContext.contains("pull request") || combinedContext.contains("readme") {
            return "Code Repository"
        }
        if combinedContext.contains("tutorial") || combinedContext.contains("guide") || combinedContext.contains("how to") {
            return "Tutorial"
        }
        if combinedContext.contains("blog") || combinedContext.contains("article") || combinedContext.contains("post") || combinedContext.contains("medium") {
            return "Article"
        }
        if combinedContext.contains("documentation") || combinedContext.contains("api") || combinedContext.contains("reference") {
            return "Documentation"
        }
        if combinedContext.contains("news") || combinedContext.contains("breaking") {
            return "News"
        }
        
        // Use domain as hint
        if let domain = metadata?.domain {
            if domain.contains("arxiv") {
                return "Research Paper"
            } else if domain.contains("github") {
                return "Code Repository"
            } else if domain.contains("youtube") || domain.contains("vimeo") {
                return "Video"
            }
        }
        
        return "General"
    }
    
    private func analyzeWhatItIs(from content: String, metadata: ContentMetadata?) -> String? {
        // Use OpenGraph description or meta description if available
        if let ogDesc = metadata?.openGraphDescription, !ogDesc.isEmpty {
            return ogDesc
        }
        if let metaDesc = metadata?.metaDescription, !metaDesc.isEmpty {
            return metaDesc
        }
        
        // Use OpenGraph type
        if let ogType = metadata?.openGraphType {
            switch ogType.lowercased() {
            case "article:article", "article":
                return "An article or blog post"
            case "website":
                return "A website or web page"
            default:
                break
            }
        }
        
        let lowercased = content.lowercased()
        let firstParagraph = content.components(separatedBy: "\n\n").first ?? content
        
        // Try to extract what this content is about
        if lowercased.contains("this paper") || lowercased.contains("we present") || lowercased.contains("we propose") || lowercased.contains("abstract") {
            return "A research paper presenting findings or a novel approach"
        }
        if lowercased.contains("this repository") || lowercased.contains("this project") || lowercased.contains("readme") {
            return "A software project or code repository"
        }
        if firstParagraph.count > 100 {
            // Use first sentence as description
            let sentences = firstParagraph.components(separatedBy: ".")
            if let firstSentence = sentences.first, firstSentence.count > 30 {
                return firstSentence.trimmingCharacters(in: .whitespaces) + "."
            }
        }
        
        // Use domain information
        if let domain = metadata?.domain {
            return "Content from \(domain)"
        }
        
        return "Content extracted from URL"
    }
    
    private func analyzeWhyAdvantageous(from content: String, category: String?, metadata: ContentMetadata?) -> String? {
        let lowercased = content.lowercased()
        
        // Generate context-aware advantages
        var advantages: [String] = []
        
        if category == "Research Paper" {
            advantages.append("Provides academic insights and peer-reviewed findings")
            if lowercased.contains("sota") || lowercased.contains("state-of-the-art") {
                advantages.append("State-of-the-art research with potential applications")
            }
        } else if category == "Code Repository" {
            advantages.append("Reusable code and implementation examples")
            advantages.append("Learning resource for programming techniques")
        } else if category == "Tutorial" {
            advantages.append("Step-by-step learning resource")
            advantages.append("Practical knowledge that can be applied immediately")
        } else if category == "Documentation" {
            advantages.append("Authoritative reference material")
            advantages.append("Technical specifications and best practices")
        } else if category == "News" || category == "Article" {
            advantages.append("Current information and trends")
            advantages.append("Perspectives on recent developments")
        }
        
        // General advantages
        if advantages.isEmpty {
            advantages.append("Valuable information for future reference")
            advantages.append("Can be shared and discussed with others")
        }
        
        return advantages.joined(separator: ". ")
    }
}

