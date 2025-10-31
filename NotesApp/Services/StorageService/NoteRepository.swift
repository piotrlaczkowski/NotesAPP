import Foundation

actor NoteRepository {
    static let shared = NoteRepository()
    
    private var notes: [Note] = []
    private let fileManager = FileManager.default
    private let documentsURL: URL
    
    private init() {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        documentsURL = paths[0].appendingPathComponent("Notes", isDirectory: true)
        
        try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        
        // Load notes - init is nonisolated, so we use Task to access isolated state
        Task { @MainActor in
            await self.loadNotes()
        }
    }
    
    private func loadNotes() async {
        let notesURL = documentsURL.appendingPathComponent("notes.json")
        guard let data = try? Data(contentsOf: notesURL),
              let decoded = try? JSONDecoder().decode([Note].self, from: data) else {
            notes = []
            return
        }
        notes = decoded
    }
    
    private func saveNotes() {
        let notesURL = documentsURL.appendingPathComponent("notes.json")
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: notesURL)
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

