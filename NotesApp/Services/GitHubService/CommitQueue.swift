import Foundation

actor CommitQueue {
    static let shared = CommitQueue()
    
    private var pendingCommits: [PendingCommit] = []
    private let noteRepository = NoteRepository.shared
    
    private init() {}
    
    func enqueue(note: Note) {
        let commit = PendingCommit(
            id: UUID(),
            noteId: note.id,
            note: note,
            dateCreated: Date(),
            retryCount: 0
        )
        pendingCommits.append(commit)
        saveQueue()
    }
    
    func processQueue() async {
        // Check if GitHub is configured before processing
        let owner = await MainActor.run { UserDefaults.standard.string(forKey: "githubOwner") ?? "" }
        let repo = await MainActor.run { UserDefaults.standard.string(forKey: "githubRepo") ?? "" }
        let hasAuth = await MainActor.run { GitHubAuth.shared.hasAuthentication() }
        
        guard !owner.isEmpty && !repo.isEmpty && hasAuth else {
            // Not configured - keep items in queue for later
            return
        }
        
        let isConnected = await MainActor.run { NetworkMonitor.shared.isConnected }
        guard isConnected else {
            return
        }
        
        // Process commits one at a time to ensure each gets its own commit
        // This prevents batching multiple notes into a single commit
        let commits = pendingCommits
        pendingCommits.removeAll()
        
        // Process sequentially to ensure each note gets its own dedicated commit
        for commit in commits {
            do {
                // Each note gets its own commit via separate API calls
                try await RepositoryManager.shared.commit(note: commit.note)
                // Small delay between commits to ensure proper ordering
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            } catch {
                // Retry logic
                if commit.retryCount < 3 {
                    let updated = commit.withRetryCount(commit.retryCount + 1)
                    pendingCommits.append(updated)
                } else {
                    // Mark note with error status after max retries
                    var note = commit.note
                    note.syncStatus = .error
                    await noteRepository.update(note)
                }
            }
        }
        
        saveQueue()
    }
    
    private func saveQueue() {
        // TODO: Persist queue to disk
    }
    
    func loadQueue() {
        // TODO: Load queue from disk
    }
    
    var count: Int {
        pendingCommits.count
    }
}

struct PendingCommit: Codable, Identifiable {
    let id: UUID
    let noteId: UUID
    let note: Note
    let dateCreated: Date
    let retryCount: Int
    
    func withRetryCount(_ newCount: Int) -> PendingCommit {
        PendingCommit(
            id: id,
            noteId: noteId,
            note: note,
            dateCreated: dateCreated,
            retryCount: newCount
        )
    }
}

