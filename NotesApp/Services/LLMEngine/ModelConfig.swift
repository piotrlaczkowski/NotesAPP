import Foundation

struct ModelConfig {
    let name: String
    let size: String
    let downloadURL: String
    let localPath: String
    let repoPath: String // e.g., "LiquidAI/LFM2-350M"
    
    static let availableModels: [ModelConfig] = [
        ModelConfig(
            name: "LFM2-350M",
            size: "350M",
            downloadURL: "https://huggingface.co/LiquidAI/LFM2-350M/resolve/main/LFM2-350M.gguf",
            localPath: "LFM2-350M.gguf",
            repoPath: "LiquidAI/LFM2-350M"
        ),
        ModelConfig(
            name: "LFM2-700M",
            size: "700M",
            downloadURL: "https://huggingface.co/LiquidAI/LFM2-700M/resolve/main/LFM2-700M.gguf",
            localPath: "LFM2-700M.gguf",
            repoPath: "LiquidAI/LFM2-700M"
        ),
        ModelConfig(
            name: "LFM2-1.2B",
            size: "1.2B",
            downloadURL: "https://huggingface.co/LiquidAI/LFM2-1.2B/resolve/main/LFM2-1.2B.gguf",
            localPath: "LFM2-1.2B.gguf",
            repoPath: "LiquidAI/LFM2-1.2B"
        ),
        ModelConfig(
            name: "LFM2-1.2B-Extract",
            size: "1.2B",
            downloadURL: "https://huggingface.co/LiquidAI/LFM2-1.2B-Extract/resolve/main/LFM2-1.2B-Extract.gguf",
            localPath: "LFM2-1.2B-Extract.gguf",
            repoPath: "LiquidAI/LFM2-1.2B-Extract"
        ),
        ModelConfig(
            name: "LFM2-1.2B-RAG",
            size: "1.2B",
            downloadURL: "https://huggingface.co/LiquidAI/LFM2-1.2B-RAG/resolve/main/LFM2-1.2B-RAG.gguf",
            localPath: "LFM2-1.2B-RAG.gguf",
            repoPath: "LiquidAI/LFM2-1.2B-RAG"
        )
    ]
    
    /// Get the recommended model for a specific task
    static func recommendedModel(for task: ModelTask) -> String {
        switch task {
        case .extraction:
            return "LFM2-1.2B-Extract"
        case .chat, .rag:
            return "LFM2-1.2B-RAG"
        case .general:
            return "LFM2-1.2B"
        }
    }
    
    /// Check if a model is specialized for a task
    static func isSpecializedModel(_ modelName: String, for task: ModelTask) -> Bool {
        switch task {
        case .extraction:
            return modelName.contains("Extract")
        case .chat, .rag:
            return modelName.contains("RAG")
        case .general:
            return !modelName.contains("Extract") && !modelName.contains("RAG")
        }
    }
    
    enum ModelTask {
        case extraction  // For extracting metadata from URLs/content
        case chat       // For general chat
        case rag        // For RAG-based chat with context
        case general    // General purpose
    }
    
    // Alternative URLs to try if primary fails (common GGUF filename patterns)
    static func alternativeURLs(for model: String) -> [String] {
        guard let config = config(for: model) else { return [] }
        
        let modelName = model
        let primaryURL = config.downloadURL.lowercased()
        let repoPath = config.repoPath
        
        var alternatives: [String] = []
        
        // Try different URL patterns and filename variations
        var patterns: [String] = []
        
        // Try resolve/main with different filenames
        patterns.append("https://huggingface.co/\(repoPath)/resolve/main/model.gguf")
        patterns.append("https://huggingface.co/\(repoPath)/resolve/main/\(modelName).gguf")
        patterns.append("https://huggingface.co/\(repoPath)/resolve/main/\(modelName)-Q4_K_M.gguf")
        patterns.append("https://huggingface.co/\(repoPath)/resolve/main/\(modelName.lowercased()).gguf")
        patterns.append("https://huggingface.co/\(repoPath)/resolve/main/\(modelName)-Q8_0.gguf")
        patterns.append("https://huggingface.co/\(repoPath)/resolve/main/\(modelName)-f16.gguf")
        
        // Try with download parameter
        patterns.append("https://huggingface.co/\(repoPath)/resolve/main/\(modelName).gguf?download=true")
        patterns.append("https://huggingface.co/\(repoPath)/resolve/main/model.gguf?download=true")
        
        // Remove hf.co - it's causing issues, use huggingface.co only
        
        for pattern in patterns {
            // Only add if it's different from the primary URL
            if pattern.lowercased() != primaryURL {
                alternatives.append(pattern)
            }
        }
        
        return alternatives
    }
    
    static func config(for name: String) -> ModelConfig? {
        return availableModels.first { $0.name == name }
    }
}

