import Foundation

/// Retrieval-Augmented Generation service for chatting with notes
actor RAGService {
    static let shared = RAGService()
    
    private let searchService = SearchService.shared
    private let noteRepository = NoteRepository.shared
    private let relevanceDetector = RAGRelevanceDetector.shared
    
    private init() {}
    
    /// Search for relevant notes and build context for RAG
    func searchRelevantNotes(query: String, limit: Int = 5) async -> [Note] {
        let allNotes = await noteRepository.fetchAll()
        let searchResults = await searchService.search(notes: allNotes, query: query)
        
        // Get top N most relevant notes
        return Array(searchResults.prefix(limit).map { $0.note })
    }
    
    /// Build context string from notes for LLM prompt
    func buildContext(from notes: [Note]) -> String {
        var contextParts: [String] = []
        
        for (index, note) in notes.enumerated() {
            var noteContext = "Note \(index + 1):\n"
            noteContext += "Title: \(note.title)\n"
            if !note.summary.isEmpty {
                noteContext += "Summary: \(note.summary)\n"
            }
            
            // Include a snippet of content (first 300 chars)
            let contentSnippet = String(note.content.prefix(300))
            if !contentSnippet.isEmpty {
                noteContext += "Content: \(contentSnippet)\(note.content.count > 300 ? "..." : "")\n"
            }
            
            if let category = note.category {
                noteContext += "Category: \(category)\n"
            }
            
            if !note.tags.isEmpty {
                noteContext += "Tags: \(note.tags.joined(separator: ", "))\n"
            }
            
            if let url = note.url {
                noteContext += "Source: \(url.absoluteString)\n"
            }
            
            contextParts.append(noteContext)
        }
        
        return contextParts.joined(separator: "\n---\n\n")
    }
    
    /// Generate a chat response using RAG (if relevant) or generic chat
    func generateResponse(query: String, maxNotes: Int = 5) async throws -> String {
        // Check if RAG is needed
        let (needsRAG, relevantNotes, _) = await relevanceDetector.shouldUseRAG(query: query)
        
        let isModelLoaded = await MainActor.run {
            LLMManager.shared.isModelLoaded
        }
        guard isModelLoaded else {
            throw LLMError(message: "LLM model not loaded. Please download and load a model in Settings.")
        }
        
        if needsRAG && !relevantNotes.isEmpty {
            // Use RAG with context
            let context = buildContext(from: relevantNotes)
            // LLMManager is @MainActor, so we can call it directly with await
            return try await LLMManager.shared.generateChatResponse(prompt: query, context: context)
        } else {
            // Generic chat without context
            // LLMManager is @MainActor, so we can call it directly with await
            return try await LLMManager.shared.generateChatResponse(prompt: query, context: nil)
        }
    }
    
    /// Generate a streaming chat response using RAG (if relevant) or generic chat
    func generateResponseStream(query: String, maxNotes: Int = 5) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Check if RAG is needed
                    let (needsRAG, relevantNotes, _) = await relevanceDetector.shouldUseRAG(query: query)
                    
                    let isModelLoaded = await MainActor.run {
                        LLMManager.shared.isModelLoaded
                    }
                    guard isModelLoaded else {
                        continuation.finish(throwing: LLMError(message: "LLM model not loaded. Please download and load a model in Settings."))
                        return
                    }
                    
                    let context: String?
                    if needsRAG && !relevantNotes.isEmpty {
                        context = buildContext(from: relevantNotes)
                    } else {
                        context = nil
                    }
                    
                    // Get streaming response
                    // LLMManager is @MainActor, so we can call it directly with await
                    let stream = await LLMManager.shared.generateChatResponseStream(prompt: query, context: context)
                    
                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Get source notes used for a response (for citation) - only if RAG was used
    func getSourceNotes(for query: String, maxNotes: Int = 5) async -> [Note] {
        let (needsRAG, relevantNotes, _) = await relevanceDetector.shouldUseRAG(query: query)
        return needsRAG ? relevantNotes : []
    }
    
    /// Check if RAG will be used for a query (for UI indication)
    func willUseRAG(for query: String) async -> Bool {
        let (needsRAG, _, _) = await relevanceDetector.shouldUseRAG(query: query)
        return needsRAG
    }
}

