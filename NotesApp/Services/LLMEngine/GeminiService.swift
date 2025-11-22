import Foundation

class GeminiService: LLMService {
    private let apiKey: String
    private let modelName: String
    
    var isModelLoaded: Bool {
        return !apiKey.isEmpty
    }
    
    init(apiKey: String, modelName: String = "gemini-1.5-flash") {
        self.apiKey = apiKey
        self.modelName = modelName
    }
    
    func loadModel(modelPath: String) async throws {
        // No-op for API based service
    }
    
    func analyzeContent(content: String, metadata: ContentMetadata?) async throws -> NoteAnalysis {
        let prompt = """
        Analyze the following content and extract structured information.
        
        Content:
        \(content.prefix(10000))
        
        Metadata:
        \(metadata?.description ?? "None")
        
        Return the result as a valid JSON object with the following keys:
        - title: A concise and descriptive title
        - summary: A comprehensive summary of the content (2-3 sentences)
        - tags: A list of relevant tags (max 5)
        - category: The most appropriate category from: Research Paper, Code Repository, Tutorial, Article, Documentation, News, Video, Podcast, Book, General
        - whatIsIt: A brief description of what this content represents
        - whyAdvantageous: Why this content is useful or advantageous
        
        JSON:
        """
        
        let response = try await generateContent(prompt: prompt)
        
        // Parse JSON from response
        // Gemini might wrap JSON in markdown code blocks
        let jsonString = cleanJsonString(response)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw LLMError(message: "Failed to convert response to data")
        }
        
        do {
            return try JSONDecoder().decode(NoteAnalysis.self, from: data)
        } catch {
            print("JSON Decode Error: \(error)")
            print("JSON String: \(jsonString)")
            throw LLMError(message: "Failed to parse Gemini response")
        }
    }
    
    func generateSummary(content: String) async throws -> String {
        let prompt = "Summarize the following content in 2-3 sentences:\n\n\(content.prefix(10000))"
        return try await generateContent(prompt: prompt)
    }
    
    func suggestTags(content: String) async throws -> [String] {
        let prompt = "Suggest 5 relevant tags for the following content. Return only the tags as a comma-separated list:\n\n\(content.prefix(10000))"
        let response = try await generateContent(prompt: prompt)
        return response.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    func generateTitle(content: String) async throws -> String {
        let prompt = "Generate a concise title for the following content:\n\n\(content.prefix(10000))"
        return try await generateContent(prompt: prompt).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func generateChatResponse(prompt: String, context: String?) async throws -> String {
        var fullPrompt = prompt
        if let context = context {
            fullPrompt = "Context:\n\(context)\n\nQuestion: \(prompt)"
        }
        return try await generateContent(prompt: fullPrompt)
    }
    
    func generateChatResponseStream(prompt: String, context: String?) -> AsyncThrowingStream<String, Error> {
        // For now, just non-streaming implementation wrapped in stream
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await generateChatResponse(prompt: prompt, context: context)
                    continuation.yield(response)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func generateContent(prompt: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw LLMError(message: "Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError(message: "Gemini API Error: \(errorMsg)")
        }
        
        // Parse response
        // Structure: candidates[0].content.parts[0].text
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw LLMError(message: "Unexpected response format")
        }
        
        return text
    }
    
    private func cleanJsonString(_ string: String) -> String {
        var cleaned = string
        if let range = cleaned.range(of: "```json") {
            cleaned.removeSubrange(range)
        }
        if let range = cleaned.range(of: "```") {
            cleaned.removeSubrange(range)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
