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
    private let session: URLSession
    private var activeDownloads: [String: URLSessionDownloadTask] = [:]
    
    private init() {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        modelsDirectory = paths[0].appendingPathComponent("Models", isDirectory: true)
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        // Configure URLSession to properly handle redirects and timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300.0 // 5 minutes
        config.timeoutIntervalForResource = 3600.0 // 1 hour for large downloads
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        self.session = URLSession(configuration: config)
    }
    
    /// Optional: Save Hugging Face token for better reliability and rate limits
    static func saveHFToken(_ token: String) -> Bool {
        return KeychainHelper.save(token, forKey: "huggingface_token")
    }
    
    /// Get Hugging Face token if set (optional)
    private func getHFToken() -> String? {
        return KeychainHelper.get(forKey: "huggingface_token")
    }
    
    /// Check if Hugging Face token is set
    static func hasHFToken() -> Bool {
        return KeychainHelper.get(forKey: "huggingface_token") != nil
    }
    
    func download(model: String, progress: @escaping (Double) -> Void) async throws {
        guard let config = ModelConfig.config(for: model) else {
            throw ModelDownloadError.invalidModel
        }
        
        let destinationURL = modelsDirectory.appendingPathComponent(config.localPath)
        
        // Check if already downloaded (with file size verification)
        if fileManager.fileExists(atPath: destinationURL.path) {
            // Verify file is not empty (might be corrupted/incomplete)
            if let attributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
               let fileSize = attributes[.size] as? Int64,
               fileSize > 0 {
                print("ModelDownloader: Model \(model) already downloaded (\(fileSize) bytes)")
                await MainActor.run {
                    progress(1.0)
                }
                return
            } else {
                // File exists but might be corrupted, remove it
                print("ModelDownloader: Existing file for \(model) appears corrupted, removing...")
                try? fileManager.removeItem(at: destinationURL)
            }
        }
        
        // Prevent concurrent downloads of the same model
        if activeDownloads[model] != nil {
            print("ModelDownloader: Download already in progress for \(model), skipping")
            throw ModelDownloadError.networkError("Download already in progress for this model")
        }
        
        // First, try to discover the actual GGUF file name using Hugging Face API
        let discoveredURLs = await discoverModelFile(model: model, repoPath: config.repoPath)
        
        // Combine URLs: discovered first (most likely to work), then primary, then alternatives
        var allURLs = discoveredURLs
        
        // Only add fallback URLs if we didn't discover anything
        if discoveredURLs.isEmpty {
            print("ModelDownloader: ⚠️ No GGUF files discovered via API, trying fallback URLs")
            allURLs.append(config.downloadURL)
            // Remove generic "model.gguf" from alternatives since it doesn't exist
            let alternatives = ModelConfig.alternativeURLs(for: model).filter { !$0.contains("model.gguf") }
            allURLs.append(contentsOf: alternatives)
        } else {
            print("ModelDownloader: ✓ Using \(discoveredURLs.count) discovered URL(s), skipping fallbacks")
        }
        var lastError: Error?
        
        print("ModelDownloader: Starting download for model '\(model)', trying \(allURLs.count) URL(s)")
        
        for (index, urlString) in allURLs.enumerated() {
            guard let url = URL(string: urlString) else {
                print("ModelDownloader: Invalid URL format: \(urlString)")
                continue
            }
            
            print("ModelDownloader: Attempting download (\(index + 1)/\(allURLs.count)): \(urlString)")
            
            // Create request with proper headers (Hugging Face may require User-Agent)
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            request.setValue("*/*", forHTTPHeaderField: "Accept") // Accept any file type for downloads
            request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.httpMethod = "GET"
            
            // Add Hugging Face token if available (optional, improves reliability)
            if let token = getHFToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            do {
                // Calculate base progress for this URL attempt (so progress doesn't restart)
                let baseProgress = Double(index) / Double(allURLs.count)
                
                // Use async download with progress tracking
                let delegate = ProgressDownloadDelegate(progressCallback: { currentProgress in
                    // Adjust progress to account for URL attempt index
                    // Each URL attempt contributes 1/allURLs.count to total progress
                    let adjustedProgress = baseProgress + (currentProgress / Double(allURLs.count))
                    let clampedProgress = min(adjustedProgress, 1.0)
                    Task { @MainActor in
                        progress(clampedProgress)
                    }
                })
                let progressSession = URLSession(configuration: session.configuration, delegate: delegate, delegateQueue: nil)
                
                // Create and store download task to track active downloads
                let downloadTask = progressSession.downloadTask(with: request)
                activeDownloads[model] = downloadTask
                downloadTask.resume()
                
                // Wait for completion
                let (localURL, response) = try await delegate.download(using: progressSession, with: request)
                
                // Clear active download
                activeDownloads.removeValue(forKey: model)
                
                // Clean up session after completion
                progressSession.finishTasksAndInvalidate()
                
                // Validate HTTP response
                if let httpResponse = response as? HTTPURLResponse {
                    guard (200...299).contains(httpResponse.statusCode) else {
                        let errorMsg = "Server returned status code \(httpResponse.statusCode) for URL: \(urlString)"
                        print("ModelDownloader: \(errorMsg)")
                        
                        // If this is not the last URL, try the next one
                        if index < allURLs.count - 1 {
                            print("ModelDownloader: Trying next URL...")
                            continue
                        }
                        throw ModelDownloadError.networkError("Server returned status code \(httpResponse.statusCode) for all attempted URLs. Last attempted: \(urlString)")
                    }
                    print("ModelDownloader: Successfully downloaded from: \(httpResponse.url?.absoluteString ?? urlString)")
                }
                
                // Move to destination
                do {
                    // Remove existing file if present
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.moveItem(at: localURL, to: destinationURL)
                    await MainActor.run {
                        progress(1.0)
                    }
                    activeDownloads.removeValue(forKey: model)
                    return // Success!
                } catch {
                    activeDownloads.removeValue(forKey: model)
                    throw ModelDownloadError.fileSystemError(error)
                }
            } catch let error as ModelDownloadError {
                print("ModelDownloader: Error (ModelDownloadError): \(error.localizedDescription)")
                lastError = error
                activeDownloads.removeValue(forKey: model)
                // If this is the last URL, throw the error
                if index >= allURLs.count - 1 {
                    await MainActor.run {
                        progress(0.0)
                    }
                    throw error
                }
                // Otherwise, continue to next URL (progress maintained at current level)
                continue
            } catch {
                print("ModelDownloader: Error (general): \(error.localizedDescription)")
                lastError = error
                activeDownloads.removeValue(forKey: model)
                // If this is the last URL, throw the error
                if index >= allURLs.count - 1 {
                    await MainActor.run {
                        progress(0.0)
                    }
                    throw ModelDownloadError.downloadFailed(error)
                }
                // Otherwise, continue to next URL (progress maintained)
                continue
            }
        }
        
        // If we get here, all URLs failed
        activeDownloads.removeValue(forKey: model)
        await MainActor.run {
            progress(0.0)
        }
        throw lastError ?? ModelDownloadError.networkError("All download URLs failed. The model may not be available or the repository structure has changed.")
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
    
    /// Discover actual GGUF files in Hugging Face repository using their API
    private func discoverModelFile(model: String, repoPath: String) async -> [String] {
        var discoveredURLs: [String] = []
        
        print("ModelDownloader: Starting discovery for \(repoPath)")
        
        // Helper to fetch files from a path
        func fetchFiles(from path: String) async -> [[String: Any]]? {
            let baseURL = "https://huggingface.co/api/models/\(repoPath)/tree/main"
            let apiURL = path.isEmpty ? baseURL : "\(baseURL)/\(path)"
            
            print("ModelDownloader: Fetching files from: \(apiURL)")
            
            guard let url = URL(string: apiURL) else {
                print("ModelDownloader: Invalid URL: \(apiURL)")
                return nil
            }
            
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10.0
            
            if let token = getHFToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("ModelDownloader: Using Hugging Face token for authentication")
            }
            
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("ModelDownloader: No HTTP response")
                    return nil
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
                    print("ModelDownloader: API returned \(httpResponse.statusCode) for \(path): \(errorBody.prefix(200))")
                    return nil
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    print("ModelDownloader: Failed to parse JSON for \(path)")
                    // Try as single object
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("ModelDownloader: Got object instead of array: \(jsonObject.keys.joined(separator: ", "))")
                    }
                    return nil
                }
                
                print("ModelDownloader: Found \(json.count) items in \(path.isEmpty ? "root" : path)")
                return json
            } catch {
                print("ModelDownloader: Error fetching \(path): \(error.localizedDescription)")
                return nil
            }
        }
        
        // First, try checking if there's a separate GGUF repository (e.g., LiquidAI/LFM2-1.2B-GGUF)
        let repoParts = repoPath.split(separator: "/")
        let org = String(repoParts[0])
        let ggufRepoPath = "\(org)/\(model)-GGUF"
        print("ModelDownloader: Checking for separate GGUF repo: \(ggufRepoPath)")
        
        // Helper to fetch from specific repo
        func fetchFilesFromRepo(_ repo: String, path: String) async -> [[String: Any]]? {
            let baseURL = "https://huggingface.co/api/models/\(repo)/tree/main"
            let apiURL = path.isEmpty ? baseURL : "\(baseURL)/\(path)"
            print("ModelDownloader: Fetching from repo \(repo): \(apiURL)")
            
            guard let url = URL(string: apiURL) else { return nil }
            
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10.0
            
            if let token = getHFToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    return nil
                }
                return json
            } catch {
                return nil
            }
        }
        
        if let ggufFiles = await fetchFilesFromRepo(ggufRepoPath, path: "") {
            for item in ggufFiles {
                if let path = item["path"] as? String,
                   path.hasSuffix(".gguf"),
                   let fileSize = item["size"] as? Int,
                   fileSize > 0 {
                    let downloadURL = "https://huggingface.co/\(ggufRepoPath)/resolve/main/\(path)"
                    discoveredURLs.append(downloadURL)
                    print("ModelDownloader: ✓ Found GGUF in separate repo: \(path) (\(fileSize / 1_000_000)MB)")
                }
            }
        }
        
        // If we found files in GGUF repo, use those
        if !discoveredURLs.isEmpty {
            print("ModelDownloader: Using GGUF repository: \(ggufRepoPath)")
            return discoveredURLs
        }
        
        
        // Try multiple locations where GGUF files might be in the main repo
        print("ModelDownloader: Checking main repository: \(repoPath)")
        
        // Collect files with their paths and sizes for sorting
        struct DiscoveredFile {
            let url: String
            let size: Int
            let path: String
        }
        var allFiles: [DiscoveredFile] = []
        
        // 1. Check root directory
        if let files = await fetchFiles(from: "") {
            for item in files {
                if let path = item["path"] as? String,
                   path.hasSuffix(".gguf"),
                   let fileSize = item["size"] as? Int,
                   fileSize > 0 {
                    let downloadURL = "https://huggingface.co/\(repoPath)/resolve/main/\(path)"
                    allFiles.append(DiscoveredFile(url: downloadURL, size: fileSize, path: path))
                    print("ModelDownloader: Discovered GGUF file: \(path) (\(fileSize) bytes)")
                }
            }
        }
        
        // 2. Check quantized models (common location)
        if let files = await fetchFiles(from: "quantized") {
            for item in files {
                if let path = item["path"] as? String,
                   path.hasSuffix(".gguf"),
                   let fileSize = item["size"] as? Int,
                   fileSize > 0 {
                    let downloadURL = "https://huggingface.co/\(repoPath)/resolve/main/quantized/\(path)"
                    allFiles.append(DiscoveredFile(url: downloadURL, size: fileSize, path: "quantized/\(path)"))
                    print("ModelDownloader: Discovered quantized GGUF: quantized/\(path) (\(fileSize) bytes)")
                }
            }
        }
        
        // 3. Try common quantized folder names
        for folder in ["gguf", "gguf-quantized", "models", "gguf_models"] {
            if let files = await fetchFiles(from: folder) {
                for item in files {
                    if let path = item["path"] as? String,
                       path.hasSuffix(".gguf"),
                       let fileSize = item["size"] as? Int,
                       fileSize > 0 {
                        let downloadURL = "https://huggingface.co/\(repoPath)/resolve/main/\(folder)/\(path)"
                        allFiles.append(DiscoveredFile(url: downloadURL, size: fileSize, path: "\(folder)/\(path)"))
                        print("ModelDownloader: Discovered GGUF in \(folder): \(path) (\(fileSize) bytes)")
                    }
                }
            }
        }
        
        // Sort by size (prefer smaller files for mobile, but also prefer Q4_K_M quantization)
        allFiles.sort { file1, file2 in
            // Prefer Q4_K_M quantization
            let q4_1 = file1.path.contains("Q4_K_M") || file1.path.contains("q4_k_m")
            let q4_2 = file2.path.contains("Q4_K_M") || file2.path.contains("q4_k_m")
            if q4_1 != q4_2 {
                return q4_1
            }
            // Otherwise prefer smaller files
            return file1.size < file2.size
        }
        
        discoveredURLs = allFiles.map { $0.url }
        
        print("ModelDownloader: Discovered \(discoveredURLs.count) GGUF file(s) from API")
        return discoveredURLs
    }
}

// Delegate for tracking download progress
class ProgressDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let progressCallback: (Double) -> Void
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    
    init(progressCallback: @escaping (Double) -> Void) {
        self.progressCallback = progressCallback
        super.init()
    }
    
    func download(using session: URLSession, with request: URLRequest) async throws -> (URL, URLResponse) {
        // This method is called after task.resume() is already called
        // So we just need to wait for the completion
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            // Task is already resumed in the caller
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // Calculate progress, handle unknown size (-1)
        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            // If size is unknown, show indeterminate progress (0.5 = halfway)
            progress = min(0.95, Double(totalBytesWritten) / 1_000_000_000.0) // Estimate based on bytes
        }
        DispatchQueue.main.async {
            self.progressCallback(progress)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let response = downloadTask.response ?? URLResponse()
        continuation?.resume(returning: (location, response))
        continuation = nil
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

