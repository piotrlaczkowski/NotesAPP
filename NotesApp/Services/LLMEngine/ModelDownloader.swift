import Foundation

enum ModelDownloadError: LocalizedError {
    case invalidModel
    case invalidURL
    case downloadFailed(Error)
    case fileSystemError(Error)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidModel:
            return "Invalid model name. Please select a valid model."
        case .invalidURL:
            return "Invalid download URL for this model."
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

actor ModelDownloader {
    static let shared = ModelDownloader()
    
    private let fileManager = FileManager.default
    private let modelsDirectory: URL
    
    private init() {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        modelsDirectory = paths[0].appendingPathComponent("Models", isDirectory: true)
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }
    
    func download(model: String, progress: @escaping (Double) -> Void) async throws {
        guard let config = ModelConfig.config(for: model) else {
            throw ModelDownloadError.invalidModel
        }
        
        let destinationURL = modelsDirectory.appendingPathComponent(config.localPath)
        
        // Check if already downloaded
        if fileManager.fileExists(atPath: destinationURL.path) {
            progress(1.0)
            return
        }
        
        guard let url = URL(string: config.downloadURL) else {
            throw ModelDownloadError.invalidURL
        }
        
        let session = URLSession.shared
        
        do {
            // Download the file (this will also validate the response)
            let (localURL, response) = try await session.download(from: url)
            
            // Validate HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw ModelDownloadError.networkError("Server returned status code \(httpResponse.statusCode)")
                }
            }
            
            // Move to destination
            do {
                // Remove existing file if present
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: localURL, to: destinationURL)
                progress(1.0)
            } catch {
                throw ModelDownloadError.fileSystemError(error)
            }
        } catch let error as ModelDownloadError {
            progress(0.0)
            throw error
        } catch {
            progress(0.0)
            throw ModelDownloadError.downloadFailed(error)
        }
    }
    
    func getModelPath(for model: String) -> URL? {
        guard let config = ModelConfig.config(for: model) else {
            return nil
        }
        
        let path = modelsDirectory.appendingPathComponent(config.localPath)
        return fileManager.fileExists(atPath: path.path) ? path : nil
    }
    
    func isModelDownloaded(_ model: String) -> Bool {
        guard let config = ModelConfig.config(for: model) else {
            return false
        }
        
        let path = modelsDirectory.appendingPathComponent(config.localPath)
        return fileManager.fileExists(atPath: path.path)
    }
}

