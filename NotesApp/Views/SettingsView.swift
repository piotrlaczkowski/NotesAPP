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
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.systemBackground,
                        Color.systemBackground.opacity(0.95)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                Form {
                    Section {
                        VStack(spacing: 12) {
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
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 14, weight: .semibold))
                                    
                                    Text("\(statusViewModel.pendingSyncCount) notes pending sync")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    } header: {
                        Text("Status Overview")
                            .font(.headline)
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
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Hugging Face Token (Optional)
                        HuggingFaceTokenView()
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
        let currentModel = await Task.detached(priority: .utility) {
            UserDefaults.standard.string(forKey: "selectedModel") ?? "LFM2-1.2B"
        }.value
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
        // Prevent concurrent downloads
        guard !isDownloading else {
            print("SettingsViewModel: Download already in progress")
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        errorMessage = nil
        showError = false
        
        defer { 
            isDownloading = false
        }
        
        do {
            try await modelDownloader.download(model: model) { progress in
                // Progress callback is already on MainActor from ModelDownloader
                self.downloadProgress = progress
            }
            
            // Verify download succeeded
            let isDownloaded = await modelDownloader.isModelDownloaded(model)
            print("SettingsViewModel: After download, isModelDownloaded=\(isDownloaded)")
            
            if isDownloaded {
                // Update UI status first
                await loadModelStatus()
                
                // Auto-load after successful download
                await llmManager.loadModel(model)
                
                // Refresh status again after loading
                await loadModelStatus()
                
                // Show success feedback
                #if os(iOS)
                HapticFeedback.success()
                #endif
            } else {
                // Model not detected - log details for debugging
                print("SettingsViewModel: ⚠️ Model download completed but file not detected")
                if let modelPath = await modelDownloader.getModelPath(for: model) {
                    print("SettingsViewModel: But getModelPath returned: \(modelPath.path)")
                } else {
                    print("SettingsViewModel: getModelPath returned nil")
                }
                // Still update status to show download completed
                await loadModelStatus()
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
    @AppStorage("appearance") private var appearance = 2
    @Environment(\.colorScheme) private var systemColorScheme
    
    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    // Light Theme Option
                    themeOption(
                        icon: "sun.max.fill",
                        title: "Light",
                        subtitle: "Bright and clear",
                        tag: 0,
                        colors: [Color.white, Color(hex: "F5F5F7")]
                    )
                    
                    // Dark Theme Option
                    themeOption(
                        icon: "moon.stars.fill",
                        title: "Dark",
                        subtitle: "Easy on the eyes",
                        tag: 1,
                        colors: [Color.black, Color(hex: "1C1C1E")]
                    )
                    
                    // System Theme Option
                    themeOption(
                        icon: "gear",
                        title: "System",
                        subtitle: "Follow device settings",
                        tag: 2,
                        colors: [Color(hex: "E8E8EA"), Color(hex: "2A2A2A")]
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("Theme")
            } footer: {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Changes apply immediately to the entire app")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            // Preview section
            Section("Preview") {
                previewCard()
            }
        }
        .navigationTitle("Theme")
    }
    
    private func themeOption(icon: String, title: String, subtitle: String, tag: Int, colors: [Color]) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                appearance = tag
                #if os(iOS)
                HapticFeedback.selection()
                #endif
            }
        }) {
            HStack(spacing: 12) {
                // Icon with gradient background
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [colors[0].opacity(0.7), colors[1].opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(10)
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: appearance == tag ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(appearance == tag ? .blue : .gray.opacity(0.3))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.systemBackground)
                    .stroke(
                        appearance == tag ?
                        LinearGradient(colors: [.blue, .blue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
            )
        }
    }
    
    private func previewCard() -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sample Card")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("This is how your notes will look")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "note.text")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.systemBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            Text(getThemeDescription())
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 8)
    }
    
    private func getThemeDescription() -> String {
        switch appearance {
        case 0:
            return "Light mode: Bright, clean interface ideal for daytime use"
        case 1:
            return "Dark mode: Comfortable for extended use, reduces eye strain"
        case 2:
            return "System mode: Automatically follows your device settings"
        default:
            return "Select a theme to get started"
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
            VStack(alignment: .leading, spacing: 16) {
                // Header with icon
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                    
                    Text("Enter your GitHub Personal Access Token")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    SecureField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $token)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .padding(10)
                        .background(Color.systemGray6)
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/settings/tokens") {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #elseif os(macOS)
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                            Text("Create token at GitHub settings")
                        }
                        .foregroundColor(.blue)
                        .font(.caption)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                            Text("repo")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.semibold)
                            Text("(full control of private repositories)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
                
                Button {
                    guard !token.isEmpty else {
                        errorMessage = "Please enter a token"
                        showError = true
                        return
                    }
                    
                    if authManager.savePAT(token) {
                        showSuccess = true
                        token = ""
                        Task {
                            await RepositoryManager.shared.sync()
                        }
                    } else {
                        errorMessage = "Failed to save token. Please try again."
                        showError = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "lock.circle.fill")
                        Text("Save Token Securely")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Personal Access Token")
        } footer: {
            if authManager.hasAuthentication() {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Token saved successfully and stored securely in Keychain")
                        .font(.caption)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Your token will be encrypted and stored securely on your device")
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
            if authManager.hasAuthentication() {
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
                    await RepositoryManager.shared.sync()
                    await MainActor.run {
                        isSyncing = false
                        successMessage = "Sync completed successfully!"
                        showSuccessAlert = true
                        #if os(iOS)
                        HapticFeedback.success()
                        #endif
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
                VStack(alignment: .leading, spacing: 12) {
                    Label("GitHub username or organization name", systemImage: "person.crop.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("piotrlaczkowski", text: $owner)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .onChange(of: owner) { _, newValue in
                            parseGitHubURL(newValue)
                        }
                        .padding(10)
                        .background(Color.systemGray6)
                        .cornerRadius(8)
                }
            } header: {
                Label("Owner/Username", systemImage: "person.fill")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Repository name (e.g., LibrarianAPP)", systemImage: "folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("LibrarianAPP", text: $repo)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .onChange(of: repo) { _, newValue in
                            if newValue.contains("github.com") {
                                parseGitHubURL(newValue)
                            }
                        }
                        .padding(10)
                        .background(Color.systemGray6)
                        .cornerRadius(8)
                }
            } header: {
                Label("Repository Name", systemImage: "folder.fill")
                    .font(.headline)
            } footer: {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("You can paste a full GitHub URL (e.g., https://github.com/user/repo) and it will auto-fill")
                        .font(.caption)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Branch name (usually 'main' or 'master')", systemImage: "git.branch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("main", text: $branch)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .padding(10)
                        .background(Color.systemGray6)
                        .cornerRadius(8)
                }
            } header: {
                Label("Branch", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.headline)
            }
            
            Section {
                Button(action: {
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
                    
                    if repo.contains("github.com") || repo.contains("http") {
                        errorMessage = "Repository name contains a URL. Please enter just the repository name (e.g., 'LibrarianAPP')"
                        showError = true
                        return
                    }
                    
                    isTesting = true
                    Task {
                        await testConnection()
                    }
                }) {
                    HStack(spacing: 10) {
                        Spacer()
                        if isTesting {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 4)
                            Text("Testing Connection...")
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Test Connection")
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.plain)
                .disabled(isTesting || owner.isEmpty || repo.isEmpty)
            }
            
            if !owner.isEmpty && !repo.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Configuration Preview")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Repository URL:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("github.com/\(owner)/\(repo)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Text("Branch:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(branch)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Text("Storage Path:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(owner)/\(repo)/notes/")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(8)
                        .background(Color.systemGray6)
                        .cornerRadius(6)
                    }
                } header: {
                    Label("Preview", systemImage: "eye")
                        .font(.headline)
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
        if input.contains("github.com") {
            let cleaned = input.replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "git@github.com:", with: "")
                .replacingOccurrences(of: ".git", with: "")
            
            let parts = cleaned.components(separatedBy: "/").filter { !$0.isEmpty }
            
            if parts.count >= 2 {
                let extractedOwner = parts[parts.count - 2]
                let extractedRepo = parts[parts.count - 1]
                
                if !extractedOwner.isEmpty && !extractedRepo.isEmpty {
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
                // Clear config cache so new settings are picked up
                Task {
                    await RepositoryManager.shared.clearConfigCache()
                }
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

struct HuggingFaceTokenView: View {
    @State private var token = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasToken = ModelDownloader.hasHFToken()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "key.horizontal.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                
                Text("Hugging Face Token (Optional)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            if hasToken {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Token is set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Remove") {
                        if KeychainHelper.delete(forKey: "huggingface_token") {
                            hasToken = false
                            token = ""
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    SecureField("hf_xxxxxxxxxxxxxxxxxxxx", text: $token)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .padding(10)
                        .background(Color.systemGray6)
                        .cornerRadius(8)
                    
                    Text("Optional: Set a Hugging Face token for better download reliability and higher rate limits. Get one at huggingface.co/settings/tokens")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Button {
                    guard !token.isEmpty else {
                        errorMessage = "Please enter a token"
                        showError = true
                        return
                    }
                    
                    // Validate token format (should start with hf_)
                    if !token.hasPrefix("hf_") {
                        errorMessage = "Hugging Face tokens should start with 'hf_'. Please check your token."
                        showError = true
                        return
                    }
                    
                    if ModelDownloader.saveHFToken(token) {
                        showSuccess = true
                        hasToken = true
                        token = ""
                    } else {
                        errorMessage = "Failed to save token. Please try again."
                        showError = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "lock.circle.fill")
                        Text("Save Token")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") { }
        } message: {
            Text("Hugging Face token saved securely. This will improve download reliability.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            hasToken = ModelDownloader.hasHFToken()
        }
    }
}

