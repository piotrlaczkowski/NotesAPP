import Foundation

@MainActor
class LLMManager: ObservableObject {
    static let shared = LLMManager()
    
    @Published var currentModel: String?
    @Published var isModelLoaded = false
    @Published var isLoading = false
    
    // Support for multiple specialized models
    private var extractionService: LLMService?
    private var chatService: LLMService?
    private var llmService: LLMService?  // Fallback/legacy support
    private let modelDownloader = ModelDownloader.shared
    
    // Track which models are loaded
    private var loadedExtractionModel: String?
    private var loadedChatModel: String?
    
    private init() {
        // Try to load specialized models first, then fallback to saved preference
        Task { @MainActor [weak self] in
            // First try to load specialized models
            await self?.loadSpecializedModels()
            
            // If no specialized models loaded, use saved preference
            if self?.isModelLoaded == false {
                let savedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "LFM2-1.2B"
                await self?.loadModel(savedModel)
            }
        }
    }
    
    func loadModel(_ modelName: String) async {
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
            
            // Determine which service to assign based on model type
            if modelName.contains("Extract") {
                extractionService = service
                loadedExtractionModel = modelName
            } else if modelName.contains("RAG") {
                chatService = service
                loadedChatModel = modelName
            } else {
                // General purpose model - use as fallback
                llmService = service
                currentModel = modelName
            }
            
            // Update loaded status if we have at least one model
            isModelLoaded = (extractionService != nil || chatService != nil || llmService != nil)
            
            // Save model preference asynchronously to avoid blocking
            Task.detached(priority: .utility) {
                UserDefaults.standard.set(modelName, forKey: "selectedModel")
            }
        } catch {
            print("Error loading model: \(error)")
            isModelLoaded = false
        }
    }
    
    /// Load specialized models for extraction and chat tasks
    func loadSpecializedModels() async {
        let extractionModel = ModelConfig.recommendedModel(for: .extraction)
        let ragModel = ModelConfig.recommendedModel(for: .rag)
        
        // Check if models are downloaded
        let extractionDownloaded = await modelDownloader.isModelDownloaded(extractionModel)
        let ragDownloaded = await modelDownloader.isModelDownloaded(ragModel)
        
        // Auto-download missing specialized models sequentially to avoid conflicts
        if !extractionDownloaded {
            print("📥 Auto-downloading \(extractionModel)...")
            await downloadModel(extractionModel)
        }
        
        // Wait a bit between downloads to avoid conflicts
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if !ragDownloaded {
            print("📥 Auto-downloading \(ragModel)...")
            await downloadModel(ragModel)
        }
        
        // Load models after download
        if await modelDownloader.isModelDownloaded(extractionModel) {
            await loadModel(extractionModel)
        }
        
        if await modelDownloader.isModelDownloaded(ragModel) {
            await loadModel(ragModel)
        }
        
        // If no specialized models loaded, fallback to general model
        if extractionService == nil && chatService == nil {
            let generalModel = ModelConfig.recommendedModel(for: .general)
            if await modelDownloader.isModelDownloaded(generalModel) {
                await loadModel(generalModel)
            }
        }
    }
    
    /// Download a model with progress tracking
    private func downloadModel(_ modelName: String) async {
        // Check if already downloaded first
        if await modelDownloader.isModelDownloaded(modelName) {
            print("✅ Model \(modelName) already downloaded")
            return
        }
        
        do {
            var lastProgress: Double = 0
            try await modelDownloader.download(model: modelName) { progress in
                // Only print significant progress updates
                let roundedProgress = (progress * 10).rounded() / 10
                if abs(roundedProgress - lastProgress) >= 0.1 {
                    print("📥 Downloading \(modelName): \(Int(progress * 100))%")
                    lastProgress = roundedProgress
                }
            }
            print("✅ Successfully downloaded \(modelName)")
        } catch {
            // Handle "download already in progress" gracefully
            if let error = error as? ModelDownloadError,
               case .networkError(let message) = error,
               message.contains("already in progress") {
                print("⏳ Download already in progress for \(modelName), waiting...")
                // Wait for download to complete
                var attempts = 0
                while !(await modelDownloader.isModelDownloaded(modelName)) && attempts < 120 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
                    attempts += 1
                }
                if await modelDownloader.isModelDownloaded(modelName) {
                    print("✅ Model \(modelName) downloaded by concurrent request")
                } else {
                    print("❌ Timeout waiting for \(modelName) download")
                }
            } else {
                print("❌ Failed to download \(modelName): \(error.localizedDescription)")
            }
        }
    }
    
    func analyzeContent(_ content: String, metadata: ContentMetadata? = nil) async throws -> NoteAnalysis {
        // Prefer extraction-specific model
        if let extractionService = extractionService {
            return try await extractionService.analyzeContent(content: content, metadata: metadata)
        }
        
        // Fallback to general model
        guard let service = llmService else {
            throw LLMError(message: "Model not loaded")
        }
        return try await service.analyzeContent(content: content, metadata: metadata)
    }
    
    func generateChatResponse(prompt: String, context: String?) async throws -> String {
        // Prefer RAG-specific model for chat, especially with context
        if context != nil, let chatService = chatService {
            return try await chatService.generateChatResponse(prompt: prompt, context: context)
        }
        
        // Use RAG model for general chat too
        if let chatService = chatService {
            return try await chatService.generateChatResponse(prompt: prompt, context: context)
        }
        
        // Fallback to general model
        guard let service = llmService else {
            throw LLMError(message: "Model not loaded")
        }
        return try await service.generateChatResponse(prompt: prompt, context: context)
    }
    
    func generateChatResponseStream(prompt: String, context: String?) -> AsyncThrowingStream<String, Error> {
        // Prefer RAG-specific model for streaming chat
        if let chatService = chatService {
            return chatService.generateChatResponseStream(prompt: prompt, context: context)
        }
        
        // Fallback to general model
        guard let service = llmService else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: LLMError(message: "Model not loaded"))
            }
        }
        return service.generateChatResponseStream(prompt: prompt, context: context)
    }
    
    /// Generate a LinkedIn post from note summaries
    func generateLinkedInPost(noteSummaries: [String], topic: String? = nil) async throws -> String {
        // Prefer RAG model for content generation
        let service = chatService ?? llmService
        guard let service = service else {
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


