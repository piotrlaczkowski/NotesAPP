import Foundation

/// Enhanced search service with semantic capabilities
/// Currently uses improved keyword search; can be extended with embeddings later
actor SearchService {
    static let shared = SearchService()
    
    private init() {}
    
    /// Search notes with enhanced semantic matching
    /// Returns notes sorted by relevance score
    func search(notes: [Note], query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        
        let normalizedQuery = normalize(query)
        let queryTerms = extractTerms(normalizedQuery)
        
        var results: [SearchResult] = []
        
        for note in notes {
            let score = calculateRelevanceScore(note: note, queryTerms: queryTerms, originalQuery: normalizedQuery)
            if score > 0 {
                results.append(SearchResult(note: note, relevanceScore: score))
            }
        }
        
        // Sort by relevance (highest first)
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    /// Calculate relevance score for a note based on search query
    private func calculateRelevanceScore(note: Note, queryTerms: [String], originalQuery: String) -> Double {
        var score: Double = 0.0
        
        let normalizedTitle = normalize(note.title)
        let normalizedSummary = normalize(note.summary)
        let normalizedContent = normalize(String(note.content.prefix(500))) // Limit content search for performance
        let normalizedCategory = note.category.map(normalize) ?? ""
        let normalizedTags = note.tags.map(normalize).joined(separator: " ")
        
        // Exact phrase match (highest score)
        if normalizedTitle.contains(originalQuery) {
            score += 10.0
        }
        if normalizedSummary.contains(originalQuery) {
            score += 8.0
        }
        if normalizedContent.contains(originalQuery) {
            score += 5.0
        }
        
        // Individual term matching
        for term in queryTerms {
            // Title matches (highest weight)
            if normalizedTitle.contains(term) {
                score += 5.0
                // Bonus for term at start of title
                if normalizedTitle.hasPrefix(term) {
                    score += 2.0
                }
            }
            
            // Summary matches (high weight)
            if normalizedSummary.contains(term) {
                score += 3.0
            }
            
            // Content matches (medium weight)
            let contentOccurrences = normalizedContent.components(separatedBy: term).count - 1
            score += Double(min(contentOccurrences, 5)) * 1.0
            
            // Category matches (high weight)
            if !normalizedCategory.isEmpty && normalizedCategory.contains(term) {
                score += 4.0
            }
            
            // Tag matches (very high weight)
            if normalizedTags.contains(term) {
                score += 6.0
            }
            
            // URL host matching
            if let host = note.url?.host?.lowercased(), host.contains(term) {
                score += 2.0
            }
        }
        
        // Fuzzy matching bonus (for typos/partial matches)
        for term in queryTerms {
            let fuzzyMatches = fuzzyMatch(term: term, against: normalizedTitle + " " + normalizedSummary)
            score += fuzzyMatches * 1.5
        }
        
        // Recency bonus (newer notes get slight boost)
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: note.dateCreated, to: Date()).day ?? 0
        if daysSinceCreation < 30 {
            score += 0.5
        }
        
        return score
    }
    
    /// Normalize text for searching
    private func normalize(_ text: String) -> String {
        return text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Extract search terms from query
    private func extractTerms(_ query: String) -> [String] {
        // Split by whitespace and filter out common stop words
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "is", "are", "was", "were"])
        
        return query.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty && !stopWords.contains($0) && $0.count > 2 }
    }
    
    /// Simple fuzzy matching score (checks if term is contained with some tolerance)
    private func fuzzyMatch(term: String, against text: String) -> Double {
        // Exact match
        if text.contains(term) {
            return 1.0
        }
        
        // Check if any words in text contain the term as substring
        let words = text.components(separatedBy: .whitespaces)
        var matches: Double = 0.0
        
        for word in words {
            if word.contains(term) || term.contains(word) {
                matches += 0.5
            }
            // Check character overlap
            let overlap = calculateOverlap(term, word)
            matches += overlap * 0.3
        }
        
        return min(matches, 2.0) // Cap fuzzy match score
    }
    
    /// Calculate character overlap between two strings
    private func calculateOverlap(_ s1: String, _ s2: String) -> Double {
        let set1 = Set(s1)
        let set2 = Set(s2)
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }
    
    /// Filter notes by category
    func filterByCategory(_ notes: [Note], category: String?) -> [Note] {
        guard let category = category else { return notes }
        return notes.filter { $0.category == category }
    }
    
    /// Filter notes by tag
    func filterByTag(_ notes: [Note], tag: String) -> [Note] {
        return notes.filter { $0.tags.contains(tag) }
    }
    
    /// Filter notes by multiple tags (OR logic - note has any of these tags)
    func filterByTags(_ notes: [Note], tags: Set<String>) -> [Note] {
        guard !tags.isEmpty else { return notes }
        return notes.filter { !Set($0.tags).isDisjoint(with: tags) }
    }
}

/// Search result with relevance score
struct SearchResult {
    let note: Note
    let relevanceScore: Double
}

