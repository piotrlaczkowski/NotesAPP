import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var statusViewModel = SettingsStatusViewModel()
    @AppStorage("selectedModel") private var selectedModel = "LFM2-1.2B"
    @AppStorage("autoSyncEnabled") private var autoSyncEnabled = true
    @AppStorage("syncInterval") private var syncInterval = 15
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Status Overview") {
                    SettingsStatusIndicator(
                        status: statusViewModel.llmStatus,
                        title: "LLM Model",
                        description: llmStatusDescription
                    )
                    
                    SettingsStatusIndicator(
                        status: statusViewModel.githubAuthStatus,
                        title: "GitHub Authentication",
                        description: githubAuthDescription
                    )
                    
                    SettingsStatusIndicator(
                        status: statusViewModel.githubRepoStatus,
                        title: "GitHub Repository",
                        description: githubRepoDescription
                    )
                    
                    SettingsStatusIndicator(
                        status: statusViewModel.networkStatus,
                        title: "Network Connection",
                        description: networkStatusDescription
                    )
                    
                    if statusViewModel.pendingSyncCount > 0 {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.orange)
                            Text("\(statusViewModel.pendingSyncCount) notes pending sync")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("LLM Model") {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(viewModel.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .onChange(of: selectedModel) { _, newValue in
                        Task {
                            await viewModel.selectModel(newValue)
                        }
                    }
                    
                    if let status = viewModel.modelStatus {
                        HStack {
                            Text("Status:")
                            Spacer()
                            Text(status)
                                .foregroundColor(status.contains("✓") ? .green : (status.contains("✗") ? .red : .secondary))
                                .font(.subheadline)
                        }
                    }
                    
                    if viewModel.isDownloading {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: viewModel.downloadProgress)
                            Text("Downloading... \(Int(viewModel.downloadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("This may take several minutes depending on model size and connection speed.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else if viewModel.needsDownload {
                        Button {
                            Task {
                                await viewModel.downloadModel(selectedModel)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Download Model")
                            }
                        }
                        
                        // Show model size info
                        if let config = ModelConfig.config(for: selectedModel) {
                            Text("Size: \(config.size)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button("Reload Model") {
                            Task {
                                await viewModel.selectModel(selectedModel)
                            }
                        }
                    }
                }
                .alert("Download Error", isPresented: $viewModel.showError) {
                    Button("OK") {
                        viewModel.showError = false
                    }
                    Button("Retry") {
                        Task {
                            await viewModel.downloadModel(selectedModel)
                        }
                    }
                } message: {
                    if let error = viewModel.errorMessage {
                        Text(error)
                    }
                }
                
                Section("GitHub Sync") {
                    NavigationLink("Authentication") {
                        GitHubAuthView()
                    }
                    
                    NavigationLink("Repository") {
                        GitHubRepositoryView()
                    }
                    
                    Toggle("Auto Sync", isOn: $autoSyncEnabled)
                    
                    if autoSyncEnabled {
                        Picker("Sync Interval (minutes)", selection: $syncInterval) {
                            Text("5").tag(5)
                            Text("15").tag(15)
                            Text("30").tag(30)
                            Text("60").tag(60)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // Manual sync controls
                    SyncControlsView()
                }
                
                Section("Appearance") {
                    NavigationLink("Theme") {
                        ThemeSettingsView()
                    }
                }
                
                Section("Categories") {
                    NavigationLink("Manage Categories") {
                        CategoryManagementView()
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            await viewModel.loadModelStatus()
            await statusViewModel.refreshAll()
        }
        .onChange(of: selectedModel) { _, _ in
            Task {
                await statusViewModel.refreshLLMStatus()
            }
        }
        .refreshable {
            await statusViewModel.refreshAll()
            await viewModel.loadModelStatus()
        }
    }
    
    private var llmStatusDescription: String {
        switch statusViewModel.llmStatus {
        case .working:
            return "Model loaded and ready for analysis"
        case .partial:
            return "Model downloaded but not loaded"
        case .notConfigured:
            return "No model downloaded. Download to enable AI analysis."
        default:
            return "Checking status..."
        }
    }
    
    private var githubAuthDescription: String {
        switch statusViewModel.githubAuthStatus {
        case .configured:
            return "Authentication configured"
        case .notConfigured:
            return "Set up authentication to sync notes to GitHub"
        default:
            return "Checking status..."
        }
    }
    
    private var githubRepoDescription: String {
        switch statusViewModel.githubRepoStatus {
        case .configured:
            return "Repository fully configured"
        case .partial:
            return "Repository set but authentication missing"
        case .notConfigured:
            return "Configure repository to enable GitHub sync"
        default:
            return "Checking status..."
        }
    }
    
    private var networkStatusDescription: String {
        switch statusViewModel.networkStatus {
        case .working:
            return "Connected and ready to sync"
        case .error:
            return "No internet connection. Notes saved locally."
        default:
            return "Checking connection..."
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var availableModels = ["LFM2-350M", "LFM2-700M", "LFM2-1.2B"]
    @Published var modelStatus: String?
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var needsDownload = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let modelDownloader = ModelDownloader.shared
    private let llmManager = LLMManager.shared
    
    func loadModelStatus() async {
        let currentModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "LFM2-1.2B"
        let isDownloaded = await modelDownloader.isModelDownloaded(currentModel)
        
        if isDownloaded {
            if llmManager.isModelLoaded && llmManager.currentModel == currentModel {
                modelStatus = "✓ Loaded and Ready"
                needsDownload = false
            } else {
                modelStatus = "✓ Downloaded (Not Loaded)"
                needsDownload = false
            }
        } else {
            modelStatus = "✗ Not Downloaded"
            needsDownload = true
        }
    }
    
    func selectModel(_ model: String) async {
        errorMessage = nil
        
        // Check if model is downloaded
        let isDownloaded = await modelDownloader.isModelDownloaded(model)
        if !isDownloaded {
            modelStatus = "✗ Not Downloaded - Please download first"
            needsDownload = true
            return
        }
        
        await llmManager.loadModel(model)
        await loadModelStatus()
    }
    
    func downloadModel(_ model: String) async {
        isDownloading = true
        downloadProgress = 0.0
        errorMessage = nil
        showError = false
        
        defer { isDownloading = false }
        
        do {
            try await modelDownloader.download(model: model) { progress in
                Task { @MainActor in
                    self.downloadProgress = progress
                }
            }
            
            await loadModelStatus()
            
            // Auto-load after successful download
            let isDownloaded = await modelDownloader.isModelDownloaded(model)
            if isDownloaded {
                await llmManager.loadModel(model)
                await loadModelStatus()
                
                // Show success feedback
                #if os(iOS)
                HapticFeedback.success()
                #endif
            }
        } catch {
            let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = "Download failed: \(errorDescription)"
            showError = true
            downloadProgress = 0.0
            
            #if os(iOS)
            HapticFeedback.error()
            #endif
            
            await loadModelStatus()
        }
    }
}

struct ThemeSettingsView: View {
    @AppStorage("appearance") private var appearance = 0
    @Environment(\.colorScheme) private var systemColorScheme
    
    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("Light").tag(0)
                Text("Dark").tag(1)
                Text("System").tag(2)
            }
        }
    }
}

struct GitHubAuthView: View {
    private let authManager = GitHubAuth.shared
    @State private var authMethod: AuthMethod = .pat
    
    var body: some View {
        Form {
            Picker("Authentication Method", selection: $authMethod) {
                Text("Personal Access Token").tag(AuthMethod.pat)
                Text("OAuth").tag(AuthMethod.oauth)
                Text("SSH Key").tag(AuthMethod.ssh)
            }
            
            switch authMethod {
            case .pat:
                PATAuthView()
            case .oauth:
                OAuthAuthView()
            case .ssh:
                SSHAuthView()
            }
        }
        .navigationTitle("GitHub Authentication")
    }
}

enum AuthMethod: String, CaseIterable {
    case pat, oauth, ssh
}

struct PATAuthView: View {
    @State private var token = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    private let authManager = GitHubAuth.shared
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter your GitHub Personal Access Token")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $token)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                Text("Create a token at: github.com/settings/tokens")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        if let url = URL(string: "https://github.com/settings/tokens") {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #elseif os(macOS)
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    }
                
                Text("Required scopes: repo (full control of private repositories)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Button {
                guard !token.isEmpty else {
                    errorMessage = "Please enter a token"
                    showError = true
                    return
                }
                
                if authManager.savePAT(token) {
                    showSuccess = true
                    token = "" // Clear the field after saving
                    // Trigger sync when GitHub is configured
                    Task {
                        await RepositoryManager.shared.sync()
                    }
                } else {
                    errorMessage = "Failed to save token. Please try again."
                    showError = true
                }
            } label: {
                HStack {
                    Spacer()
                    Text("Save Token")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
        } header: {
            Text("Personal Access Token")
        } footer: {
            if authManager.hasAuthentication() {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Token saved successfully")
                        .font(.caption)
                }
            }
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") { }
        } message: {
            Text("GitHub authentication saved securely. Pending notes will sync automatically.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Check if token exists when view appears
            if authManager.hasAuthentication() {
                // Token is saved, don't show it
                token = ""
            }
        }
    }
}

struct OAuthAuthView: View {
    var body: some View {
        Section("OAuth") {
            Button("Authorize with GitHub") {
                // OAuth flow
            }
        }
    }
}

struct SSHAuthView: View {
    var body: some View {
        Section("SSH Key") {
            Text("SSH key authentication coming soon")
                .foregroundColor(.secondary)
        }
    }
}

struct SyncControlsView: View {
    @State private var isSyncing = false
    @State private var isPushing = false
    @State private var isPulling = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var successMessage = ""
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                #if os(iOS)
                HapticFeedback.selection()
                #endif
                isSyncing = true
                Task {
                    do {
                        await RepositoryManager.shared.sync()
                        await MainActor.run {
                            isSyncing = false
                            successMessage = "Sync completed successfully!"
                            showSuccessAlert = true
                            #if os(iOS)
                            HapticFeedback.success()
                            #endif
                        }
                    } catch {
                        await MainActor.run {
                            isSyncing = false
                            errorMessage = "Sync failed: \(error.localizedDescription)"
                            showErrorAlert = true
                            #if os(iOS)
                            HapticFeedback.error()
                            #endif
                        }
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.headline)
                    }
                    Text(isSyncing ? "Syncing..." : "Sync Now (Push & Pull)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isSyncing || isPushing || isPulling)
            
            HStack(spacing: 12) {
                Button(action: {
                    #if os(iOS)
                    HapticFeedback.selection()
                    #endif
                    isPushing = true
                    Task {
                        do {
                            try await RepositoryManager.shared.push()
                            await MainActor.run {
                                isPushing = false
                                successMessage = "Push completed! Notes uploaded to GitHub."
                                showSuccessAlert = true
                                #if os(iOS)
                                HapticFeedback.success()
                                #endif
                            }
                        } catch {
                            await MainActor.run {
                                isPushing = false
                                errorMessage = "Push failed: \(error.localizedDescription)"
                                showErrorAlert = true
                                #if os(iOS)
                                HapticFeedback.error()
                                #endif
                            }
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        if isPushing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.subheadline)
                        }
                        Text(isPushing ? "Pushing..." : "Push")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.green.opacity(0.25), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(isSyncing || isPushing || isPulling)
                
                Button(action: {
                    #if os(iOS)
                    HapticFeedback.selection()
                    #endif
                    isPulling = true
                    Task {
                        do {
                            try await RepositoryManager.shared.pull()
                            await MainActor.run {
                                isPulling = false
                                successMessage = "Pull completed! Latest notes downloaded from GitHub."
                                showSuccessAlert = true
                                #if os(iOS)
                                HapticFeedback.success()
                                #endif
                            }
                        } catch {
                            await MainActor.run {
                                isPulling = false
                                errorMessage = "Pull failed: \(error.localizedDescription)"
                                showErrorAlert = true
                                #if os(iOS)
                                HapticFeedback.error()
                                #endif
                            }
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        if isPulling {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.subheadline)
                        }
                        Text(isPulling ? "Pulling..." : "Pull")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.orange.opacity(0.25), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(isSyncing || isPushing || isPulling)
            }
        }
        .padding(.vertical, 4)
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text(successMessage)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct GitHubRepositoryView: View {
    @AppStorage("githubOwner") private var owner = ""
    @AppStorage("githubRepo") private var repo = ""
    @AppStorage("githubBranch") private var branch = "main"
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isTesting = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your GitHub username or organization name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("username", text: $owner)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: owner) { _, newValue in
                            // Auto-parse if full GitHub URL is pasted
                            parseGitHubURL(newValue)
                        }
                }
            } header: {
                Text("Owner/Username")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The repository name (create it on GitHub if it doesn't exist)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("my-notes-repo", text: $repo)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: repo) { _, newValue in
                            // Auto-parse if full GitHub URL is pasted in repo field
                            if newValue.contains("github.com") {
                                parseGitHubURL(newValue)
                            }
                        }
                }
            } header: {
                Text("Repository Name")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Branch name (usually 'main' or 'master')")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("main", text: $branch)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            } header: {
                Text("Branch")
            }
            
            Section {
                Button {
                    guard !owner.isEmpty, !repo.isEmpty else {
                        errorMessage = "Please fill in both Owner and Repository name"
                        showError = true
                        return
                    }
                    
                    guard !branch.isEmpty else {
                        errorMessage = "Please specify a branch name"
                        showError = true
                        return
                    }
                    
                    // Check for malformed URLs in repo field
                    if repo.contains("github.com") || repo.contains("http") {
                        errorMessage = "Repository name contains a URL. Please enter just the repository name (e.g., 'LibrarianAPP')"
                        showError = true
                        return
                    }
                    
                    isTesting = true
                    Task {
                        await testConnection()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isTesting {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Testing...")
                        } else {
                            Image(systemName: "checkmark.circle")
                            Text("Test Connection")
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTesting || owner.isEmpty || repo.isEmpty)
            } footer: {
                if !owner.isEmpty && !repo.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Notes will be saved to: \(owner)/\(repo)/notes/")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Repository")
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") { }
        } message: {
            Text("Repository settings saved successfully. Notes will sync to \(owner)/\(repo) on branch '\(branch)'.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func parseGitHubURL(_ input: String) {
        // Check if it's a full GitHub URL
        if input.contains("github.com") {
            // Examples: https://github.com/piotrlaczkowski/LibrarianAPP or just github.com/piotrlaczkowski/LibrarianAPP
            let cleaned = input.replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "git@github.com:", with: "")
                .replacingOccurrences(of: ".git", with: "")
            
            let parts = cleaned.components(separatedBy: "/").filter { !$0.isEmpty }
            
            if parts.count >= 2 {
                // Extract owner and repo from URL
                let extractedOwner = parts[parts.count - 2]
                let extractedRepo = parts[parts.count - 1]
                
                // Only update if we got valid values
                if !extractedOwner.isEmpty && !extractedRepo.isEmpty {
                    // Update owner and repo with parsed values
                    if owner != extractedOwner {
                        owner = extractedOwner
                    }
                    if repo != extractedRepo {
                        repo = extractedRepo
                    }
                }
            }
        }
    }
    
    private func testConnection() async {
        // Verify authentication is set up
        guard GitHubAuth.shared.hasAuthentication() else {
            await MainActor.run {
                errorMessage = "Please configure GitHub authentication first"
                showError = true
                isTesting = false
            }
            return
        }
        
        // Test by trying to list files (this will fail gracefully if repo doesn't exist)
        do {
            // First, try to initialize the repository if it's empty
            do {
                try await GitHubClient.shared.initializeEmptyRepository(
                    owner: owner,
                    repo: repo,
                    branch: branch
                )
            } catch {
                // Repository might already be initialized, that's fine
                // Continue with the test
            }
            
            // Try to access the repository
            let _ = try await GitHubClient.shared.listFiles(
                path: "",
                owner: owner,
                repo: repo,
                branch: branch
            )
            
            await MainActor.run {
                showSuccess = true
                isTesting = false
                // Save settings (already saved via @AppStorage, but trigger sync)
                UserDefaults.standard.synchronize()
            }
            
            // Trigger sync if configured
            Task {
                await RepositoryManager.shared.sync()
            }
        } catch {
            await MainActor.run {
                if let githubError = error as? GitHubError {
                    switch githubError {
                    case .authenticationError:
                        errorMessage = "Authentication failed. Please check your token."
                    case .apiError(let message):
                        if message.contains("404") || message.contains("Not Found") {
                            errorMessage = "Repository not found. Make sure '\(owner)/\(repo)' exists, or create it on GitHub first."
                        } else {
                            errorMessage = "Connection failed: \(message)"
                        }
                    case .decodingError:
                        errorMessage = "Invalid response from GitHub. Please try again."
                    }
                } else {
                    errorMessage = "Connection failed: \(error.localizedDescription)"
                }
                showError = true
                isTesting = false
            }
        }
    }
}

