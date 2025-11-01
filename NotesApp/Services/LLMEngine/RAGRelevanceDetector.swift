import Foundation

/// Determines if a query needs RAG (context from notes) or can be answered generically
actor RAGRelevanceDetector {
    static let shared = RAGRelevanceDetector()
    
    private let searchService = SearchService.shared
    private let noteRepository = NoteRepository.shared
    
    private init() {}
    
    /// Determines if RAG is needed for a query
    /// Returns: (needsRAG: Bool, relevantNotes: [Note], relevanceScore: Double)
    func shouldUseRAG(query: String) async -> (needsRAG: Bool, relevantNotes: [Note], relevanceScore: Double) {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Generic questions that don't need RAG
        let genericPatterns = [
            "hello", "hi", "hey", "how are you", "what can you do",
            "help", "who are you", "what is your name", "what are you",
            "thank you", "thanks", "bye", "goodbye", "good morning",
            "good afternoon", "good evening", "how's it going", "how are things"
        ]
        
        // Check for generic greetings/questions (more lenient)
        if genericPatterns.contains(where: { normalizedQuery.contains($0) && normalizedQuery.count < 60 }) {
            return (false, [], 0.0)
        }
        
        // Questions asking about the user's notes/content
        let ragKeywords = [
            "my note", "my notes", "in my", "from my", "about my",
            "what did i", "what have i", "what i", "when did i",
            "remember", "i saved", "i saved", "i noted", "i wrote",
            "search", "find", "show me", "tell me about"
        ]
        
        let hasRAGKeywords = ragKeywords.contains { normalizedQuery.contains($0) }
        
        // General questions that don't need notes (unless they have RAG keywords)
        let generalQuestionPatterns = [
            "explain", "what is", "tell me about", "how does",
            "why", "when", "where", "who", "which"
        ]
        
        // If it's a general question without note-specific keywords, check relevance before deciding
        let hasGeneralQuestion = generalQuestionPatterns.contains(where: { normalizedQuery.contains($0) })
        if hasGeneralQuestion && !hasRAGKeywords && normalizedQuery.count < 100 {
            // Will check relevance score below
        }
        
        // Search for relevant notes
        let allNotes = await noteRepository.fetchAll()
        let searchResults = await searchService.search(notes: allNotes, query: query)
        
        // Calculate relevance score from top results
        let topResults = Array(searchResults.prefix(5))
        let relevanceScore = topResults.first?.relevanceScore ?? 0.0
        let relevantNotes = topResults.map { $0.note }
        
        // Use RAG if:
        // 1. Explicit RAG keywords present, OR
        // 2. High relevance score (>= 5.0), OR
        // 3. Multiple notes found with decent relevance
        let needsRAG = hasRAGKeywords || 
                       relevanceScore >= 5.0 || 
                       (relevantNotes.count >= 2 && relevanceScore >= 2.0)
        
        return (needsRAG, relevantNotes, relevanceScore)
    }
    
    /// Quick check if query likely needs RAG (faster, less accurate)
    func quickRAGCheck(query: String) -> Bool {
        let normalizedQuery = query.lowercased()
        
        // Generic greetings don't need RAG
        let genericPatterns = ["hello", "hi", "hey", "how are you", "help", "who are you"]
        if genericPatterns.contains(where: { normalizedQuery.contains($0) && normalizedQuery.count < 30 }) {
            return false
        }
        
        // Keywords that suggest user wants info from their notes
        let ragKeywords = [
            "my note", "my notes", "in my", "from my", "about my",
            "what did i", "what have i", "what i saved",
            "remember", "search", "find", "show me"
        ]
        
        return ragKeywords.contains { normalizedQuery.contains($0) }
    }
}

