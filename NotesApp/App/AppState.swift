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
    private let sharedDefaults = UserDefaults(suiteName: "group.com.piotrlaczkowski.NotesApp")
    
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
        
        // Load any pending notes on launch
        Task {
            await processPendingNote()
        }
        
        // Initial sync attempt
        Task {
            await performAutoSync()
        }
        
        // Observe appearance changes
        observeAppearanceChanges()
    }
    
    private func observeAppearanceChanges() {
        // Initial theme application
        applyTheme()
        
        // Watch for changes to appearance setting
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)
    }
    
    private func applyTheme() {
        let appearance = UserDefaults.standard.integer(forKey: "appearance")
        
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
    
    func processPendingNote() async {
        guard let defaults = sharedDefaults else {
            // App Group not configured - silently fail
            return
        }
        
        // Check for pending URL first (from Share Extension)
        await MainActor.run {
            if let pendingURLString = defaults.string(forKey: "pendingURLToAnalyze"), 
               !pendingURLString.isEmpty,
               let url = URL(string: pendingURLString) {
                // Clear the pending URL immediately
                defaults.removeObject(forKey: "pendingURLToAnalyze")
                defaults.synchronize()
                
                // Process URL using the full LLM analysis system
                Task { @MainActor in
                    await processURLFromShareExtension(url: url)
                }
                return
            }
        }
        
        // Fallback: Check for pending note (legacy support)
        await MainActor.run {
            guard let noteData = defaults.data(forKey: "pendingNote") else {
                return
            }
            
            guard let note = try? JSONDecoder().decode(Note.self, from: noteData) else {
                // Invalid data - clear it
                defaults.removeObject(forKey: "pendingNote")
                return
            }
            
            // Clear the pending note immediately
            defaults.removeObject(forKey: "pendingNote")
            
            // Show review view
            self.pendingNoteToReview = note
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
        let autoSyncEnabled = UserDefaults.standard.bool(forKey: "autoSyncEnabled")
        guard autoSyncEnabled else { return }
        
        let interval = UserDefaults.standard.integer(forKey: "syncInterval")
        let syncIntervalSeconds = TimeInterval(interval * 60)
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performAutoSync()
            }
        }
    }
    
    func performAutoSync() async {
        guard isOnline else { return }
        
        // Check if GitHub is configured before syncing
        let owner = UserDefaults.standard.string(forKey: "githubOwner") ?? ""
        let repo = UserDefaults.standard.string(forKey: "githubRepo") ?? ""
        guard !owner.isEmpty && !repo.isEmpty && GitHubAuth.shared.hasAuthentication() else {
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

