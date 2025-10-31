import Foundation

class GitHubAuth {
    static let shared = GitHubAuth()
    
    private let keychain = KeychainHelper.self
    
    enum AuthMethod {
        case pat
        case oauth
        case ssh
    }
    
    var currentMethod: AuthMethod {
        if keychain.get(forKey: "github_pat") != nil {
            return .pat
        } else if keychain.get(forKey: "github_oauth_token") != nil {
            return .oauth
        } else if keychain.get(forKey: "github_ssh_key") != nil {
            return .ssh
        }
        return .pat
    }
    
    func savePAT(_ token: String) -> Bool {
        return keychain.save(token, forKey: "github_pat")
    }
    
    func getPAT() -> String? {
        return keychain.get(forKey: "github_pat")
    }
    
    func saveOAuthToken(_ token: String) -> Bool {
        return keychain.save(token, forKey: "github_oauth_token")
    }
    
    func getOAuthToken() -> String? {
        return keychain.get(forKey: "github_oauth_token")
    }
    
    func saveSSHKey(_ key: String) -> Bool {
        return keychain.save(key, forKey: "github_ssh_key")
    }
    
    func getSSHKey() -> String? {
        return keychain.get(forKey: "github_ssh_key")
    }
    
    func getAuthHeader() -> String? {
        switch currentMethod {
        case .pat:
            if let token = getPAT() {
                return "token \(token)"
            }
        case .oauth:
            if let token = getOAuthToken() {
                return "Bearer \(token)"
            }
        case .ssh:
            // SSH requires different authentication method
            return nil
        }
        return nil
    }
    
    func hasAuthentication() -> Bool {
        return getAuthHeader() != nil
    }
}

