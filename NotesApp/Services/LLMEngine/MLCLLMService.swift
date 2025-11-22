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
        
        // Use URLMetadataExtractor logic (aligned with tests)
        if let url = metadata?.url {
            do {
                let extracted = try await URLMetadataExtractor.extractMetadata(
                    from: url,
                    content: content,
                    metadata: metadata,
                    llmService: self
                )
                
                // Use extracted fields directly, with better fallbacks
                let finalSummary = extracted.summary ?? metadata?.openGraphDescription ?? metadata?.metaDescription ?? "No summary available"
                let finalWhatIsIt = extracted.whatIsIt ?? extracted.summary ?? metadata?.openGraphDescription ?? "Content from \(url.host ?? "web")"
                let finalWhyAdvantageous = extracted.whyAdvantageous ?? "Reference material worth reviewing"
                
                return NoteAnalysis(
                    title: extracted.title ?? metadata?.pageTitle ?? "Untitled",
                    summary: finalSummary,
                    tags: extracted.tags.isEmpty ? (metadata?.keywords ?? []) : extracted.tags,
                    category: extracted.category ?? "General",
                    whatIsIt: finalWhatIsIt,
                    whyAdvantageous: finalWhyAdvantageous
                )
            } catch {
                print("Extraction failed: \(error)")
                // Fallback below with metadata
            }
        }
        
        // Fallback to metadata-based analysis if extraction fails or no URL
        let title = metadata?.pageTitle ?? metadata?.openGraphTitle ?? "Untitled"
        let summary = metadata?.openGraphDescription ?? metadata?.metaDescription ?? String(content.prefix(200))
        let tags = metadata?.keywords ?? []
        
        return NoteAnalysis(
            title: title,
            summary: summary,
            tags: tags,
            category: "General",
            whatIsIt: metadata?.openGraphDescription ?? "Content",
            whyAdvantageous: "Reference material"
        )
    }
    
    /// Build comprehensive context with ALL available information for LLM
    private func buildComprehensiveContext(
        content: String,
        fullContent: String,
        metadata: ContentMetadata?,
        contentType: ContentType,
        characteristics: ContentCharacteristics
    ) -> String {
        var context = "=== COMPREHENSIVE CONTENT ANALYSIS ===\n\n"
        
        // Add metadata information (very valuable for LLM)
        if let metadata = metadata {
            context += "METADATA:\n"
            if let title = metadata.pageTitle, !title.isEmpty {
                context += "Page Title: \(title)\n"
            }
            if let ogTitle = metadata.openGraphTitle, !ogTitle.isEmpty {
                context += "OpenGraph Title: \(ogTitle)\n"
            }
            if let ogDesc = metadata.openGraphDescription, !ogDesc.isEmpty {
                context += "OpenGraph Description: \(ogDesc)\n"
            }
            if let metaDesc = metadata.metaDescription, !metaDesc.isEmpty {
                context += "Meta Description: \(metaDesc)\n"
            }
            if let domain = metadata.domain, !domain.isEmpty {
                context += "Domain: \(domain)\n"
            }
            context += "URL: \(metadata.url.absoluteString)\n"
            if let ogType = metadata.openGraphType, !ogType.isEmpty {
                context += "Content Type (OpenGraph): \(ogType)\n"
            }
            if !metadata.keywords.isEmpty {
                context += "Keywords: \(metadata.keywords.joined(separator: ", "))\n"
            }
            context += "\n"
        }
        
        // Add content type and characteristics
        context += "CONTENT ANALYSIS:\n"
        context += "Detected Type: \(contentType)\n"
        context += "Word Count: \(characteristics.wordCount)\n"
        context += "Complexity: \(characteristics.complexity)\n"
        context += "Has Structured Sections: \(characteristics.hasStructuredSections)\n"
        context += "Has Code Blocks: \(characteristics.hasCodeBlocks)\n"
        context += "Has Lists: \(characteristics.hasLists)\n"
        context += "\n"
        
        // Add full content (or substantial portion)
        context += "FULL CONTENT:\n"
        // Include more content for better analysis - up to 8000 chars
        let contentToInclude: String
        if fullContent.count > 8000 {
            // Include beginning, middle sections, and end for comprehensive view
            let beginning = String(fullContent.prefix(3000))
            let middleStart = fullContent.index(fullContent.startIndex, offsetBy: fullContent.count / 2 - 1000)
            let middleEnd = fullContent.index(middleStart, offsetBy: 2000)
            let middle = String(fullContent[middleStart..<middleEnd])
            let end = String(fullContent.suffix(2000))
            contentToInclude = "\(beginning)\n\n[... middle section ...]\n\n\(middle)\n\n[... end section ...]\n\n\(end)"
        } else {
            contentToInclude = fullContent
        }
        context += contentToInclude
        context += "\n\n"
        
        // Add key sections if available
        if characteristics.hasStructuredSections {
            context += "KEY SECTIONS DETECTED:\n"
            // Extract section headers
            let lines = fullContent.components(separatedBy: .newlines)
            var sectionHeaders: [String] = []
            for line in lines {
                if line.hasPrefix("#") || line.hasPrefix("##") || line.hasPrefix("###") {
                    sectionHeaders.append(line.trimmingCharacters(in: .whitespaces))
                    if sectionHeaders.count >= 10 {
                        break
                    }
                }
            }
            if !sectionHeaders.isEmpty {
                context += sectionHeaders.joined(separator: "\n")
                context += "\n"
            }
        }
        
        return context
    }
    
    /// Parse comprehensive LLM response into NoteAnalysis
    private func parseComprehensiveLLMResponse(
        llmResponse: String,
        content: String,
        metadata: ContentMetadata?,
        contentType: ContentType
    ) -> NoteAnalysis {
        var summary = ""
        var whatIsIt: String? = nil
        var whyAdvantageous: String? = nil
        var category: String? = nil
        var tags: [String] = []
        
        // Parse structured response
        let lines = llmResponse.components(separatedBy: .newlines)
        var currentSection: String? = nil
        var currentContent = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }
            
            // Check for section headers
            if trimmed.uppercased().hasPrefix("SUMMARY:") {
                if let prevSection = currentSection, !currentContent.isEmpty {
                    assignToSection(prevSection, content: currentContent, summary: &summary, whatIsIt: &whatIsIt, whyAdvantageous: &whyAdvantageous, category: &category, tags: &tags)
                }
                currentSection = "SUMMARY"
                currentContent = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.uppercased().hasPrefix("WHAT_IS_IT:") || trimmed.uppercased().hasPrefix("WHAT IS IT:") {
                if let prevSection = currentSection, !currentContent.isEmpty {
                    assignToSection(prevSection, content: currentContent, summary: &summary, whatIsIt: &whatIsIt, whyAdvantageous: &whyAdvantageous, category: &category, tags: &tags)
                }
                currentSection = "WHAT_IS_IT"
                let prefix = trimmed.uppercased().hasPrefix("WHAT_IS_IT:") ? "WHAT_IS_IT:" : "WHAT IS IT:"
                currentContent = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.uppercased().hasPrefix("WHY_IMPORTANT:") || trimmed.uppercased().hasPrefix("WHY IMPORTANT:") || trimmed.uppercased().hasPrefix("WHY IS IT IMPORTANT:") {
                if let prevSection = currentSection, !currentContent.isEmpty {
                    assignToSection(prevSection, content: currentContent, summary: &summary, whatIsIt: &whatIsIt, whyAdvantageous: &whyAdvantageous, category: &category, tags: &tags)
                }
                currentSection = "WHY_IMPORTANT"
                let prefix = trimmed.uppercased().hasPrefix("WHY_IMPORTANT:") ? "WHY_IMPORTANT:" : (trimmed.uppercased().hasPrefix("WHY IMPORTANT:") ? "WHY IMPORTANT:" : "WHY IS IT IMPORTANT:")
                currentContent = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.uppercased().hasPrefix("CATEGORY:") {
                if let prevSection = currentSection, !currentContent.isEmpty {
                    assignToSection(prevSection, content: currentContent, summary: &summary, whatIsIt: &whatIsIt, whyAdvantageous: &whyAdvantageous, category: &category, tags: &tags)
                }
                currentSection = "CATEGORY"
                currentContent = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.uppercased().hasPrefix("TAGS:") {
                if let prevSection = currentSection, !currentContent.isEmpty {
                    assignToSection(prevSection, content: currentContent, summary: &summary, whatIsIt: &whatIsIt, whyAdvantageous: &whyAdvantageous, category: &category, tags: &tags)
                }
                currentSection = "TAGS"
                currentContent = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if currentSection != nil {
                // Continue current section
                currentContent += (currentContent.isEmpty ? "" : " ") + trimmed
            }
        }
        
        // Assign last section
        if let lastSection = currentSection, !currentContent.isEmpty {
            assignToSection(lastSection, content: currentContent, summary: &summary, whatIsIt: &whatIsIt, whyAdvantageous: &whyAdvantageous, category: &category, tags: &tags)
        }
        
        // Fallback values if LLM didn't provide them
        if summary.isEmpty {
            summary = generateEnhancedSummary(from: content, metadata: metadata)
        }
        if whatIsIt == nil {
            whatIsIt = analyzeWhatItIs(from: content, metadata: metadata)
        }
        if whyAdvantageous == nil {
            whyAdvantageous = analyzeWhyAdvantageous(from: content, category: category, metadata: metadata)
        }
        if category == nil {
            category = extractCategory(from: content, metadata: metadata) ?? contentType.description
        }
        if tags.isEmpty {
            tags = Array(Set(extractTags(from: content, metadata: metadata))).prefix(8).map { $0 }
        }
        
        // Extract title
        let title = extractTitle(from: content, metadata: metadata)
        
        return NoteAnalysis(
            title: title,
            summary: summary,
            tags: tags,
            category: category,
            whatIsIt: whatIsIt,
            whyAdvantageous: whyAdvantageous
        )
    }
    
    /// Helper to assign parsed content to appropriate section
    private func assignToSection(
        _ section: String,
        content: String,
        summary: inout String,
        whatIsIt: inout String?,
        whyAdvantageous: inout String?,
        category: inout String?,
        tags: inout [String]
    ) {
        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        switch section.uppercased() {
        case "SUMMARY":
            summary = String(cleaned.prefix(300))
        case "WHAT_IS_IT":
            whatIsIt = String(cleaned.prefix(150))
        case "WHY_IMPORTANT":
            whyAdvantageous = String(cleaned.prefix(400))
        case "CATEGORY":
            category = cleaned
        case "TAGS":
            tags = cleaned.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        default:
            break
        }
    }
    
    /// Fallback analysis if LLM fails
    private func performFallbackAnalysis(
        content: String,
        metadata: ContentMetadata?,
        contentType: ContentType
    ) -> NoteAnalysis {
        let title = extractTitle(from: content, metadata: metadata)
        let summary = generateEnhancedSummary(from: content, metadata: metadata)
        let tags = extractTags(from: content, metadata: metadata)
        let category = extractCategory(from: content, metadata: metadata) ?? contentType.description
        let whatIsIt = analyzeWhatItIs(from: content, metadata: metadata)
        let whyAdvantageous = analyzeWhyAdvantageous(from: content, category: category, metadata: metadata)
        
        return NoteAnalysis(
            title: title,
            summary: summary,
            tags: Array(Set(tags)).prefix(8).map { $0 },
            category: category,
            whatIsIt: whatIsIt,
            whyAdvantageous: whyAdvantageous
        )
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
            return cleanAndTruncateSummary(ogDesc, maxLength: 300)
        }
        if let metaDesc = metadata?.metaDescription, !metaDesc.isEmpty {
            return cleanAndTruncateSummary(metaDesc, maxLength: 300)
        }
        
        // Step 2: Clean and preprocess content for better extraction
        let cleanedContent = preprocessContentForSummary(content)
        
        // Step 3: Intelligent summary extraction based on content type
        if let summary = extractSummaryByContentType(cleanedContent, metadata: metadata) {
            return summary
        }
        
        // Step 4: Extract meaningful sentences from first paragraphs (improved)
        if let summary = extractKeySentences(from: cleanedContent) {
            return summary
        }
        
        // Step 5: Enhanced fallback - extract key information with context
        let enhancedSummary = extractEnhancedSummary(from: cleanedContent)
        if !enhancedSummary.isEmpty {
            return enhancedSummary
        }
        
        // Step 6: Final fallback - smart truncation with context
        return smartTruncate(content: cleanedContent, maxLength: 300)
    }
    
    /// Extract enhanced summary with key information and context
    private func extractEnhancedSummary(from content: String) -> String {
        var summaryParts: [String] = []
        
        // Extract key sections
        let sections = content.components(separatedBy: "\n\n")
        
        // Look for key indicators
        for section in sections.prefix(5) {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count < 50 || trimmed.count > 500 {
                continue
            }
            
            let lowercased = trimmed.lowercased()
            
            // Prioritize sections with key information
            if lowercased.contains("summary") || 
               lowercased.contains("overview") ||
               lowercased.contains("introduction") ||
               lowercased.contains("about") ||
               lowercased.contains("description") {
                summaryParts.append(trimmed)
                if summaryParts.joined(separator: " ").count > 250 {
                    break
                }
            }
        }
        
        // If we found key sections, use them
        if !summaryParts.isEmpty {
            let combined = summaryParts.joined(separator: " ")
            return cleanAndTruncateSummary(combined, maxLength: 300)
        }
        
        // Otherwise, extract first meaningful paragraphs
        var meaningfulParagraphs: [String] = []
        for section in sections.prefix(3) {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 50 && trimmed.count < 400 {
                // Skip common noise
                let lowercased = trimmed.lowercased()
                if !lowercased.hasPrefix("skip") &&
                   !lowercased.hasPrefix("menu") &&
                   !lowercased.hasPrefix("cookie") &&
                   !lowercased.contains("subscribe") &&
                   !lowercased.contains("newsletter") {
                    meaningfulParagraphs.append(trimmed)
                }
            }
        }
        
        if !meaningfulParagraphs.isEmpty {
            let combined = meaningfulParagraphs.joined(separator: " ")
            return cleanAndTruncateSummary(combined, maxLength: 300)
        }
        
        return ""
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
        // Use OpenGraph description or meta description if available (most accurate)
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
        
        // Enhanced content type detection with more context
        if lowercased.contains("this paper") || lowercased.contains("we present") || lowercased.contains("we propose") || lowercased.contains("abstract") {
            // Try to extract the main topic from abstract or introduction
            if let abstract = extractAbstract(from: content) {
                let sentences = abstract.components(separatedBy: ".")
                if let firstSentence = sentences.first, firstSentence.count > 30 && firstSentence.count < 200 {
                    return firstSentence.trimmingCharacters(in: .whitespaces) + "."
                }
            }
            return "A research paper presenting findings or a novel approach"
        }
        
        if lowercased.contains("this repository") || lowercased.contains("this project") || lowercased.contains("readme") {
            // Try to extract project description from README
            let readmeLines = content.components(separatedBy: .newlines)
            for line in readmeLines.prefix(20) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.count > 30 && trimmed.count < 200 && 
                   !trimmed.lowercased().hasPrefix("#") &&
                   !trimmed.lowercased().contains("license") &&
                   !trimmed.lowercased().contains("copyright") {
                    return trimmed
                }
            }
            return "A software project or code repository"
        }
        
        // Extract from first meaningful paragraph
        if firstParagraph.count > 50 {
            // Clean the paragraph
            let cleaned = firstParagraph
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Use first sentence if it's meaningful
            let sentences = cleaned.components(separatedBy: ".")
            for sentence in sentences {
                let trimmed = sentence.trimmingCharacters(in: .whitespaces)
                if trimmed.count > 30 && trimmed.count < 200 {
                    // Skip common noise
                    if !trimmed.lowercased().hasPrefix("skip") &&
                       !trimmed.lowercased().hasPrefix("menu") &&
                       !trimmed.lowercased().hasPrefix("cookie") {
                        return trimmed + "."
                    }
                }
            }
        }
        
        // Use domain information with more context
        if let domain = metadata?.domain {
            if domain.contains("github") {
                return "A GitHub repository or code project"
            } else if domain.contains("arxiv") {
                return "A research paper from arXiv"
            } else if domain.contains("medium") || domain.contains("substack") {
                return "An article or blog post"
            } else {
                return "Content from \(domain)"
            }
        }
        
        return "Content extracted from URL"
    }
    
    private func analyzeWhyAdvantageous(from content: String, category: String?, metadata: ContentMetadata?) -> String? {
        let lowercased = content.lowercased()
        var advantages: [String] = []
        
        // Extract specific benefits from content
        // Look for key phrases that indicate value
        let valueIndicators = [
            ("breakthrough", "Presents breakthrough findings or innovations"),
            ("state-of-the-art", "State-of-the-art approach or technology"),
            ("sota", "State-of-the-art research with cutting-edge results"),
            ("best practice", "Demonstrates best practices and proven methods"),
            ("solution", "Provides practical solutions to common problems"),
            ("framework", "Offers a reusable framework or methodology"),
            ("tutorial", "Step-by-step guide that can be immediately applied"),
            ("reference", "Comprehensive reference material for future use"),
            ("case study", "Real-world case study with actionable insights"),
            ("comparison", "Comparative analysis helping make informed decisions"),
            ("trend", "Current trends and future directions in the field"),
            ("innovation", "Innovative approach or novel technique"),
            ("performance", "Performance improvements or optimizations"),
            ("scalable", "Scalable solution applicable to various contexts"),
            ("open source", "Open source resource that can be freely used and modified")
        ]
        
        for (keyword, advantage) in valueIndicators {
            if lowercased.contains(keyword) {
                advantages.append(advantage)
            }
        }
        
        // Category-specific advantages with content analysis
        if let category = category {
            switch category {
            case "Research Paper":
                advantages.append("Provides peer-reviewed academic insights")
                if lowercased.contains("experiment") || lowercased.contains("study") {
                    advantages.append("Empirical evidence and experimental validation")
                }
                if lowercased.contains("method") || lowercased.contains("approach") {
                    advantages.append("Novel methodology that can be adapted")
                }
                
            case "Code Repository":
                advantages.append("Reusable code and implementation examples")
                if lowercased.contains("library") || lowercased.contains("framework") {
                    advantages.append("Ready-to-use library or framework")
                }
                if lowercased.contains("example") || lowercased.contains("demo") {
                    advantages.append("Practical examples demonstrating best practices")
                }
                advantages.append("Learning resource for understanding implementation patterns")
                
            case "Tutorial", "Guide":
                advantages.append("Step-by-step learning resource")
                if lowercased.contains("beginner") || lowercased.contains("getting started") {
                    advantages.append("Accessible for beginners and newcomers")
                }
                advantages.append("Practical knowledge that can be applied immediately")
                
            case "Documentation":
                advantages.append("Authoritative reference material")
                if lowercased.contains("api") || lowercased.contains("reference") {
                    advantages.append("Complete API reference and specifications")
                }
                advantages.append("Technical specifications and best practices")
                
            case "News", "Article":
                advantages.append("Current information and industry trends")
                if lowercased.contains("analysis") || lowercased.contains("insight") {
                    advantages.append("In-depth analysis and expert perspectives")
                }
                advantages.append("Timely information relevant to current developments")
                
            default:
                break
            }
        }
        
        // Extract specific use cases from content
        let useCasePatterns = [
            ("can be used", "Identifies specific use cases and applications"),
            ("applicable to", "Applicable to multiple scenarios and contexts"),
            ("suitable for", "Suitable for specific problem domains"),
            ("recommended for", "Recommended for particular use cases"),
            ("ideal for", "Ideal solution for specific needs")
        ]
        
        for (pattern, advantage) in useCasePatterns {
            if lowercased.contains(pattern) {
                advantages.append(advantage)
                break // Only add once
            }
        }
        
        // Extract problem-solving value
        if lowercased.contains("problem") && lowercased.contains("solve") {
            advantages.append("Addresses specific problems with actionable solutions")
        }
        
        // Extract learning value
        if lowercased.contains("learn") || lowercased.contains("understand") || lowercased.contains("explain") {
            advantages.append("Educational resource that enhances understanding")
        }
        
        // Extract practical value
        if lowercased.contains("implement") || lowercased.contains("apply") || lowercased.contains("use") {
            advantages.append("Practical resource that can be directly implemented")
        }
        
        // Remove duplicates while preserving order
        var uniqueAdvantages: [String] = []
        for advantage in advantages {
            if !uniqueAdvantages.contains(advantage) {
                uniqueAdvantages.append(advantage)
            }
        }
        
        // If we found specific advantages, use them; otherwise use general ones
        if !uniqueAdvantages.isEmpty {
            // Limit to 3-4 most relevant advantages
            let limited = Array(uniqueAdvantages.prefix(4))
            return limited.joined(separator: ". ")
        }
        
        // General fallback advantages
        return "Valuable information for future reference. Can be shared and discussed with others. Provides insights applicable to various contexts."
    }
    
    func generateChatResponse(prompt: String, context: String?) async throws -> String {
        guard isModelLoaded else {
            throw LLMError(message: "Model not loaded")
        }
        
        // TODO: When MLC-LLM is integrated, build and use the full prompt here
        // For now, we provide intelligent context-aware responses
        // The full prompt structure would be:
        // - With context: system message + context + user prompt
        // - Without context: system message + user prompt
        
        // TODO: When MLC-LLM is integrated, use actual model inference here
        // For now, provide intelligent responses based on context and prompt type
        
        if let context = context, !context.isEmpty {
            let promptLower = prompt.lowercased()
            
            // Check if this is a LinkedIn post generation request
            let isLinkedInPostRequest = promptLower.contains("linkedin") || promptLower.contains("social media expert")
            
            if isLinkedInPostRequest {
                // Generate an actual LinkedIn post from the context
                return generateLinkedInPostFromContext(context: context, prompt: prompt)
            }
            
            // Check if this is a comprehensive content analysis request
            let isComprehensiveAnalysis = promptLower.contains("expert content analyst") || 
                                         promptLower.contains("comprehensive content analysis") ||
                                         (promptLower.contains("analyze") && promptLower.contains("thoroughly"))
            
            // Check if this is a content analysis request (summary, importance, what is it)
            let isAnalysisRequest = isComprehensiveAnalysis ||
                                   promptLower.contains("summary:") || 
                                   promptLower.contains("what_is_it:") ||
                                   promptLower.contains("why_important:") ||
                                   promptLower.contains("category:") ||
                                   promptLower.contains("tags:")
            
            if isAnalysisRequest || isComprehensiveAnalysis {
                // For comprehensive analysis, use the full context and let LLM analyze everything
                // The prompt already contains all instructions, so we just need to ensure proper response
                return generateComprehensiveAnalysisResponse(prompt: prompt, context: context)
            }
            
            // Otherwise, provide a RAG-style response for chat queries using intelligent generation
            // Use the context as content and generate an intelligent response
            return generateIntelligentChatResponse(from: context, prompt: prompt)
        }
        
        // Generate actual LLM response instead of predefined responses
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            return "I'm ready to help! You can ask me questions, and I'll do my best to assist. If you ask about your notes, I'll automatically search through them to find relevant information."
        }
        
        // Check if this is a JSON extraction request (keep this special case)
        let lowerPrompt = trimmedPrompt.lowercased()
        let isExtractionRequest = lowerPrompt.contains("extract") && 
                                 (lowerPrompt.contains("json") ||
                                  lowerPrompt.contains("metadata") ||
                                  (lowerPrompt.contains("title") && lowerPrompt.contains("description") && lowerPrompt.contains("tags")) ||
                                  lowerPrompt.contains("return only") ||
                                  lowerPrompt.contains("required json format"))
        
        if isExtractionRequest {
            // Generate JSON response for extraction
            return generateExtractionResponse(prompt: prompt, content: trimmedPrompt)
        }
        
        // For all other queries, generate an intelligent response using LLM analysis
        // Use the prompt as content and generate a natural response
        return generateIntelligentChatResponse(from: trimmedPrompt, prompt: trimmedPrompt)
    }
    
    /// Generate intelligent chat response using LLM analysis (not predefined)
    private func generateIntelligentChatResponse(from content: String, prompt: String) -> String {
        // Use the intelligent analysis methods to generate a natural response
        // This creates a more dynamic, LLM-like response instead of predefined text
        
        let lowerPrompt = prompt.lowercased()
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // For very short prompts or simple greetings, provide a friendly response
        if prompt.count < 10 || lowerPrompt == "hi" || lowerPrompt == "hello" || lowerPrompt == "hey" {
            return "Hello! I'm here to help. You can ask me questions, and I'll search through your notes if relevant. How can I assist you?"
        }
        
        // Check if content is substantial (RAG context) or just the prompt
        let hasSubstantialContent = trimmedContent.count > 100 && trimmedContent != prompt
        
        // Determine the type of query and generate appropriate response
        if lowerPrompt.contains("what") || lowerPrompt.contains("explain") || lowerPrompt.contains("describe") {
            // Use description generation for "what" questions
            let description = generateIntelligentDescription(from: hasSubstantialContent ? content : prompt, prompt: prompt)
            if !description.isEmpty && description.count > 20 {
                return description
            }
        }
        
        if lowerPrompt.contains("why") || lowerPrompt.contains("important") || lowerPrompt.contains("useful") {
            // Use importance generation for "why" questions
            if let importance = generateIntelligentImportance(from: hasSubstantialContent ? content : prompt, prompt: prompt, context: content) {
                if !importance.isEmpty && importance.count > 20 {
                    return importance
                }
            }
        }
        
        if lowerPrompt.contains("summarize") || lowerPrompt.contains("summary") {
            // Use summary generation
            let summary = generateIntelligentSummary(from: hasSubstantialContent ? content : prompt, prompt: prompt)
            if !summary.isEmpty && summary.count > 20 {
                return summary
            }
        }
        
        // For RAG queries with substantial context, use intelligent analysis
        if hasSubstantialContent {
            let summary = generateIntelligentSummary(from: content, prompt: prompt)
            let description = generateIntelligentDescription(from: content, prompt: prompt)
            
            // Build a natural conversational response from the context
            var response = ""
            if !summary.isEmpty && summary.count > 20 {
                response = summary
                if !description.isEmpty && description.count > 20 && description != summary {
                    response += " " + description
                }
            } else if !description.isEmpty && description.count > 20 {
                response = description
            }
            
            if !response.isEmpty {
                return response
            }
        }
        
        // For general chat without substantial context, provide a helpful response
        let words = prompt.components(separatedBy: CharacterSet.whitespaces.union(.punctuationCharacters))
            .filter { $0.count > 2 && !["what", "when", "where", "which", "whose", "about", "would", "could", "should", "hello", "hi", "hey", "the", "and", "or", "but"].contains($0.lowercased()) }
        
        if !words.isEmpty {
            let topic = words.prefix(3).joined(separator: " ")
            return "I understand you're asking about \(topic). Based on the information available, I can help you explore this topic further. Would you like me to search through your notes for more specific information?"
        } else {
            return "I'm here to help! Feel free to ask me questions, and I'll do my best to assist. If you mention your notes, I'll automatically search through them to find relevant information."
        }
    }
    
    /// Generate JSON extraction response from prompt/content
    private func generateExtractionResponse(prompt: String, content: String) -> String {
        // Extract URL from prompt if present
        var url: URL?
        if let urlRange = prompt.range(of: #"https?://[^\s]+"#, options: .regularExpression) {
            url = URL(string: String(prompt[urlRange]))
        }
        
        // Extract content from prompt (look for "Content:" section)
        var actualContent = content
        if let contentStart = prompt.range(of: "Content:", options: .caseInsensitive) {
            let contentSection = String(prompt[contentStart.upperBound...])
            if !contentSection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Remove "Return JSON only:" or similar trailing text
                let cleaned = contentSection.components(separatedBy: "Return JSON").first ?? contentSection
                actualContent = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Extract metadata hints from prompt
        var metadataHints: [String: String] = [:]
        if let metadataStart = prompt.range(of: "Metadata:", options: .caseInsensitive) {
            let metadataSection = String(prompt[metadataStart.upperBound...])
            let metadataLines = metadataSection.components(separatedBy: .newlines)
            for line in metadataLines {
                if line.contains(":") {
                    let parts = line.components(separatedBy: ":")
                    if parts.count >= 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        metadataHints[key] = value
                    }
                }
            }
        }
        
        // Use intelligent extraction with improved logic
        let title = extractTitleFromContentImproved(actualContent, url: url, metadataHints: metadataHints)
        let description = generateIntelligentSummary(from: actualContent, prompt: prompt)
        let tags = extractTagsFromContextImproved(context: actualContent, content: actualContent, url: url, metadataHints: metadataHints)
        
        // Build JSON response
        var jsonParts: [String] = []
        
        if let title = title, !title.isEmpty {
            jsonParts.append("\"title\": \"\(escapeJSON(title))\"")
        } else {
            jsonParts.append("\"title\": null")
        }
        
        if !description.isEmpty {
            // Add "Why it is useful" if not present
            var fullDescription = description
            if !description.lowercased().contains("why it is useful") && !description.lowercased().contains("why it's useful") {
                if let usefulness = generateIntelligentImportance(from: actualContent, prompt: prompt, context: actualContent), !usefulness.isEmpty {
                    fullDescription += " Why it is useful: \(usefulness)"
                }
            }
            // Limit description length
            if fullDescription.count > 400 {
                fullDescription = String(fullDescription.prefix(397)) + "..."
            }
            jsonParts.append("\"description\": \"\(escapeJSON(fullDescription))\"")
        } else {
            jsonParts.append("\"description\": null")
        }
        
        if !tags.isEmpty {
            let tagsJSON = tags.map { "\"\(escapeJSON($0))\"" }.joined(separator: ", ")
            jsonParts.append("\"tags\": [\(tagsJSON)]")
        } else {
            jsonParts.append("\"tags\": []")
        }
        
        return "{\n  \(jsonParts.joined(separator: ",\n  "))\n}"
    }
    
    /// Extract title from content/URL (improved version)
    private func extractTitleFromContent(_ content: String, url: URL?) -> String? {
        return extractTitleFromContentImproved(content, url: url, metadataHints: [:])
    }
    
    /// Improved title extraction
    private func extractTitleFromContentImproved(_ content: String, url: URL?, metadataHints: [String: String]) -> String? {
        // Check metadata hints first
        if let pageTitle = metadataHints["page title"], !pageTitle.isEmpty {
            return pageTitle
        }
        if let ogTitle = metadataHints["opengraph title"], !ogTitle.isEmpty {
            return ogTitle
        }
        
        // Try to extract from content - look for common patterns
        let lines = content.components(separatedBy: .newlines)
        
        // Look for title-like patterns in first few lines
        for line in lines.prefix(15) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines, URLs, and common prefixes
            if trimmed.isEmpty ||
               trimmed.lowercased().hasPrefix("http") ||
               trimmed.lowercased().hasPrefix("content:") ||
               trimmed.lowercased().hasPrefix("metadata:") ||
               trimmed.count < 5 {
                continue
            }
            
            // Look for title patterns: starts with capital, reasonable length, not all caps
            if trimmed.first?.isUppercase == true &&
               trimmed.count > 5 && trimmed.count < 120 &&
               trimmed != trimmed.uppercased() {
                // Check if it looks like a title (not a sentence)
                if !trimmed.contains(".") || trimmed.components(separatedBy: ".").count <= 2 {
                    return trimmed
                }
            }
        }
        
        // Fallback to URL extraction
        if let url = url {
            if url.host?.contains("github.com") == true {
                let pathComponents = url.pathComponents.filter { $0 != "/" }
                if let repoName = pathComponents.last, !repoName.isEmpty {
                    // Capitalize first letter
                    return repoName.prefix(1).uppercased() + repoName.dropFirst()
                }
            } else if let host = url.host {
                return host.replacingOccurrences(of: "www.", with: "").capitalized
            }
        }
        
        return nil
    }
    
    /// Improved tag extraction
    private func extractTagsFromContextImproved(context: String, content: String, url: URL?, metadataHints: [String: String]) -> [String] {
        var tags: [String] = []
        
        // Extract from metadata keywords if available
        if let keywords = metadataHints["keywords"], !keywords.isEmpty {
            let keywordTags = keywords.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.count > 2 }
            tags.append(contentsOf: keywordTags)
        }
        
        // Extract from URL domain/path
        if let url = url {
            if url.host?.contains("github.com") == true {
                tags.append("github")
                // Try to infer from repo name
                let pathComponents = url.pathComponents.filter { $0 != "/" }
                if pathComponents.count >= 2 {
                    let org = pathComponents[0]
                    if org.lowercased() != "github" {
                        tags.append(org.lowercased())
                    }
                }
            } else if url.host?.contains("arxiv.org") == true {
                tags.append("research-paper")
                tags.append("arxiv")
            } else if url.host?.contains("huggingface.co") == true {
                tags.append("huggingface")
            }
        }
        
        // Extract from content characteristics
        let lowercased = content.lowercased()
        
        // Technology tags
        if lowercased.contains("python") { tags.append("python") }
        if lowercased.contains("javascript") || lowercased.contains("typescript") { tags.append("javascript") }
        if lowercased.contains("swift") { tags.append("swift") }
        if lowercased.contains("rust") { tags.append("rust") }
        if lowercased.contains("go ") || lowercased.contains("golang") { tags.append("go") }
        
        // Domain tags
        if lowercased.contains("machine learning") || lowercased.contains("ml ") { tags.append("machine-learning") }
        if lowercased.contains("deep learning") || lowercased.contains("neural network") { tags.append("deep-learning") }
        if lowercased.contains("transformer") { tags.append("transformers") }
        if lowercased.contains("llm") || lowercased.contains("large language model") { tags.append("llm") }
        if lowercased.contains("ai") && !tags.contains("ai") { tags.append("ai") }
        if lowercased.contains("time series") || lowercased.contains("time-series") { tags.append("time-series") }
        if lowercased.contains("forecast") { tags.append("forecasting") }
        if lowercased.contains("research") { tags.append("research") }
        if lowercased.contains("framework") { tags.append("framework") }
        if lowercased.contains("library") { tags.append("library") }
        if lowercased.contains("tutorial") { tags.append("tutorial") }
        if lowercased.contains("documentation") { tags.append("documentation") }
        if lowercased.contains("agent") { tags.append("ai-agents") }
        if lowercased.contains("automation") { tags.append("automation") }
        if lowercased.contains("open source") || lowercased.contains("open-source") { tags.append("open-source") }
        if lowercased.contains("webgpu") { tags.append("webgpu") }
        if lowercased.contains("ocr") || lowercased.contains("optical character") { tags.append("ocr") }
        if lowercased.contains("retrieval") && lowercased.contains("generation") { tags.append("retrieval-augmented-generation") }
        if lowercased.contains("rag") { tags.append("retrieval-augmented-generation") }
        if lowercased.contains("edge") && lowercased.contains("ai") { tags.append("edge-ai") }
        if lowercased.contains("lightweight") { tags.append("lightweight-ai") }
        if lowercased.contains("attention") { tags.append("attention-models") }
        if lowercased.contains("fine-tun") || lowercased.contains("finetun") { tags.append("fine-tuning") }
        if lowercased.contains("optimization") { tags.append("optimization") }
        if lowercased.contains("nlp") || lowercased.contains("natural language") { tags.append("nlp") }
        if lowercased.contains("memory") && lowercased.contains("long") { tags.append("long-context") }
        
        // Remove duplicates and limit
        tags = Array(Set(tags.map { $0.lowercased() })).map { $0 }
        
        // Limit to 8 tags max
        return Array(tags.prefix(8))
    }
    
    /// Escape JSON string
    private func escapeJSON(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
    
    /// Generate comprehensive analysis response using full LLM power
    private func generateComprehensiveAnalysisResponse(prompt: String, context: String) -> String {
        // The prompt already contains comprehensive instructions
        // Extract the actual content from context for intelligent analysis
        let contentStart = context.range(of: "FULL CONTENT:") ?? context.range(of: "Content to analyze:")
        let actualContent: String
        if let start = contentStart {
            actualContent = String(context[start.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            actualContent = context
        }
        
        // Use intelligent extraction to generate structured response
        // This simulates what the LLM would do when fully integrated
        var response = ""
        
        // Generate SUMMARY
        let summary = generateIntelligentSummary(from: actualContent, prompt: prompt)
        response += "SUMMARY: \(summary)\n\n"
        
        // Generate WHAT_IS_IT
        let whatIsIt = generateIntelligentDescription(from: actualContent, prompt: prompt)
        response += "WHAT_IS_IT: \(whatIsIt)\n\n"
        
        // Generate WHY_IMPORTANT
        if let whyImportant = generateIntelligentImportance(from: actualContent, prompt: prompt, context: context) {
            response += "WHY_IMPORTANT: \(whyImportant)\n\n"
        } else {
            // If no specific value found, try to extract from content directly
            let fallback = extractSpecificValueFromContent(actualContent)
            response += "WHY_IMPORTANT: \(fallback)\n\n"
        }
        
        // Extract CATEGORY from context or content
        let category = extractCategoryFromContext(context: context) ?? "General"
        response += "CATEGORY: \(category)\n\n"
        
        // Extract TAGS
        let tags = extractTagsFromContext(context: context, content: actualContent)
        response += "TAGS: \(tags.joined(separator: ", "))"
        
        return response
    }
    
    /// Extract category from context metadata
    private func extractCategoryFromContext(context: String) -> String? {
        // Look for category hints in context
        if context.lowercased().contains("research paper") || context.lowercased().contains("arxiv") {
            return "Research Paper"
        }
        if context.lowercased().contains("code repository") || context.lowercased().contains("github") {
            return "Code Repository"
        }
        if context.lowercased().contains("tutorial") || context.lowercased().contains("guide") {
            return "Tutorial"
        }
        if context.lowercased().contains("documentation") || context.lowercased().contains("api") {
            return "Documentation"
        }
        if context.lowercased().contains("article") || context.lowercased().contains("blog") {
            return "Article"
        }
        return nil
    }
    
    /// Extract tags from context and content
    private func extractTagsFromContext(context: String, content: String) -> [String] {
        var tags: [String] = []
        
        // Extract from metadata keywords if available
        if let keywordsRange = context.range(of: "Keywords:") {
            let keywordsLine = String(context[keywordsRange.upperBound...])
            let keywordsPart = keywordsLine.components(separatedBy: "\n").first ?? ""
            let extractedKeywords = keywordsPart.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            tags.append(contentsOf: extractedKeywords)
        }
        
        // Extract from content characteristics
        let lowercased = content.lowercased()
        if lowercased.contains("python") || lowercased.contains("javascript") || lowercased.contains("swift") {
            tags.append("programming")
        }
        if lowercased.contains("machine learning") || lowercased.contains("ai") || lowercased.contains("neural") {
            tags.append("AI/ML")
        }
        if lowercased.contains("research") || lowercased.contains("study") {
            tags.append("research")
        }
        if lowercased.contains("framework") || lowercased.contains("library") {
            tags.append("framework")
        }
        
        // Use heuristic tag extraction as fallback
        if tags.isEmpty {
            tags = Array(Set(extractTags(from: content, metadata: nil))).prefix(5).map { $0 }
        }
        
        return Array(Set(tags)).prefix(8).map { $0 }
    }
    
    /// Generate intelligent analysis response based on context (for summary, importance, etc.)
    private func generateAnalysisResponse(prompt: String, context: String) -> String {
        let promptLower = prompt.lowercased()
        
        // Extract content from context
        // Context format: "Content Analysis Task:\nType: ...\nCharacteristics: ...\n\nContent to analyze:\n..."
        let contentStart = context.range(of: "Content to analyze:") ?? context.range(of: "Content:")
        let actualContent: String
        if let start = contentStart {
            actualContent = String(context[start.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Fallback: use context as-is
            actualContent = context
        }
        
        // Determine what type of analysis is requested
        if promptLower.contains("summary") || promptLower.contains("summarize") {
            return generateIntelligentSummary(from: actualContent, prompt: prompt)
        } else if promptLower.contains("important") || promptLower.contains("valuable") || promptLower.contains("why") || promptLower.contains("advantageous") {
            return generateIntelligentImportance(from: actualContent, prompt: prompt, context: context) ?? generateIntelligentSummary(from: actualContent, prompt: prompt)
        } else if promptLower.contains("what is") || promptLower.contains("describe") {
            return generateIntelligentDescription(from: actualContent, prompt: prompt)
        }
        
        // Generic analysis response
        return generateIntelligentSummary(from: actualContent, prompt: prompt)
    }
    
    /// Generate intelligent summary from content (context-aware, not regex-based)
    private func generateIntelligentSummary(from content: String, prompt: String) -> String {
        // Extract key information intelligently
        let paragraphs = content.components(separatedBy: "\n\n")
        var keyPoints: [String] = []
        
        // Look for key sections
        for paragraph in paragraphs.prefix(10) {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count < 50 || trimmed.count > 500 {
                continue
            }
            
            // Prioritize paragraphs with key indicators
            let lowercased = trimmed.lowercased()
            if lowercased.contains("introduces") || 
               lowercased.contains("presents") ||
               lowercased.contains("demonstrates") ||
               lowercased.contains("shows") ||
               lowercased.contains("provides") ||
               lowercased.contains("enables") {
                keyPoints.append(trimmed)
                if keyPoints.joined(separator: " ").count > 250 {
                    break
                }
            }
        }
        
        // If we found key points, synthesize them
        if !keyPoints.isEmpty {
            let combined = keyPoints.joined(separator: " ")
            // Extract first 2-3 sentences
            let sentences = combined.components(separatedBy: ".")
            var summary = ""
            for sentence in sentences.prefix(3) {
                let trimmed = sentence.trimmingCharacters(in: .whitespaces)
                if trimmed.count > 20 {
                    summary += (summary.isEmpty ? "" : " ") + trimmed + "."
                    if summary.count > 280 {
                        break
                    }
                }
            }
            if !summary.isEmpty {
                return summary.trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Fallback: use first meaningful paragraphs
        return generateEnhancedSummary(from: content, metadata: nil)
    }
    
    /// Generate intelligent importance/why advantageous from content
    private func generateIntelligentImportance(from content: String, prompt: String, context: String) -> String? {
        // Analyze content to find specific value propositions, metrics, and innovations
        var importancePoints: [String] = []
        
        // Look for quantifiable benefits (numbers, percentages, metrics)
        let metricsPatterns = [
            #"(\d+)%"#,  // Percentages
            #"(\d+)x"#,  // Multipliers
            #"(\d+)\s*(times|fold)"#,  // Times/fold improvements
            #"(\d+)\s*(MB|GB|TB|ms|s|min)"#,  // Size/time metrics
            #"reduce[sd]?\s+by\s+(\d+)"#,  // Reductions
            #"improve[sd]?\s+by\s+(\d+)"#,  // Improvements
        ]
        
        let lowercased = content.lowercased()
        
        // Extract sentences with metrics
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            let sentenceLower = trimmed.lowercased()
            
            // Look for sentences with metrics
            var hasMetric = false
            for pattern in metricsPatterns {
                if let _ = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                    .firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                    hasMetric = true
                    break
                }
            }
            
            if hasMetric && trimmed.count > 40 && trimmed.count < 200 {
                importancePoints.append(trimmed)
            }
        }
        
        // Look for specific problem-solution patterns with details
        let problemSolutionKeywords = [
            "solves", "addresses", "eliminates", "reduces", "minimizes",
            "improves", "enhances", "optimizes", "accelerates",
            "enables", "allows", "facilitates", "supports",
            "provides", "offers", "delivers", "implements"
        ]
        
        for keyword in problemSolutionKeywords {
            if lowercased.contains(keyword) {
                for sentence in sentences {
                    let trimmed = sentence.trimmingCharacters(in: .whitespaces)
                    let sentenceLower = trimmed.lowercased()
                    if sentenceLower.contains(keyword) && trimmed.count > 50 && trimmed.count < 180 {
                        // Prefer sentences with specific details
                        if sentenceLower.contains("by") || sentenceLower.contains("from") || 
                           sentenceLower.contains("to") || sentenceLower.contains("with") ||
                           trimmed.range(of: #"\d+"#, options: .regularExpression) != nil {
                            importancePoints.append(trimmed)
                            break
                        }
                    }
                }
            }
        }
        
        // Look for innovation indicators with FULL context - extract the actual sentence, not generic labels
        let innovationKeywords = [
            "novel", "innovative", "breakthrough", "state-of-the-art", "cutting-edge", 
            "first", "unique", "revolutionary", "groundbreaking", "pioneering"
        ]
        
        for keyword in innovationKeywords {
            if lowercased.contains(keyword) {
                // Find the sentence with context - extract the FULL sentence, not a generic label
                for sentence in sentences {
                    let trimmed = sentence.trimmingCharacters(in: .whitespaces)
                    let sentenceLower = trimmed.lowercased()
                    // Only include if it has actual details (contains numbers, specific terms, or is descriptive)
                    if sentenceLower.contains(keyword) && trimmed.count > 60 && trimmed.count < 250 {
                        // Prefer sentences with specific details
                        if trimmed.range(of: #"\d+"#, options: .regularExpression) != nil ||
                           sentenceLower.contains("enables") || sentenceLower.contains("allows") ||
                           sentenceLower.contains("reduces") || sentenceLower.contains("improves") ||
                           sentenceLower.contains("provides") || sentenceLower.contains("supports") {
                            importancePoints.append(trimmed)
                            break
                        }
                    }
                }
            }
        }
        
        // Look for practical applications and use cases
        let useCaseKeywords = ["can be used", "applicable to", "ideal for", "suitable for", "designed for"]
        for keyword in useCaseKeywords {
            if lowercased.contains(keyword) {
                for sentence in sentences {
                    let trimmed = sentence.trimmingCharacters(in: .whitespaces)
                    if trimmed.lowercased().contains(keyword) && trimmed.count > 40 && trimmed.count < 180 {
                        importancePoints.append(trimmed)
                        break
                    }
                }
            }
        }
        
        // Synthesize importance points - prioritize those with metrics or specific details
        if !importancePoints.isEmpty {
            // Sort by length and specificity (longer, more detailed sentences first)
            let sorted = importancePoints.sorted { $0.count > $1.count }
            // Take first 2-3 most relevant and detailed points
            let limited = Array(sorted.prefix(3))
            let result = limited.joined(separator: ". ")
            // Ensure we don't exceed reasonable length
            return result.count > 400 ? String(result.prefix(397)) + "..." : result
        }
        
        // Fallback: try to extract actual sentences with value, not generic statements
        // Look for sentences that contain both value keywords AND specific details
        let valueKeywords = ["enables", "allows", "provides", "supports", "reduces", "improves", 
                             "eliminates", "solves", "addresses", "facilitates", "optimizes"]
        
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            let sentenceLower = trimmed.lowercased()
            
            // Check if sentence has value keyword AND specific details (numbers or descriptive content)
            let hasValueKeyword = valueKeywords.contains { sentenceLower.contains($0) }
            let hasSpecificDetail = trimmed.range(of: #"\d+"#, options: .regularExpression) != nil ||
                                   trimmed.count > 80 // Longer sentences usually have more detail
            
            if hasValueKeyword && hasSpecificDetail && trimmed.count > 50 && trimmed.count < 250 {
                // Avoid generic statements
                let genericPhrases = ["novel approach", "innovative solution", "practical and applicable",
                                     "comprehensive resource", "valuable information", "useful resource"]
                let isGeneric = genericPhrases.contains { sentenceLower.contains($0) }
                
                if !isGeneric {
                    importancePoints.append(trimmed)
                    if importancePoints.count >= 2 {
                        break
                    }
                }
            }
        }
        
        // If we found specific points, use them
        if !importancePoints.isEmpty {
            let sorted = importancePoints.sorted { $0.count > $1.count }
            let limited = Array(sorted.prefix(2))
            let result = limited.joined(separator: ". ")
            return result.count > 400 ? String(result.prefix(397)) + "..." : result
        }
        
        // Last resort: try to extract from paragraphs with actual content
        let paragraphs = content.components(separatedBy: "\n\n")
        for paragraph in paragraphs.prefix(5) {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 150 && trimmed.count < 400 {
                // Look for paragraphs with specific details (numbers, technical terms, or detailed descriptions)
                let hasNumbers = trimmed.range(of: #"\d+"#, options: .regularExpression) != nil
                let hasTechnicalTerms = trimmed.lowercased().contains("api") || 
                                       trimmed.lowercased().contains("framework") ||
                                       trimmed.lowercased().contains("algorithm") ||
                                       trimmed.lowercased().contains("model") ||
                                       trimmed.lowercased().contains("performance")
                
                // Avoid generic paragraphs
                let isGeneric = trimmed.lowercased().contains("novel approach") ||
                               trimmed.lowercased().contains("innovative solution") ||
                               trimmed.lowercased().contains("practical and applicable")
                
                if (hasNumbers || hasTechnicalTerms) && !isGeneric {
                    return String(trimmed.prefix(400))
                }
            }
        }
        
        // Final fallback - be honest that we couldn't extract specific value
        return nil // Return nil instead of generic statement
    }
    
    /// Extract specific value from content as fallback when generateIntelligentImportance returns nil
    private func extractSpecificValueFromContent(_ content: String) -> String {
        // Try to find any sentence with specific details
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            // Look for sentences with numbers or specific technical details
            if trimmed.range(of: #"\d+"#, options: .regularExpression) != nil && trimmed.count > 40 && trimmed.count < 200 {
                // Avoid generic statements
                let genericPhrases = ["novel approach", "innovative solution", "practical and applicable"]
                let isGeneric = genericPhrases.contains { trimmed.lowercased().contains($0) }
                if !isGeneric {
                    return trimmed
                }
            }
        }
        
        // Last resort: return a message asking user to review content
        return "Review content for specific benefits and value propositions"
    }
    
    /// Generate intelligent description of what the content is
    private func generateIntelligentDescription(from content: String, prompt: String) -> String {
        // Extract from first meaningful sentence
        let paragraphs = content.components(separatedBy: "\n\n")
        for paragraph in paragraphs.prefix(3) {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 50 && trimmed.count < 300 {
                let sentences = trimmed.components(separatedBy: ".")
                if let firstSentence = sentences.first, firstSentence.count > 30 && firstSentence.count < 150 {
                    return firstSentence.trimmingCharacters(in: .whitespaces) + "."
                }
            }
        }
        
        // Fallback
        return analyzeWhatItIs(from: content, metadata: nil) ?? "Content resource"
    }
    
    func generateChatResponseStream(prompt: String, context: String?) -> AsyncThrowingStream<String, Error> {
        guard isModelLoaded else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: LLMError(message: "Model not loaded"))
            }
        }
        
        // TODO: When MLC-LLM is integrated, build and use the full prompt here
        // For now, the prompt is not used as we're providing simulated streaming responses
        // The full prompt structure would be:
        // - With context: system message + context + user prompt
        // - Without context: system message + user prompt
        
        // TODO: When MLC-LLM is integrated, use actual streaming inference
        // For now, simulate streaming by chunking the response
        return AsyncThrowingStream { continuation in
            Task {
                // Generate the full response (placeholder)
                var fullResponse: String
                if let context = context, !context.isEmpty {
                    let promptLower = prompt.lowercased()
                    
                    // Check if this is a LinkedIn post generation request
                    let isLinkedInPostRequest = promptLower.contains("linkedin") || promptLower.contains("social media expert")
                    
                    if isLinkedInPostRequest {
                        // Generate an actual LinkedIn post from the context
                        fullResponse = generateLinkedInPostFromContext(context: context, prompt: prompt)
                    } else {
                        // Otherwise, provide a RAG-style response for chat queries using intelligent generation
                        // Use the context as content and generate an intelligent response
                        fullResponse = generateIntelligentChatResponse(from: context, prompt: prompt)
                    }
                } else {
                    // Generic chat response - use intelligent generation instead of predefined
                    let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedPrompt.isEmpty else {
                        fullResponse = "I'm ready to help! You can ask me questions, and I'll do my best to assist. If you ask about your notes, I'll automatically search through them to find relevant information."
                        return
                    }
                    
                    // Use intelligent chat response generation instead of predefined responses
                    fullResponse = generateIntelligentChatResponse(from: trimmedPrompt, prompt: trimmedPrompt)
                }
                
                // Simulate streaming by sending chunks word by word
                let responseWords = fullResponse.components(separatedBy: " ")
                for (index, word) in responseWords.enumerated() {
                    let chunk = index == 0 ? word : " \(word)"
                    continuation.yield(chunk)
                    
                    // Simulate typing speed (adjust delay as needed)
                    try? await Task.sleep(nanoseconds: 30_000_000) // 30ms per word for smoother streaming
                }
                
                continuation.finish()
            }
        }
    }
    
    /// Generate a LinkedIn post from context (note summaries)
    private func generateLinkedInPostFromContext(context: String, prompt: String) -> String {
        // Parse the context to extract note summaries
        // Context format: "Recent interesting findings (N items):\n\n1. Title: ...\nSummary: ...\n\n2. Title: ...\nSummary: ...\n..."
        var summaries: [String] = []
        
        // Use a more robust regex to find all numbered sections
        // Pattern matches: start of line or newline, followed by number, dot, and space
        let numberedItemPattern = #"(?:^|\n)(\d+)\.\s+"#
        guard let regex = try? NSRegularExpression(pattern: numberedItemPattern, options: [.anchorsMatchLines]) else {
            // Fallback parsing
            return generateLinkedInPostFallback(context: context)
        }
        
        let range = NSRange(context.startIndex..., in: context)
        let matches = regex.matches(in: context, options: [], range: range)
        
        if matches.isEmpty {
            // Try alternative parsing
            return generateLinkedInPostFallback(context: context)
        }
        
        // Extract each numbered section
        for (index, match) in matches.enumerated() {
            let matchStart = match.range.location
            let matchEnd: Int
            
            // Find the end of this section (start of next numbered item or end of string)
            if index < matches.count - 1 {
                matchEnd = matches[index + 1].range.location
            } else {
                matchEnd = context.count
            }
            
            // Extract the section content
            let sectionRange = NSRange(location: matchStart, length: matchEnd - matchStart)
            if let range = Range(sectionRange, in: context) {
                var sectionContent = String(context[range])
                
                // Remove the leading "N. " part - find the number and dot
                if let numberMatch = sectionContent.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                    sectionContent = String(sectionContent[numberMatch.upperBound...])
                } else if let newlineIndex = sectionContent.firstIndex(of: "\n") {
                    // If no leading number pattern, try removing first line
                    let firstLine = String(sectionContent[..<newlineIndex])
                    if firstLine.range(of: #"^\d+\.\s*"#, options: .regularExpression) != nil {
                        sectionContent = String(sectionContent[sectionContent.index(after: newlineIndex)...])
                    }
                }
                
                // Clean up the section
                sectionContent = sectionContent.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !sectionContent.isEmpty {
                    summaries.append(sectionContent)
                }
            }
        }
        
        // Debug: Log how many summaries we found
        print("LinkedIn Post Generation: Found \(summaries.count) summaries from context")
        
        // If we still don't have summaries, try fallback
        if summaries.isEmpty {
            return generateLinkedInPostFallback(context: context)
        }
        
        // Verify we have the expected number of summaries
        // Extract expected count from context header if possible
        if let countMatch = context.range(of: #"\((\d+)\s+items?\)"#, options: .regularExpression),
           let countString = String(context[countMatch]).components(separatedBy: CharacterSet.decimalDigits.inverted).joined().first.map(String.init),
           let expectedCount = Int(countString),
           summaries.count < expectedCount {
            print("LinkedIn Post Generation: Warning - Expected \(expectedCount) summaries but found \(summaries.count)")
            // Try fallback to see if it can extract more
            let fallbackResult = generateLinkedInPostFallback(context: context)
            // If fallback found more summaries, use it
            if fallbackResult.contains("\(expectedCount) interesting findings") || summaries.count < expectedCount {
                return fallbackResult
            }
        }
        
        // Build LinkedIn post from parsed summaries
        return buildLinkedInPostFromSummaries(summaries: summaries)
    }
    
    /// Fallback parsing method for LinkedIn post generation
    private func generateLinkedInPostFallback(context: String) -> String {
        // Try multiple parsing strategies
        var summaries: [String] = []
        
        // Strategy 1: Split by numbered items more carefully
        // Look for patterns like "1. ", "2. " at start of lines
        let lines = context.components(separatedBy: .newlines)
        var currentSummary: [String] = []
        var currentNumber: Int?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip header
            if trimmed.lowercased().contains("recent interesting findings") || 
               trimmed.lowercased().contains("items") {
                continue
            }
            
            // Check if this line starts a new numbered item
            if let numberMatch = trimmed.range(of: #"^(\d+)\.\s+"#, options: .regularExpression) {
                // Save previous summary if exists
                if let prevNum = currentNumber, !currentSummary.isEmpty {
                    let summaryText = currentSummary.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !summaryText.isEmpty {
                        summaries.append(summaryText)
                    }
                }
                
                // Extract number
                let numberPart = String(trimmed[numberMatch])
                if let num = Int(numberPart.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                    currentNumber = num
                    currentSummary = []
                    
                    // Extract content after number
                    let contentStart = trimmed.index(numberMatch.upperBound, offsetBy: 0)
                    let content = String(trimmed[contentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !content.isEmpty {
                        currentSummary.append(content)
                    }
                }
            } else if !trimmed.isEmpty {
                // Continue current summary
                currentSummary.append(trimmed)
            } else if !currentSummary.isEmpty {
                // Empty line might separate sections, but continue if we have content
                currentSummary.append("")
            }
        }
        
        // Add last summary
        if let prevNum = currentNumber, !currentSummary.isEmpty {
            let summaryText = currentSummary.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !summaryText.isEmpty {
                summaries.append(summaryText)
            }
        }
        
        // Strategy 2: If still empty, try splitting by double newlines
        if summaries.isEmpty {
            let sections = context.components(separatedBy: "\n\n")
            for section in sections {
                let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && 
                   !trimmed.lowercased().contains("recent interesting findings") &&
                   !trimmed.lowercased().contains("items") {
                    // Remove leading numbers if present
                    let cleaned = trimmed.replacingOccurrences(
                        of: #"^\d+\.\s*"#,
                        with: "",
                        options: .regularExpression
                    )
                    if !cleaned.isEmpty {
                        summaries.append(cleaned)
                    }
                }
            }
        }
        
        print("LinkedIn Post Fallback: Found \(summaries.count) summaries")
        return buildLinkedInPostFromSummaries(summaries: summaries)
    }
    
    /// Build LinkedIn post from parsed summaries
    private func buildLinkedInPostFromSummaries(summaries: [String]) -> String {
        var post = ""
        
        // Debug: Ensure we're working with all summaries
        print("buildLinkedInPostFromSummaries: Processing \(summaries.count) summaries")
        
        if summaries.isEmpty {
            // Fallback if we can't parse summaries
            post = """
            📚 Weekly Roundup
            
            I've been exploring some interesting topics this week. Here are a few highlights that caught my attention.
            
            What are your thoughts on these topics? I'd love to hear your perspective!
            
            #Learning #KnowledgeSharing
            """
        } else {
            // Generate post from summaries - include ALL notes with proper formatting
            post = "📚 Weekly Roundup\n\n"
            
            if summaries.count == 1 {
                post += "Here's something interesting I came across this week:\n\n"
                post += formatNoteForLinkedIn(summaries[0]) + "\n\n"
            } else {
                post += "Here are \(summaries.count) interesting findings from this week:\n\n"
                // Use different emojis for variety, cycling through them
                let emojis = ["💡", "🔍", "📖", "🚀", "⚡", "🎯", "🌟", "📊", "🔬", "💼"]
                // CRITICAL: Ensure ALL summaries are included
                for (index, summary) in summaries.enumerated() {
                    let emoji = emojis[index % emojis.count]
                    // Format each note properly - include ALL summaries
                    let formatted = formatNoteForLinkedIn(summary)
                    post += "\(emoji) \(formatted)\n\n"
                    print("buildLinkedInPostFromSummaries: Added summary \(index + 1)/\(summaries.count)")
                }
            }
            
            post += "These insights have been valuable for my work. What topics have you been exploring lately?\n\n"
            post += "#Learning #KnowledgeSharing #WeeklyRoundup"
        }
        
        return post
    }
    
    /// Format a note summary for LinkedIn post (extract key info, format nicely)
    private func formatNoteForLinkedIn(_ noteContent: String) -> String {
        // Parse the note content to extract all available fields
        var title: String?
        var summary: String?
        var fullContent: String?
        var contentPreview: String?
        var url: String?
        var category: String?
        var tags: [String] = []
        
        let lines = noteContent.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("Title:") {
                title = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Summary:") {
                summary = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Full Content:") {
                fullContent = String(trimmed.dropFirst(13)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Content Preview:") {
                contentPreview = String(trimmed.dropFirst(16)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Source URL:") {
                url = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Category:") {
                category = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Tags:") {
                let tagsString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                tags = tagsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
        }
        
        // Build formatted output with all relevant information
        var formatted = ""
        
        // Always include title if available
        if let title = title, !title.isEmpty {
            formatted = "**\(title)**"
        }
        
        // Add summary (prefer summary over content preview)
        let contentToUse = summary ?? contentPreview ?? fullContent
        if let content = contentToUse, !content.isEmpty {
            if !formatted.isEmpty {
                formatted += "\n\n"
            }
            // Use summary/content, but limit length for LinkedIn readability
            let maxLength = 250
            if content.count > maxLength {
                formatted += String(content.prefix(maxLength)) + "..."
            } else {
                formatted += content
            }
        }
        
        // Add category and tags if available
        var metadataParts: [String] = []
        if let category = category, !category.isEmpty {
            metadataParts.append(category)
        }
        if !tags.isEmpty {
            metadataParts.append(tags.prefix(3).joined(separator: ", "))
        }
        if !metadataParts.isEmpty {
            formatted += "\n\n*\(metadataParts.joined(separator: " • "))*"
        }
        
        // Add URL if available (important for source attribution)
        if let url = url, !url.isEmpty {
            formatted += "\n\n"
            // Extract domain for cleaner display, or show full URL if short
            if let urlObj = URL(string: url), let host = urlObj.host {
                if url.count < 60 {
                    formatted += "🔗 \(url)"
                } else {
                    formatted += "🔗 Source: \(host)"
                }
            } else {
                formatted += "🔗 \(url)"
            }
        }
        
        return formatted.isEmpty ? noteContent : formatted
    }
}

