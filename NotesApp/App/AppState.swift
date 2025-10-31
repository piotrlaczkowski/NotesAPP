import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var colorScheme: ColorScheme? = nil
    @Published var isOnline: Bool = true
    @Published var syncInProgress: Bool = false
    @Published var pendingNoteToReview: Note?
    
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
    }
    
    func processPendingNote() async {
        guard let defaults = sharedDefaults else {
            // App Group not configured - silently fail
            return
        }
        
        // Access UserDefaults on main actor to avoid threading issues
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

