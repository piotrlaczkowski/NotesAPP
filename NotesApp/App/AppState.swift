import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var colorScheme: ColorScheme? = nil
    @Published var isOnline: Bool = true
    @Published var syncInProgress: Bool = false
    @Published var pendingNoteToReview: Note?
    @Published var pendingNoteAnalysis: NoteAnalysis?
    
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    private var isProcessingPendingNote = false
    private var lastPendingCheckTime: Date = Date.distantPast
    private var cachedPendingURL: String? = nil
    
    // Never access sharedDefaults synchronously - always use getSharedDefaults() async method
    
    init() {
        // Observe network status
        NetworkMonitor.shared.startMonitoring()
        
        NetworkMonitor.shared.$isConnected
            .assign(to: &$isOnline)
        
        // Trigger sync when connection is restored
        NetworkMonitor.shared.$isConnected
            .dropFirst() // Skip initial value
            .sink { [weak self] isConnected in
                if isConnected {
                    Task { @MainActor [weak self] in
                        await self?.performAutoSync()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Set up auto-sync if enabled
        setupAutoSync()
        
        // Load any pending notes on launch - delay slightly to avoid blocking app startup
        Task {
            // Small delay to let UI render first
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await processPendingNote()
        }
        
        // Initial sync attempt - delay to avoid blocking
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await performAutoSync()
        }
        
        // Observe appearance changes
        observeAppearanceChanges()
    }
    
    private func observeAppearanceChanges() {
        // Initial theme application (async, non-blocking)
        Task {
            await applyTheme()
        }
        
        // Watch for changes to appearance setting - heavily debounced to avoid excessive calls
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.applyTheme()
                }
            }
            .store(in: &cancellables)
    }
    
    private func applyTheme() async {
        // Read UserDefaults asynchronously with timeout to avoid blocking
        let appearance = await Task.detached(priority: .utility) {
            UserDefaults.standard.integer(forKey: "appearance")
        }.value
        
        await MainActor.run {
            self.updateColorScheme(from: appearance)
        }
    }
    
    private func updateColorScheme(from appearance: Int) {
        switch appearance {
        case 0: // Light
            colorScheme = .light
        case 1: // Dark
            colorScheme = .dark
        case 2: // System
            colorScheme = nil
        default:
            colorScheme = nil
        }
    }
    
    // Helper to get shared UserDefaults asynchronously with timeout and error handling
    // This prevents CFPrefs blocking errors by ensuring all access is async
    // Small delay helps let system initialize cfprefsd connection properly
    private func getSharedDefaults() async -> UserDefaults? {
        // Small delay to let system initialize cfprefsd connection
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        return await withTimeout(seconds: 0.5) {
            await Task.detached(priority: .utility) {
                // Initialize UserDefaults in detached task to avoid blocking
                return UserDefaults(suiteName: "group.com.piotrlaczkowski.NotesApp")
            }.value
        } ?? nil
    }
    
    func processPendingNote() async {
        // Throttle checks - don't check more than once per 2 seconds
        let now = Date()
        guard now.timeIntervalSince(lastPendingCheckTime) > 2.0 else {
            return
        }
        lastPendingCheckTime = now
        
        // Prevent concurrent calls - if already processing, skip
        guard !isProcessingPendingNote else {
            return
        }
        
        // Get UserDefaults reference asynchronously with timeout to avoid blocking
        guard let defaults = await getSharedDefaults() else {
            // UserDefaults not available - return silently to avoid errors
            return
        }
        
        isProcessingPendingNote = true
        defer { isProcessingPendingNote = false }
        
        // Perform UserDefaults access with timeout to prevent indefinite blocking
        // Small delay to help system process cfprefsd connection
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        let pendingURLString: String? = await withTimeout(seconds: 1.0) {
            await Task.detached(priority: .userInitiated) {
                // Access UserDefaults in detached task - all methods are non-throwing
                return defaults.string(forKey: "pendingURLToAnalyze")
            }.value
        } ?? nil
        
        if let pendingURLString = pendingURLString, 
           !pendingURLString.isEmpty,
           pendingURLString != cachedPendingURL, // Don't process same URL twice
           let url = URL(string: pendingURLString) {
            // Cache the URL to avoid reprocessing
            cachedPendingURL = pendingURLString
            
            // Clear the pending URL immediately (off main thread, with timeout)
            await withTimeout(seconds: 0.5) {
                await Task.detached(priority: .utility) {
                    // Remove object - non-throwing operation
                    defaults.removeObject(forKey: "pendingURLToAnalyze")
                }.value
            }
            
            // Process URL using the full LLM analysis system
            // Use Task.detached to avoid blocking main thread for network operations
            Task.detached { [weak self] in
                await self?.processURLFromShareExtension(url: url)
            }
            return
        }
        
        // Fallback: Check for pending note (legacy support) - off main thread with timeout
        let noteData: Data? = await withTimeout(seconds: 1.0) {
            await Task.detached(priority: .userInitiated) {
                // Access UserDefaults in detached task - non-throwing operation
                return defaults.data(forKey: "pendingNote")
            }.value
        } ?? nil
        
        guard let noteData = noteData else {
            return
        }
        
        guard let note = try? JSONDecoder().decode(Note.self, from: noteData) else {
            // Invalid data - clear it (off main thread, with timeout)
            await withTimeout(seconds: 0.5) {
                await Task.detached(priority: .utility) {
                    defaults.removeObject(forKey: "pendingNote")
                }.value
            }
            return
        }
        
        // Clear the pending note immediately (off main thread, with timeout)
        await withTimeout(seconds: 0.5) {
            await Task.detached(priority: .utility) {
                defaults.removeObject(forKey: "pendingNote")
            }.value
        }
        
        // Show review view (back on main actor)
        await MainActor.run {
            self.pendingNoteToReview = note
        }
    }
    
    // Helper to wrap async operations with timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask {
                await operation()
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            
            guard let result = try? await group.next(), let value = result else {
                group.cancelAll()
                return nil
            }
            
            group.cancelAll()
            return value
        }
    }
    
    func processURLFromShareExtension(url: URL) async {
        // Use the same robust LLM analysis system as regular URL addition
        do {
            let contentExtractor = URLContentExtractor.shared
            // Use enhanced extraction with metadata
            let result = try await contentExtractor.extractContentWithMetadata(from: url)
            let content = result.content
            let metadata = result.metadata
            
            // Try to analyze with LLM using metadata
            let llmManager = LLMManager.shared
            let analysis: NoteAnalysis
            
            if llmManager.isModelLoaded {
                do {
                    analysis = try await llmManager.analyzeContent(content, metadata: metadata)
                } catch {
                    // Fallback if LLM fails
                    analysis = createFallbackAnalysis(from: content, url: url, metadata: metadata)
                }
            } else {
                analysis = createFallbackAnalysis(from: content, url: url, metadata: metadata)
            }
            
            // Create note with full analysis
            let note = Note(
                title: analysis.title,
                summary: analysis.summary,
                content: content,
                url: url,
                tags: analysis.tags,
                category: analysis.category,
                syncStatus: .pending
            )
            
            // Show review view with full analysis
            // We may be off MainActor if called from Task.detached, so use await MainActor.run
            await MainActor.run {
                self.pendingNoteToReview = note
                self.pendingNoteAnalysis = analysis
            }
        } catch {
            // On error, create a basic note
            let note = Note(
                title: url.host ?? "Untitled",
                summary: "Content from \(url.absoluteString)",
                content: "",
                url: url,
                tags: [],
                category: nil,
                syncStatus: .pending
            )
            // We may be off MainActor if called from Task.detached, so use await MainActor.run
            await MainActor.run {
                self.pendingNoteToReview = note
            }
        }
    }
    
    private func createFallbackAnalysis(from content: String, url: URL, metadata: ContentMetadata?) -> NoteAnalysis {
        // Use metadata if available for better fallback
        let title: String
        if let ogTitle = metadata?.openGraphTitle, !ogTitle.isEmpty {
            title = String(ogTitle.prefix(100))
        } else if let pageTitle = metadata?.pageTitle, !pageTitle.isEmpty {
            title = String(pageTitle.prefix(100))
        } else {
            title = url.host ?? "Untitled"
        }
        
        let summary: String
        if let ogDesc = metadata?.openGraphDescription, !ogDesc.isEmpty {
            summary = String(ogDesc.prefix(280))
        } else if let metaDesc = metadata?.metaDescription, !metaDesc.isEmpty {
            summary = String(metaDesc.prefix(280))
        } else {
            summary = String(content.prefix(280))
        }
        
        var tags: [String] = []
        if let metadata = metadata, !metadata.keywords.isEmpty {
            tags.append(contentsOf: metadata.keywords)
        }
        
        let category: String?
        if let ogType = metadata?.openGraphType {
            switch ogType.lowercased() {
            case "article", "article:article":
                category = "Article"
            default:
                category = nil
            }
        } else if url.host?.contains("arxiv") == true {
            category = "Research Paper"
        } else if url.host?.contains("github") == true {
            category = "Code Repository"
        } else {
            category = nil
        }
        
        return NoteAnalysis(
            title: title,
            summary: summary,
            tags: tags,
            category: category,
            whatIsIt: metadata?.openGraphDescription,
            whyAdvantageous: "Valuable information for future reference"
        )
    }
    
    private func setupAutoSync() {
        // Read UserDefaults asynchronously to avoid blocking
        Task.detached(priority: .utility) { [weak self] in
            let autoSyncEnabled = UserDefaults.standard.bool(forKey: "autoSyncEnabled")
            guard autoSyncEnabled else { return }
            
            let interval = UserDefaults.standard.integer(forKey: "syncInterval")
            let syncIntervalSeconds = TimeInterval(interval * 60)
            
            await MainActor.run {
                guard let self = self else { return }
                self.syncTimer = Timer.scheduledTimer(withTimeInterval: syncIntervalSeconds, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        await self?.performAutoSync()
                    }
                }
            }
        }
    }
    
    func performAutoSync() async {
        guard isOnline else { return }
        
        // Check if GitHub is configured before syncing (async to avoid blocking)
        let config = await Task.detached(priority: .utility) {
            let owner = UserDefaults.standard.string(forKey: "githubOwner") ?? ""
            let repo = UserDefaults.standard.string(forKey: "githubRepo") ?? ""
            return (owner: owner, repo: repo)
        }.value
        
        guard !config.owner.isEmpty && !config.repo.isEmpty && GitHubAuth.shared.hasAuthentication() else {
            // Not configured - skip sync silently
            return
        }
        
        syncInProgress = true
        defer { syncInProgress = false }
        
        // Perform sync - RepositoryManager handles all configuration checks
        await RepositoryManager.shared.sync()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}

