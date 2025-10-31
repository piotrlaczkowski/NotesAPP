import Foundation
import SwiftUI

@MainActor
class SettingsStatusViewModel: ObservableObject {
    @Published var llmStatus: ConfigurationStatus = .unknown
    @Published var githubAuthStatus: ConfigurationStatus = .unknown
    @Published var githubRepoStatus: ConfigurationStatus = .unknown
    @Published var networkStatus: ConfigurationStatus = .unknown
    @Published var pendingSyncCount: Int = 0
    
    private let modelDownloader = ModelDownloader.shared
    private let llmManager = LLMManager.shared
    private let authManager = GitHubAuth.shared
    private let repositoryManager = RepositoryManager.shared
    
    func refreshAll() async {
        await refreshLLMStatus()
        await refreshGitHubAuthStatus()
        await refreshGitHubRepoStatus()
        await refreshNetworkStatus()
        await refreshPendingSyncCount()
    }
    
    func refreshLLMStatus() async {
        let currentModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "LFM2-1.2B"
        let isDownloaded = await modelDownloader.isModelDownloaded(currentModel)
        
        if isDownloaded && llmManager.isModelLoaded && llmManager.currentModel == currentModel {
            llmStatus = .working
        } else if isDownloaded {
            llmStatus = .partial
        } else {
            llmStatus = .notConfigured
        }
    }
    
    func refreshGitHubAuthStatus() async {
        if authManager.hasAuthentication() {
            githubAuthStatus = .configured
        } else {
            githubAuthStatus = .notConfigured
        }
    }
    
    func refreshGitHubRepoStatus() async {
        let owner = UserDefaults.standard.string(forKey: "githubOwner") ?? ""
        let repo = UserDefaults.standard.string(forKey: "githubRepo") ?? ""
        
        if !owner.isEmpty && !repo.isEmpty {
            if authManager.hasAuthentication() {
                githubRepoStatus = .configured
            } else {
                githubRepoStatus = .partial
            }
        } else {
            githubRepoStatus = .notConfigured
        }
    }
    
    func refreshNetworkStatus() async {
        let isConnected = NetworkMonitor.shared.isConnected
        networkStatus = isConnected ? .working : .error
    }
    
    func refreshPendingSyncCount() async {
        // Get count from CommitQueue
        pendingSyncCount = await CommitQueue.shared.count
    }
}

