import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var summary: String
    var content: String
    var url: URL?
    var tags: [String]
    var category: String?
    var dateCreated: Date
    var dateModified: Date
    var syncStatus: SyncStatus
    
    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        content: String,
        url: URL? = nil,
        tags: [String] = [],
        category: String? = nil,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.content = content
        self.url = url
        self.tags = tags
        self.category = category
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.syncStatus = syncStatus
    }
}

enum SyncStatus: String, Codable {
    case synced
    case pending
    case conflict
    case error
}

struct NoteAnalysis: Codable {
    let title: String
    let summary: String
    let tags: [String]
    let category: String?
    let whatIsIt: String?  // What is this content
    let whyAdvantageous: String?  // Why is it advantageous/useful
}

