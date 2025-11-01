import Foundation

@MainActor
class LLMManager: ObservableObject {
    static let shared = LLMManager()
    
    @Published var currentModel: String?
    @Published var isModelLoaded = false
    @Published var isLoading = false
    
    private var llmService: LLMService?
    private let modelDownloader = ModelDownloader.shared
    
    private init() {
        // Load saved model preference asynchronously to avoid blocking init
        Task.detached(priority: .utility) { [weak self] in
            let savedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "LFM2-1.2B"
            await MainActor.run {
                Task {
                    await self?.loadModel(savedModel)
                }
            }
        }
    }
    
    func loadModel(_ modelName: String) async {
        guard currentModel != modelName else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Check if model is downloaded
        let isDownloaded = await modelDownloader.isModelDownloaded(modelName)
        guard isDownloaded else {
            // Model needs to be downloaded first
            return
        }
        
        // Get model path
        guard let modelPath = await modelDownloader.getModelPath(for: modelName) else {
            return
        }
        let pathString = modelPath.path
        
        // Create and load service
        let service = MLCLLMService()
        
        do {
            try await service.loadModel(modelPath: pathString)
            llmService = service
            currentModel = modelName
            isModelLoaded = true
            // Save model preference asynchronously to avoid blocking
            Task.detached(priority: .utility) {
                UserDefaults.standard.set(modelName, forKey: "selectedModel")
            }
        } catch {
            print("Error loading model: \(error)")
            isModelLoaded = false
        }
    }
    
    func analyzeContent(_ content: String, metadata: ContentMetadata? = nil) async throws -> NoteAnalysis {
        guard let service = llmService else {
            throw LLMError(message: "Model not loaded")
        }
        return try await service.analyzeContent(content: content, metadata: metadata)
    }
    
    func generateChatResponse(prompt: String, context: String?) async throws -> String {
        guard let service = llmService else {
            throw LLMError(message: "Model not loaded")
        }
        return try await service.generateChatResponse(prompt: prompt, context: context)
    }
    
    func generateChatResponseStream(prompt: String, context: String?) -> AsyncThrowingStream<String, Error> {
        guard let service = llmService else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: LLMError(message: "Model not loaded"))
            }
        }
        return service.generateChatResponseStream(prompt: prompt, context: context)
    }
    
    var service: LLMService? {
        llmService
    }
}


