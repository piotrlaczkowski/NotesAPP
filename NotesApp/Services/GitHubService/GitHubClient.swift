import Foundation

actor GitHubClient {
    static let shared = GitHubClient()
    
    private let auth = GitHubAuth.shared
    private let baseURL = "https://api.github.com"
    
    private init() {}
    
    func createOrUpdateFile(path: String, content: String, message: String, owner: String, repo: String, branch: String = "main") async throws {
        // Get SHA of existing file if it exists
        let sha = try? await getFileSHA(path: path, owner: owner, repo: repo, branch: branch)
        
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authHeader = auth.getAuthHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        // Content should already be base64-encoded
        var body: [String: Any] = [
            "message": message,
            "content": content,
            "branch": branch
        ]
        
        if let sha = sha {
            body["sha"] = sha
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GitHubError.apiError("Failed to create/update file")
        }
    }
    
    func getFile(path: String, owner: String, repo: String, branch: String = "main") async throws -> String {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)?ref=\(branch)")!
        var request = URLRequest(url: url)
        
        if let authHeader = auth.getAuthHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GitHubError.apiError("Failed to get file")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? String,
              let decoded = Data(base64Encoded: content, options: .ignoreUnknownCharacters),
              let text = String(data: decoded, encoding: .utf8) else {
            throw GitHubError.decodingError
        }
        
        return text
    }
    
    func listFiles(path: String = "", owner: String, repo: String, branch: String = "main") async throws -> [GitHubFile] {
        // Validate inputs
        guard !owner.isEmpty && !repo.isEmpty else {
            throw GitHubError.apiError("Owner and repo must be specified")
        }
        
        // Check authentication
        guard auth.hasAuthentication() else {
            throw GitHubError.authenticationError
        }
        
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)?ref=\(branch)")!
        var request = URLRequest(url: url)
        
        if let authHeader = auth.getAuthHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.apiError("Invalid response from GitHub API")
        }
        
        // Handle 404 - directory doesn't exist yet
        if httpResponse.statusCode == 404 {
            throw GitHubError.apiError("404 Not Found - Directory may not exist yet")
        }
        
        // Handle 401/403 - authentication issues
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw GitHubError.authenticationError
        }
        
        // Handle other errors
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitHubError.apiError("GitHub API error (\(httpResponse.statusCode)): \(errorMessage)")
        }
        
        // Handle empty directory (returns object instead of array)
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           jsonObject["type"] as? String == "file" {
            // Single file, not a directory - return empty array
            return []
        }
        
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // Might be an empty directory or different structure
            return []
        }
        
        return jsonArray.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let type = dict["type"] as? String else {
                return nil
            }
            return GitHubFile(name: name, type: type == "file" ? .file : .directory)
        }
    }
    
    private func getFileSHA(path: String, owner: String, repo: String, branch: String) async throws -> String? {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)?ref=\(branch)")!
        var request = URLRequest(url: url)
        
        if let authHeader = auth.getAuthHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return nil
        }
        
        if httpResponse.statusCode == 404 {
            return nil // File doesn't exist
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sha = json["sha"] as? String else {
            return nil
        }
        
        return sha
    }
}

struct GitHubFile {
    let name: String
    let type: FileType
    
    enum FileType {
        case file
        case directory
    }
}

enum GitHubError: Error {
    case apiError(String)
    case decodingError
    case authenticationError
}

