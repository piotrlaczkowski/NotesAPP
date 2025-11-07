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
            let modelToLoad = savedModel
            await MainActor.run {
                Task { @MainActor [weak self] in
                    await self?.loadModel(modelToLoad)
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
    
    /// Generate a LinkedIn post from note summaries
    func generateLinkedInPost(noteSummaries: [String], topic: String? = nil) async throws -> String {
        guard let service = llmService else {
            throw LLMError(message: "Model not loaded")
        }
        
        // Build context from note summaries - include all summaries
        var context = "Recent interesting findings (\(noteSummaries.count) items):\n\n"
        for (index, summary) in noteSummaries.enumerated() {
            // Include full summary for each note
            context += "\(index + 1). \(summary)\n"
            if index < noteSummaries.count - 1 {
                context += "\n" // Add spacing between items
            }
        }
        
        // Create prompt for LinkedIn post generation
        let topicContext = topic.map { " about \($0)" } ?? ""
        let prompt = """
        You are a social media expert specializing in LinkedIn content. \
        Create an engaging LinkedIn post\(topicContext) based on these \(noteSummaries.count) recent interesting findings. \
        
        CRITICAL REQUIREMENTS:
        1. Include ALL \(noteSummaries.count) findings in your post - do not skip any
        2. For each finding, include:
           - The title or main topic
           - A brief summary of what it is
           - Why it's important, interesting, or useful
           - The source URL if available (format as clickable link or mention the domain)
        3. Explain the significance and value of each finding
        4. Make connections between findings if relevant
        5. Keep the tone professional yet engaging and conversational
        
        The post should highlight the most interesting insights from each finding, explain why they matter, \
        and be suitable for sharing on LinkedIn. Format as a complete LinkedIn post with proper structure. \
        Include relevant hashtags at the end.
        
        Ensure each of the \(noteSummaries.count) findings gets proper attention and explanation.
        """
        
        return try await service.generateChatResponse(prompt: prompt, context: context)
    }
    
    var service: LLMService? {
        llmService
    }
}


