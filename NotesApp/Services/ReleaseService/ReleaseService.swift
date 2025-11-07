import Foundation

@MainActor
class ReleaseService: ObservableObject {
    static let shared = ReleaseService()
    
    @Published var releases: [Release] = []
    @Published var lastReleaseDate: Date? = nil
    @Published var isLoading = false
    
    private let releaseRepository = ReleaseRepository.shared
    private let noteRepository = NoteRepository.shared
    
    private init() {
        Task {
            await loadReleases()
        }
    }
    
    /// Load all releases from local storage
    func loadReleases() async {
        isLoading = true
        defer { isLoading = false }
        
        let loadedReleases = await releaseRepository.fetchAll()
        releases = loadedReleases.sorted { $0.date > $1.date }
        
        // Update last release date
        if let lastApproved = releases.first(where: { $0.isApproved }) {
            lastReleaseDate = lastApproved.date
        }
    }
    
    /// Get notes created since the last approved release
    func getNotesForAutoSuggestion() async -> [Note] {
        guard let lastReleaseDate = lastReleaseDate else {
            // If no releases yet, return all notes
            return await noteRepository.fetchAll()
        }
        
        let notes = await noteRepository.fetchAll()
        return notes.filter { $0.dateCreated > lastReleaseDate }
    }
    
    /// Get notes created within a specific date range
    func getNotesByDateRange(from startDate: Date, to endDate: Date) async -> [Note] {
        let notes = await noteRepository.fetchAll()
        return notes.filter { note in
            note.dateCreated >= startDate && note.dateCreated <= endDate
        }
    }
    
    /// Create a new release (draft)
    func createRelease(
        title: String,
        noteIds: [UUID],
        linkedInDraft: String
    ) async {
        let release = Release(
            date: Date(),
            title: title,
            noteIds: noteIds,
            linkedInDraft: linkedInDraft,
            isApproved: false
        )
        
        releases.insert(release, at: 0)
        await releaseRepository.save(release)
    }
    
    /// Update a release draft
    func updateRelease(id: UUID, linkedInDraft: String, title: String) async {
        guard let index = releases.firstIndex(where: { $0.id == id }) else { return }
        
        var updatedRelease = releases[index]
        updatedRelease.linkedInDraft = linkedInDraft
        updatedRelease.title = title
        
        releases[index] = updatedRelease
        await releaseRepository.save(updatedRelease)
    }
    
    /// Approve a release and save it
    func approveRelease(id: UUID, with approvedText: String? = nil) async {
        guard let index = releases.firstIndex(where: { $0.id == id }) else { return }
        
        var updatedRelease = releases[index]
        updatedRelease.approve(with: approvedText)
        
        releases[index] = updatedRelease
        await releaseRepository.save(updatedRelease)
        
        // Update last release date
        lastReleaseDate = updatedRelease.date
    }
    
    /// Delete a release
    func deleteRelease(id: UUID) async {
        releases.removeAll { $0.id == id }
        await releaseRepository.delete(id: id)
    }
    
    /// Get a specific release by ID
    func getRelease(id: UUID) -> Release? {
        releases.first { $0.id == id }
    }
    
    /// Get all approved releases
    func getApprovedReleases() -> [Release] {
        releases.filter { $0.isApproved }
    }
}

