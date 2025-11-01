import Foundation

actor NoteRepository {
    static let shared = NoteRepository()
    
    private var notes: [Note] = []
    private let fileManager = FileManager.default
    private let documentsURL: URL
    
    // Notification name for when notes are updated
    static let notesDidChangeNotification = NSNotification.Name("NotesDidChange")
    
    private init() {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        documentsURL = paths[0].appendingPathComponent("Notes", isDirectory: true)
        
        try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        
        // Load notes asynchronously to avoid blocking initialization
        Task {
            await self.loadNotes()
        }
    }
    
    private func loadNotes() async {
        // Perform file I/O off the actor to avoid blocking
        let notesURL = documentsURL.appendingPathComponent("notes.json")
        let loadedNotes = await Task.detached(priority: .utility) {
            // Use FileHandle for truly async file reading
            guard FileManager.default.fileExists(atPath: notesURL.path) else {
                return [Note]()
            }
            
            // Read file data - still sync but in detached task to avoid blocking main thread
            // For small JSON files, this is acceptable as it's off the main thread
            guard let data = try? Data(contentsOf: notesURL),
                  let decoded = try? JSONDecoder().decode([Note].self, from: data) else {
                return [Note]()
            }
            return decoded
        }.value
        
        // Update actor-isolated state
        notes = loadedNotes
    }
    
    private func saveNotes() {
        // Since we're in an actor, file I/O won't block other actors
        // But we should still do it asynchronously to avoid blocking the caller
        let notesURL = documentsURL.appendingPathComponent("notes.json")
        let notesToSave = notes
        
        Task.detached(priority: .utility) { [notesToSave, notesURL] in
            // Perform file I/O off the actor with proper async handling
            guard let data = try? JSONEncoder().encode(notesToSave) else { return }
            
            // Write asynchronously
            do {
                try await Task.detached(priority: .utility) {
                    try data.write(to: notesURL, options: .atomic)
                }.value
            } catch {
                // Silently fail - will retry on next save
                return
            }
            
            // Post notification on main thread so UI can update
            await MainActor.run {
                NotificationCenter.default.post(name: NoteRepository.notesDidChangeNotification, object: nil)
            }
        }
    }
    
    func fetchAll() -> [Note] {
        return notes.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    func fetch(id: UUID) -> Note? {
        return notes.first { $0.id == id }
    }
    
    func save(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            var updated = note
            updated = Note(
                id: note.id,
                title: note.title,
                summary: note.summary,
                content: note.content,
                url: note.url,
                tags: note.tags,
                category: note.category,
                dateCreated: note.dateCreated,
                dateModified: Date(),
                syncStatus: note.syncStatus
            )
            notes[index] = updated
        } else {
            notes.append(note)
        }
        saveNotes()
    }
    
    func update(_ note: Note) {
        save(note)
    }
    
    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        saveNotes()
    }
    
    func search(query: String) -> [Note] {
        let lowercased = query.lowercased()
        return notes.filter { note in
            note.title.lowercased().contains(lowercased) ||
            note.summary.lowercased().contains(lowercased) ||
            note.content.lowercased().contains(lowercased) ||
            note.tags.joined(separator: " ").lowercased().contains(lowercased)
        }
    }
}

