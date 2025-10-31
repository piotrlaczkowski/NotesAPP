import Foundation

protocol LLMService {
    func loadModel(modelPath: String) async throws
    func analyzeContent(content: String, metadata: ContentMetadata?) async throws -> NoteAnalysis
    func generateSummary(content: String) async throws -> String
    func suggestTags(content: String) async throws -> [String]
    func generateTitle(content: String) async throws -> String
    var isModelLoaded: Bool { get }
}

struct LLMError: Error {
    let message: String
}

