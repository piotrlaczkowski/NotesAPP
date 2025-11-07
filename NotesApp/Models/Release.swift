import Foundation

struct Release: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    var title: String
    let noteIds: [UUID]
    var linkedInDraft: String
    var approvedDraft: String?
    var isApproved: Bool
    let dateCreated: Date
    var dateApproved: Date?
    
    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        noteIds: [UUID] = [],
        linkedInDraft: String = "",
        approvedDraft: String? = nil,
        isApproved: Bool = false,
        dateCreated: Date = Date(),
        dateApproved: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.noteIds = noteIds
        self.linkedInDraft = linkedInDraft
        self.approvedDraft = approvedDraft
        self.isApproved = isApproved
        self.dateCreated = dateCreated
        self.dateApproved = dateApproved
    }
    
    mutating func approve(with approvedText: String? = nil) {
        self.isApproved = true
        self.dateApproved = Date()
        if let approvedText = approvedText {
            self.approvedDraft = approvedText
        } else {
            self.approvedDraft = linkedInDraft
        }
    }
}

