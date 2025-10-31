import Foundation

struct ModelConfig {
    let name: String
    let size: String
    let downloadURL: String
    let localPath: String
    
    static let availableModels: [ModelConfig] = [
        ModelConfig(
            name: "LFM2-350M",
            size: "350M",
            downloadURL: "https://huggingface.co/liquidai/LFM2-350M/resolve/main/model.gguf",
            localPath: "LFM2-350M.gguf"
        ),
        ModelConfig(
            name: "LFM2-700M",
            size: "700M",
            downloadURL: "https://huggingface.co/liquidai/LFM2-700M/resolve/main/model.gguf",
            localPath: "LFM2-700M.gguf"
        ),
        ModelConfig(
            name: "LFM2-1.2B",
            size: "1.2B",
            downloadURL: "https://huggingface.co/liquidai/LFM2-1.2B/resolve/main/model.gguf",
            localPath: "LFM2-1.2B.gguf"
        )
    ]
    
    static func config(for name: String) -> ModelConfig? {
        return availableModels.first { $0.name == name }
    }
}

