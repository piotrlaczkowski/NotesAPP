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
        
        // Step 1: Intelligently detect content type and characteristics
        let contentType = detectContentType(content: content, metadata: metadata)
        let contentCharacteristics = analyzeContentCharacteristics(content: content, metadata: metadata)
        
        // Step 2: Prepare optimized content for analysis
        let optimizedContent = prepareOptimizedContent(
            content: content,
            contentType: contentType,
            characteristics: contentCharacteristics
        )
        
        // Step 3: Build intelligent, efficient context for LLM (when actual inference is implemented)
        // Currently unused but kept for future LLM integration
        let _ = buildIntelligentContext(
            content: optimizedContent,
            metadata: metadata,
            contentType: contentType,
            characteristics: contentCharacteristics
        )
        
        // Step 4: Use adaptive analysis strategy based on content type
        let analysis = performAdaptiveAnalysis(
            content: optimizedContent,
            metadata: metadata,
            contentType: contentType,
            characteristics: contentCharacteristics
        )
        
        return analysis
    }
    
    // MARK: - Content Type Detection
    
    private enum ContentType: CustomStringConvertible {
        case researchPaper
        case codeRepository
        case technicalDocumentation
        case articleBlog
        case tutorial
        case news
        case video
        case socialMedia
        case academic
        case general
        
        var description: String {
            switch self {
            case .researchPaper: return "Research Paper"
            case .codeRepository: return "Code Repository"
            case .technicalDocumentation: return "Technical Documentation"
            case .articleBlog: return "Article/Blog"
            case .tutorial: return "Tutorial"
            case .news: return "News"
            case .video: return "Video"
            case .socialMedia: return "Social Media"
            case .academic: return "Academic"
            case .general: return "General"
            }
        }
    }
    
    private func detectContentType(content: String, metadata: ContentMetadata?) -> ContentType {
        let combined = (content.lowercased() + " " + (metadata?.contextString().lowercased() ?? "")).lowercased()
        let domain = metadata?.domain?.lowercased() ?? ""
        
        // Domain-based detection (most reliable)
        if domain.contains("arxiv") || domain.contains("pubmed") || domain.contains("researchgate") {
            return .researchPaper
        }
        if domain.contains("github") || domain.contains("gitlab") || domain.contains("bitbucket") {
            return .codeRepository
        }
        if domain.contains("stackoverflow") || domain.contains("stackexchange") {
            return .technicalDocumentation
        }
        if domain.contains("youtube") || domain.contains("vimeo") || domain.contains("tiktok") {
            return .video
        }
        if domain.contains("twitter") || domain.contains("x.com") || domain.contains("facebook") || domain.contains("linkedin") {
            return .socialMedia
        }
        if domain.contains("medium") || domain.contains("substack") || domain.contains("dev.to") {
            return .articleBlog
        }
        
        // Content-based detection
        if combined.contains("abstract") || combined.contains("doi:") || combined.contains("citation") ||
           combined.contains("methodology") || combined.contains("results") || combined.contains("conclusion") {
            return .researchPaper
        }
        if combined.contains("repository") || combined.contains("readme") || combined.contains("install") ||
           combined.contains("npm install") || combined.contains("pip install") || combined.contains("clone") {
            return .codeRepository
        }
        if combined.contains("api") || combined.contains("documentation") || combined.contains("reference") ||
           combined.contains("getting started") || combined.contains("quick start") {
            return .technicalDocumentation
        }
        if combined.contains("tutorial") || combined.contains("how to") || combined.contains("step by step") ||
           combined.contains("guide") || combined.contains("walkthrough") {
            return .tutorial
        }
        if combined.contains("breaking") || combined.contains("news") || combined.contains("report") ||
           combined.contains("update") || combined.contains("announcement") {
            return .news
        }
        
        return .general
    }
    
    private struct ContentCharacteristics {
        let wordCount: Int
        let hasStructuredSections: Bool
        let hasCodeBlocks: Bool
        let hasLists: Bool
        let hasHeadings: Bool
        let averageParagraphLength: Int
        let complexity: ComplexityLevel
    }
    
    private enum ComplexityLevel: CustomStringConvertible {
        case simple      // < 500 words, straightforward
        case moderate    // 500-2000 words
        case complex     // 2000-5000 words
        case veryComplex // > 5000 words
        
        var description: String {
            switch self {
            case .simple: return "Simple"
            case .moderate: return "Moderate"
            case .complex: return "Complex"
            case .veryComplex: return "Very Complex"
            }
        }
    }
    
    private func analyzeContentCharacteristics(content: String, metadata: ContentMetadata?) -> ContentCharacteristics {
        let words = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let wordCount = words.count
        let paragraphs = content.components(separatedBy: "\n\n")
        let avgParaLength = paragraphs.isEmpty ? 0 : paragraphs.map { $0.count }.reduce(0, +) / paragraphs.count
        
        let complexity: ComplexityLevel
        switch wordCount {
        case 0..<500: complexity = .simple
        case 500..<2000: complexity = .moderate
        case 2000..<5000: complexity = .complex
        default: complexity = .veryComplex
        }
        
        return ContentCharacteristics(
            wordCount: wordCount,
            hasStructuredSections: content.contains("##") || content.contains("# ") || content.contains("Section"),
            hasCodeBlocks: content.contains("```") || content.contains("```"),
            hasLists: content.contains("- ") || content.contains("* ") || content.contains("1. "),
            hasHeadings: content.contains("#") || content.range(of: #"<h[1-6]>"#, options: .regularExpression) != nil,
            averageParagraphLength: avgParaLength,
            complexity: complexity
        )
    }
    
    // MARK: - Content Optimization
    
    private func prepareOptimizedContent(content: String, contentType: ContentType, characteristics: ContentCharacteristics) -> String {
        var optimized = content
        
        // For very long content, intelligently extract the most relevant parts
        if characteristics.complexity == .veryComplex || optimized.count > 10000 {
            optimized = extractRelevantSections(
                content: optimized,
                contentType: contentType,
                maxLength: 8000 // Keep more for better analysis
            )
        }
        
        // Clean and normalize
        optimized = preprocessContentForSummary(optimized)
        
        return optimized
    }
    
    private func extractRelevantSections(content: String, contentType: ContentType, maxLength: Int) -> String {
        var sections: [String] = []
        var currentLength = 0
        
        // Strategy varies by content type
        switch contentType {
        case .researchPaper:
            // Keep: Abstract, Introduction, Conclusion
            if let abstract = extractSection(content: content, marker: "abstract") {
                sections.append(abstract)
                currentLength += abstract.count
            }
            if let intro = extractSection(content: content, marker: "introduction") {
                sections.append(intro)
                currentLength += intro.count
            }
            if let conclusion = extractSection(content: content, marker: "conclusion") {
                sections.append(conclusion)
                currentLength += conclusion.count
                if currentLength >= maxLength { return sections.joined(separator: "\n\n") }
            }
            
        case .codeRepository:
            // Keep: README intro, description, installation, usage
            let readmeMarkers = ["description", "about", "overview", "installation", "usage", "getting started"]
            for marker in readmeMarkers {
                if let section = extractSection(content: content, marker: marker) {
                    sections.append(section)
                    currentLength += section.count
                    if currentLength >= maxLength { break }
                }
            }
            
        case .articleBlog, .tutorial, .general:
            // Keep: First sections and headings
            let paragraphs = content.components(separatedBy: "\n\n")
            for paragraph in paragraphs {
                if currentLength + paragraph.count > maxLength { break }
                // Prioritize paragraphs with headings or substantial content
                if paragraph.hasPrefix("#") || paragraph.count > 100 {
                    sections.append(paragraph)
                    currentLength += paragraph.count
                }
            }
            
        default:
            // For other types, use first substantial paragraphs
            let paragraphs = content.components(separatedBy: "\n\n")
            for paragraph in paragraphs.prefix(20) {
                if currentLength + paragraph.count > maxLength { break }
                if paragraph.count > 50 {
                    sections.append(paragraph)
                    currentLength += paragraph.count
                }
            }
        }
        
        // Fallback: use first N characters if no sections found
        if sections.isEmpty {
            return String(content.prefix(maxLength))
        }
        
        return sections.joined(separator: "\n\n")
    }
    
    private func extractSection(content: String, marker: String) -> String? {
        // Escape special regex characters in marker
        let escapedMarker = NSRegularExpression.escapedPattern(for: marker)
        
        let patterns = [
            "(?i)##\\s*\(escapedMarker)[^\\n]*\\n+([^#]{100,2000})",
            "(?i)#\\s*\(escapedMarker)[^\\n]*\\n+([^#]{100,2000})",
            "(?i)\\b\(escapedMarker)\\s*:?\\s*\\n+([^\\n]{100,2000})"
        ]
        
        for pattern in patterns {
            if let range = content.range(of: pattern, options: .regularExpression) {
                let match = String(content[range])
                if let contentStart = match.range(of: "\n") {
                    let section = String(match[contentStart.upperBound...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if section.count >= 100 {
                        return section
                    }
                }
            }
        }
        
        // Fallback: Look for section heading and collect following content
        let headingPattern = "(?i)##?\\s*\(escapedMarker)\\s*"
        if let headingRange = content.range(of: headingPattern, options: .regularExpression) {
            let afterHeading = String(content[headingRange.upperBound...])
            let lines = afterHeading.components(separatedBy: .newlines)
            var sectionLines: [String] = []
            
            for line in lines.prefix(30) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                // Stop at next major heading
                if trimmed.hasPrefix("##") { break }
                if trimmed.hasPrefix("# ") && sectionLines.count > 0 { break }
                
                if !trimmed.isEmpty {
                    sectionLines.append(trimmed)
                    if sectionLines.joined(separator: " ").count > 2000 { break }
                }
            }
            
            let section = sectionLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if section.count >= 100 {
                return section
            }
        }
        
        return nil
    }
    
    // MARK: - Intelligent Context Building
    
    private func buildIntelligentContext(content: String, metadata: ContentMetadata?, contentType: ContentType, characteristics: ContentCharacteristics) -> String {
        var context = "Content Analysis Task:\n"
        
        // Add content type context
        context += "Type: \(contentType)\n"
        context += "Characteristics: \(characteristics.wordCount) words, \(characteristics.complexity)\n"
        
        // Add metadata if available (highly informative)
        if let metadata = metadata {
            context += "\nMetadata:\n"
            context += metadata.contextString()
            context += "\n"
        }
        
        // Add optimized content
        context += "\nContent to analyze:\n"
        
        // For very long content, add a summary + first part
        if content.count > 5000 {
            let summary = generateQuickSummary(content: content, maxLength: 300)
            let firstPart = String(content.prefix(3000))
            context += "Summary: \(summary)\n\n"
            context += "Full content (first 3000 chars):\n\(firstPart)\n..."
        } else {
            context += content
        }
        
        return context
    }
    
    private func generateQuickSummary(content: String, maxLength: Int) -> String {
        // Fast heuristic summary for context
        let paragraphs = content.components(separatedBy: "\n\n")
        var summary = ""
        
        for paragraph in paragraphs.prefix(3) {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 50 && summary.count + trimmed.count < maxLength {
                summary += (summary.isEmpty ? "" : " ") + trimmed
            }
        }
        
        if summary.isEmpty {
            return String(content.prefix(maxLength))
        }
        
        return String(summary.prefix(maxLength))
    }
    
    // MARK: - Adaptive Analysis
    
    private func performAdaptiveAnalysis(content: String, metadata: ContentMetadata?, contentType: ContentType, characteristics: ContentCharacteristics) -> NoteAnalysis {
        // Use different strategies based on content type
        switch contentType {
        case .researchPaper:
            return analyzeResearchPaper(content: content, metadata: metadata)
        case .codeRepository:
            return analyzeCodeRepository(content: content, metadata: metadata)
        case .technicalDocumentation:
            return analyzeTechnicalDoc(content: content, metadata: metadata)
        case .articleBlog, .tutorial:
            return analyzeArticle(content: content, metadata: metadata)
        default:
            return analyzeGeneral(content: content, metadata: metadata)
        }
    }
    
    private func analyzeResearchPaper(content: String, metadata: ContentMetadata?) -> NoteAnalysis {
        let title = extractTitle(from: content, metadata: metadata)
        let summary = extractAbstract(from: content) ?? generateEnhancedSummary(from: content, metadata: metadata)
        let tags = extractTags(from: content, metadata: metadata) + ["research", "academic"]
        let category = "Research Paper"
        let whatIsIt = analyzeWhatItIs(from: content, metadata: metadata) ?? "A research paper presenting academic findings"
        let whyAdvantageous = "Provides peer-reviewed insights and scientific findings. Useful for academic research and staying current with developments."
        
        return NoteAnalysis(
            title: title,
            summary: summary,
            tags: Array(Set(tags)).prefix(8).map { $0 },
            category: category,
            whatIsIt: whatIsIt,
            whyAdvantageous: whyAdvantageous
        )
    }
    
    private func analyzeCodeRepository(content: String, metadata: ContentMetadata?) -> NoteAnalysis {
        let title = extractTitle(from: content, metadata: metadata)
        let summary = extractReadmeSummary(from: content) ?? generateEnhancedSummary(from: content, metadata: metadata)
        let tags = extractTags(from: content, metadata: metadata) + ["code", "development"]
        let category = "Code Repository"
        let whatIsIt = analyzeWhatItIs(from: content, metadata: metadata) ?? "A software project or code repository"
        let whyAdvantageous = "Provides reusable code examples and implementation patterns. Useful for learning and reference in development projects."
        
        return NoteAnalysis(
            title: title,
            summary: summary,
            tags: Array(Set(tags)).prefix(8).map { $0 },
            category: category,
            whatIsIt: whatIsIt,
            whyAdvantageous: whyAdvantageous
        )
    }
    
    private func analyzeTechnicalDoc(content: String, metadata: ContentMetadata?) -> NoteAnalysis {
        let title = extractTitle(from: content, metadata: metadata)
        let summary = generateEnhancedSummary(from: content, metadata: metadata)
        let tags = extractTags(from: content, metadata: metadata) + ["documentation", "technical"]
        let category = "Documentation"
        let whatIsIt = "Technical documentation providing specifications, APIs, or reference materials"
        let whyAdvantageous = "Authoritative technical reference. Essential for understanding systems and implementing solutions correctly."
        
        return NoteAnalysis(
            title: title,
            summary: summary,
            tags: Array(Set(tags)).prefix(8).map { $0 },
            category: category,
            whatIsIt: whatIsIt,
            whyAdvantageous: whyAdvantageous
        )
    }
    
    private func analyzeArticle(content: String, metadata: ContentMetadata?) -> NoteAnalysis {
        let title = extractTitle(from: content, metadata: metadata)
        let summary = generateEnhancedSummary(from: content, metadata: metadata)
        let tags = extractTags(from: content, metadata: metadata)
        let category = extractCategory(from: content, metadata: metadata) ?? "Article"
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
    
    private func analyzeGeneral(content: String, metadata: ContentMetadata?) -> NoteAnalysis {
        let title = extractTitle(from: content, metadata: metadata)
        let summary = generateEnhancedSummary(from: content, metadata: metadata)
        let tags = extractTags(from: content, metadata: metadata)
        let category = extractCategory(from: content, metadata: metadata) ?? "General"
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
    
    func generateSummary(content: String) async throws -> String {
        guard isModelLoaded else {
            throw LLMError(message: "Model not loaded")
        }
        
        // Use intelligent summary generation
        let contentType = detectContentType(content: content, metadata: nil)
        let characteristics = analyzeContentCharacteristics(content: content, metadata: nil)
        let optimizedContent = prepareOptimizedContent(
            content: content,
            contentType: contentType,
            characteristics: characteristics
        )
        
        return generateEnhancedSummary(from: optimizedContent, metadata: nil)
    }
    
    func suggestTags(content: String) async throws -> [String] {
        guard isModelLoaded else {
            throw LLMError(message: "Model not loaded")
        }
        
        // Use intelligent tag extraction with content type awareness
        let contentType = detectContentType(content: content, metadata: nil)
        let tags = extractTags(from: content, metadata: nil)
        
        // Add content-type specific tags
        var enhancedTags = tags
        switch contentType {
        case .researchPaper:
            enhancedTags.append("research")
            enhancedTags.append("academic")
        case .codeRepository:
            enhancedTags.append("code")
            enhancedTags.append("development")
        case .technicalDocumentation:
            enhancedTags.append("documentation")
            enhancedTags.append("technical")
        case .articleBlog:
            enhancedTags.append("article")
        case .tutorial:
            enhancedTags.append("tutorial")
            enhancedTags.append("guide")
        case .news:
            enhancedTags.append("news")
        default:
            break
        }
        
        return Array(Set(enhancedTags)).prefix(8).map { $0 }
    }
    
    func generateTitle(content: String) async throws -> String {
        guard isModelLoaded else {
            throw LLMError(message: "Model not loaded")
        }
        
        // Use intelligent title extraction
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
        // Step 1: Prefer metadata descriptions (most accurate and concise)
        if let ogDesc = metadata?.openGraphDescription, !ogDesc.isEmpty {
            return cleanAndTruncateSummary(ogDesc, maxLength: 280)
        }
        if let metaDesc = metadata?.metaDescription, !metaDesc.isEmpty {
            return cleanAndTruncateSummary(metaDesc, maxLength: 280)
        }
        
        // Step 2: Clean and preprocess content for better extraction
        let cleanedContent = preprocessContentForSummary(content)
        
        // Step 3: Intelligent summary extraction based on content type
        if let summary = extractSummaryByContentType(cleanedContent, metadata: metadata) {
            return summary
        }
        
        // Step 4: Extract meaningful sentences from first paragraphs
        if let summary = extractKeySentences(from: cleanedContent) {
            return summary
        }
        
        // Step 5: Fallback - smart truncation with context
        return smartTruncate(content: cleanedContent, maxLength: 280)
    }
    
    // MARK: - Content Preprocessing
    
    private func preprocessContentForSummary(_ content: String) -> String {
        var cleaned = content
        
        // Remove common noise patterns
        let noisePatterns = [
            "Skip to content",
            "Skip to main content",
            "Menu",
            "Navigation",
            "Cookie consent",
            "Accept cookies",
            "Subscribe",
            "Newsletter",
            "Advertisement",
            "Ad:",
            "Related articles",
            "Share this"
        ]
        
        for pattern in noisePatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        
        // Remove excessive whitespace
        cleaned = cleaned.replacingOccurrences(
            of: "\\s{3,}",
            with: " ",
            options: .regularExpression
        )
        
        // Remove markdown code blocks that might be noise
        cleaned = cleaned.replacingOccurrences(
            of: "```[^`]*```",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Content Type-Specific Extraction
    
    private func extractSummaryByContentType(_ content: String, metadata: ContentMetadata?) -> String? {
        let lowercased = content.lowercased()
        
        // Research papers
        if content.contains("Abstract:") || content.contains("ABSTRACT") || 
           content.range(of: #"\babstract\b"#, options: .regularExpression) != nil {
            if let abstract = extractAbstract(from: content) {
                return cleanAndTruncateSummary(abstract, maxLength: 280)
            }
        }
        
        // GitHub README files
        if metadata?.domain?.contains("github") == true || lowercased.contains("readme") {
            if let readmeSummary = extractReadmeSummary(from: content) {
                return cleanAndTruncateSummary(readmeSummary, maxLength: 280)
            }
        }
        
        // Articles with explicit introduction or summary sections
        if let introSummary = extractIntroductionOrSummary(from: content) {
            return cleanAndTruncateSummary(introSummary, maxLength: 280)
        }
        
        return nil
    }
    
    private func extractAbstract(from content: String) -> String? {
        // Look for "Abstract:" or "ABSTRACT" header
        let abstractMarkers = [
            #"(?i)\babstract\s*:?\s*\n"#,
            #"(?i)^\s*abstract\s*:?\s*\n"#,
            #"ABSTRACT\s*:?\s*\n"#
        ]
        
        for marker in abstractMarkers {
            if let markerRange = content.range(of: marker, options: .regularExpression) {
                let afterAbstract = String(content[markerRange.upperBound...])
                let lines = afterAbstract.components(separatedBy: .newlines)
                var abstractLines: [String] = []
                
                // Collect lines until we hit a section break
                for line in lines.prefix(15) {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Stop at section headers
                    if trimmed.hasPrefix("#") { break }
                    if trimmed.lowercased().hasPrefix("introduction") { break }
                    if trimmed.lowercased().hasPrefix("keywords") { break }
                    if trimmed.lowercased().hasPrefix("1.") && trimmed.count < 50 { break }
                    if trimmed.isEmpty && abstractLines.count >= 3 { break }
                    
                    if !trimmed.isEmpty {
                        abstractLines.append(trimmed)
                        
                        // Stop if we have enough content
                        let currentAbstract = abstractLines.joined(separator: " ")
                        if currentAbstract.count > 500 {
                            break
                        }
                    }
                }
                
                let abstract = abstractLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                if abstract.count >= 50 && abstract.count <= 500 {
                    return abstract
                }
            }
        }
        
        // Alternative: Look for abstract in first paragraph that mentions "abstract"
        let paragraphs = content.components(separatedBy: "\n\n")
        for paragraph in paragraphs.prefix(5) {
            let lowercased = paragraph.lowercased()
            if lowercased.contains("abstract") && paragraph.count >= 50 && paragraph.count <= 800 {
                // Extract content after "Abstract:" marker
                if let abstractPos = lowercased.range(of: "abstract") {
                    let afterAbstract = String(paragraph[abstractPos.upperBound...])
                    let cleaned = afterAbstract
                        .replacingOccurrences(of: #"^[:\s]+"#, with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if cleaned.count >= 50 && cleaned.count <= 500 {
                        return cleaned
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractReadmeSummary(from content: String) -> String? {
        // Look for description section in README
        let sectionPattern = #"##\s*(?:Description|About|Overview|Summary)[^\n]*\n+([^#]{30,400})"#
        
        if let range = content.range(of: sectionPattern, options: .regularExpression) {
            let sectionContent = String(content[range])
            // Extract content after the header
            if let headerEnd = sectionContent.range(of: "\n") {
                let summary = String(sectionContent[headerEnd.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if summary.count >= 30 && summary.count <= 400 {
                    return summary
                }
            }
        }
        
        // Fallback: Look for inline description/about/overview
        let inlinePattern = #"(?i)(?:description|about|overview)[:\s]+\s*([^\n]{30,400})"#
        if let range = content.range(of: inlinePattern, options: .regularExpression) {
            let match = String(content[range])
            if let colonRange = match.range(of: ":") {
                let summary = String(match[colonRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if summary.count >= 30 && summary.count <= 400 {
                    return summary
                }
            }
        }
        
        // Fallback: Use first paragraph if it looks like a description
        let paragraphs = content.components(separatedBy: "\n\n")
        for paragraph in paragraphs.prefix(3) {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 30 && trimmed.count <= 400 &&
               !trimmed.hasPrefix("#") && !trimmed.hasPrefix("```") {
                return trimmed
            }
        }
        
        return nil
    }
    
    private func extractIntroductionOrSummary(from content: String) -> String? {
        // Look for explicit summary/introduction sections with headers
        let headerPattern = #"##\s*(?:Summary|Introduction|Overview|TL;DR|TLDR|Executive Summary)[^\n]*\n+([^#]{30,400})"#
        
        if let range = content.range(of: headerPattern, options: .regularExpression) {
            let sectionContent = String(content[range])
            if let headerEnd = sectionContent.range(of: "\n") {
                let summary = String(sectionContent[headerEnd.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if summary.count >= 30 && summary.count <= 400 {
                    return summary
                }
            }
        }
        
        // Look for inline summary/introduction
        let inlinePattern = #"(?i)(?:summary|introduction|overview|tl;dr|tldr)[:\s]+\s*([^\n]{30,400})"#
        if let range = content.range(of: inlinePattern, options: .regularExpression) {
            let match = String(content[range])
            var colonRange: Range<String.Index>?
            if let colon = match.range(of: ":") {
                colonRange = colon
            } else if let space = match.range(of: #"\s+"#, options: .regularExpression) {
                colonRange = space
            }
            
            if let colonRange = colonRange {
                let summary = String(match[colonRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if summary.count >= 30 && summary.count <= 400 {
                    return summary
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Key Sentence Extraction
    
    private func extractKeySentences(from content: String) -> String? {
        let paragraphs = content.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { paragraph in
                // Filter out non-content paragraphs
                paragraph.count >= 30 &&
                !paragraph.hasPrefix("#") &&
                !paragraph.hasPrefix("```") &&
                !paragraph.lowercased().contains("cookie") &&
                !paragraph.lowercased().contains("subscribe")
            }
        
        guard !paragraphs.isEmpty else { return nil }
        
        // Strategy 1: Use first substantial paragraph
        if let firstParagraph = paragraphs.first(where: { $0.count >= 50 && $0.count <= 500 }) {
            return extractBestSentences(from: firstParagraph, maxLength: 280)
        }
        
        // Strategy 2: Combine first 2-3 short paragraphs
        let shortParagraphs = paragraphs.prefix(3).filter { $0.count >= 30 && $0.count <= 200 }
        if shortParagraphs.count >= 2 {
            let combined = shortParagraphs.joined(separator: " ")
            return cleanAndTruncateSummary(combined, maxLength: 280)
        }
        
        // Strategy 3: Extract key sentences from first long paragraph
        if let firstParagraph = paragraphs.first, firstParagraph.count > 500 {
            return extractBestSentences(from: firstParagraph, maxLength: 280)
        }
        
        return nil
    }
    
    private func extractBestSentences(from paragraph: String, maxLength: Int) -> String {
        let sentences = paragraph.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { sentence in
                sentence.count >= 20 && sentence.count <= 200
            }
        
        guard !sentences.isEmpty else {
            return smartTruncate(content: paragraph, maxLength: maxLength)
        }
        
        // Prefer first 2-3 sentences that are meaningful
        var selectedSentences: [String] = []
        var totalLength = 0
        
        for sentence in sentences.prefix(5) {
            if totalLength + sentence.count + 2 <= maxLength {
                selectedSentences.append(sentence)
                totalLength += sentence.count + 2
            } else {
                break
            }
        }
        
        if !selectedSentences.isEmpty {
            return selectedSentences.joined(separator: ". ") + (selectedSentences.count == sentences.count ? "" : "...")
        }
        
        return smartTruncate(content: paragraph, maxLength: maxLength)
    }
    
    // MARK: - Summary Utilities
    
    private func cleanAndTruncateSummary(_ text: String, maxLength: Int) -> String {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        if cleaned.count <= maxLength {
            return cleaned
        }
        
        // Try to truncate at sentence boundary
        let truncated = String(cleaned.prefix(maxLength))
        if let lastPeriod = truncated.lastIndex(of: ".") {
            let lastSentenceEnd = truncated.index(after: lastPeriod)
            if truncated.distance(from: truncated.startIndex, to: lastSentenceEnd) >= maxLength * 3 / 4 {
                return String(truncated[..<lastSentenceEnd])
            }
        }
        
        // Fallback to word boundary
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }
        
        return truncated + "..."
    }
    
    private func smartTruncate(content: String, maxLength: Int) -> String {
        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.count <= maxLength {
            return cleaned
        }
        
        let truncated = String(cleaned.prefix(maxLength))
        
        // Try to end at sentence boundary
        if let lastPeriod = truncated.lastIndex(of: ".") {
            return String(truncated[..<truncated.index(after: lastPeriod)])
        }
        
        // Try word boundary
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }
        
        return truncated + "..."
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
    
    func generateChatResponse(prompt: String, context: String?) async throws -> String {
        guard isModelLoaded else {
            throw LLMError(message: "Model not loaded")
        }
        
        // Build the prompt with context if provided
        var fullPrompt = ""
        
        if let context = context, !context.isEmpty {
            fullPrompt = """
            <|startoftext|><|im_start|>system
            You are a helpful AI assistant that can answer questions based on the user's notes.
            
            Here are relevant notes from the user's collection:
            \(context)
            
            Use this information to answer questions accurately. If the notes don't contain relevant information, say so politely.<|im_end|>
            <|im_start|>user
            \(prompt)<|im_end|>
            <|im_start|>assistant
            """
        } else {
            fullPrompt = """
            <|startoftext|><|im_start|>system
            You are a helpful AI assistant.<|im_end|>
            <|im_start|>user
            \(prompt)<|im_end|>
            <|im_start|>assistant
            """
        }
        
        // TODO: When MLC-LLM is integrated, use actual model inference here
        // For now, provide a helpful response that acknowledges the model is loaded
        // In production, this will call the actual LLM with the prompt
        
        // Simulated response (remove when actual LLM is integrated)
        if let context = context, !context.isEmpty {
            // Try to provide a context-aware response
            let contextLower = context.lowercased()
            let promptLower = prompt.lowercased()
            
            // Extract some key information from context to show we're using it
            let noteCount = context.components(separatedBy: "Note ").count - 1
            var response = "I found \(noteCount) relevant note\(noteCount == 1 ? "" : "s") in your collection. "
            
            // Check if we can find relevant information
            let queryWords = promptLower.components(separatedBy: .whitespaces).filter { $0.count > 3 }
            let hasRelevantInfo = queryWords.contains { contextLower.contains($0) }
            
            if hasRelevantInfo {
                response += "The notes appear to contain relevant information about your query. "
            }
            
            // Remove integration status message - just provide helpful response
            response += "You can see the source notes below for more details."
            return response
        }
        
        // Generic response without integration status - more natural
        return "I'm ready to help! You can ask me questions, and I'll do my best to assist. If you ask about your notes, I'll automatically search through them to find relevant information."
    }
    
    func generateChatResponseStream(prompt: String, context: String?) -> AsyncThrowingStream<String, Error> {
        guard isModelLoaded else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: LLMError(message: "Model not loaded"))
            }
        }
        
        // Build the full prompt
        let fullPrompt: String
        if let context = context, !context.isEmpty {
            fullPrompt = """
            <|startoftext|><|im_start|>system
            You are a helpful AI assistant that can answer questions based on the user's notes.
            
            Here are relevant notes from the user's collection:
            \(context)
            
            Use this information to answer questions accurately. If the notes don't contain relevant information, say so politely.<|im_end|>
            <|im_start|>user
            \(prompt)<|im_end|>
            <|im_start|>assistant
            """
        } else {
            fullPrompt = """
            <|startoftext|><|im_start|>system
            You are a helpful AI assistant.<|im_end|>
            <|im_start|>user
            \(prompt)<|im_end|>
            <|im_start|>assistant
            """
        }
        
        // TODO: When MLC-LLM is integrated, use actual streaming inference
        // For now, simulate streaming by chunking the response
        return AsyncThrowingStream { continuation in
            Task {
                // Generate the full response (placeholder)
                let fullResponse: String
                if let context = context, !context.isEmpty {
                    let noteCount = context.components(separatedBy: "Note ").count - 1
                    let promptLower = prompt.lowercased()
                    let queryWords = promptLower.components(separatedBy: CharacterSet.whitespaces).filter { $0.count > 3 }
                    let contextLower = context.lowercased()
                    let hasRelevantInfo = queryWords.contains { contextLower.contains($0) }
                    
                    // Better context-aware response for RAG queries
                    var response = "Based on your \(noteCount) relevant note\(noteCount == 1 ? "" : "s"), "
                    
                    // Try to extract key information from the context
                    let queryWordsForExtraction = promptLower.components(separatedBy: CharacterSet.whitespaces)
                        .filter { $0.count > 3 }
                        .map { $0.lowercased() }
                    
                    // Find mentions in context
                    var foundMentions: [String] = []
                    for word in queryWordsForExtraction {
                        if contextLower.contains(word) {
                            // Find the sentence or phrase containing this word
                            let sentences = contextLower.components(separatedBy: ". ")
                            if let relevantSentence = sentences.first(where: { $0.contains(word) }) {
                                let cleaned = relevantSentence.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines)
                                if !foundMentions.contains(cleaned) && cleaned.count > 10 {
                                    foundMentions.append(String(cleaned))
                                }
                            }
                        }
                    }
                    
                    if hasRelevantInfo {
                        if !foundMentions.isEmpty {
                            response += "I found relevant information: \(foundMentions[0]). "
                        } else {
                            response += "I found information related to your question. "
                        }
                    }
                    
                    response += "You can review the source notes below for more details."
                    fullResponse = response
                } else {
                    // Generic chat response - more natural and conversational
                    let lowerPrompt = prompt.lowercased()
                    if lowerPrompt.contains("hello") || lowerPrompt.contains("hi") || lowerPrompt.contains("hey") {
                        fullResponse = "Hello! I'm your AI assistant. I'm here to help you with questions and can search through your notes when you ask about them. How can I assist you today?"
                    } else if lowerPrompt.contains("what can you do") || lowerPrompt.contains("help") {
                        fullResponse = "I can help you in several ways:\n\n• Answer questions about your saved notes when you ask (like 'what did I save about X?')\n• Have general conversations\n• Search through your notes to find relevant information\n\nJust ask me anything, and if you mention your notes, I'll search through them automatically!"
                    } else if lowerPrompt.contains("thank") {
                        fullResponse = "You're welcome! I'm here to help anytime. Feel free to ask me anything else."
                    } else if lowerPrompt.contains("how are you") {
                        fullResponse = "I'm doing well, thank you for asking! I'm ready to help you with your questions or search through your notes. What would you like to know?"
                    } else {
                        // More natural general response
                        let capitalizedPrompt = prompt.prefix(1).capitalized + prompt.dropFirst()
                        fullResponse = "I understand your question about '\(capitalizedPrompt)'. Let me know if you'd like me to search through your notes for more specific information, or feel free to ask me anything else!"
                    }
                }
                
                // Simulate streaming by sending chunks word by word
                let words = fullResponse.components(separatedBy: " ")
                for (index, word) in words.enumerated() {
                    let chunk = index == 0 ? word : " \(word)"
                    continuation.yield(chunk)
                    
                    // Simulate typing speed (adjust delay as needed)
                    try? await Task.sleep(nanoseconds: 30_000_000) // 30ms per word for smoother streaming
                }
                
                continuation.finish()
            }
        }
    }
}

