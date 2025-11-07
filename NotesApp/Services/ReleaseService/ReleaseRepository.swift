import Foundation

actor ReleaseRepository {
    static let shared = ReleaseRepository()
    
    private var releases: [Release] = []
    private let fileManager = FileManager.default
    private let documentsURL: URL
    
    private init() {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        documentsURL = paths[0].appendingPathComponent("Releases", isDirectory: true)
        
        try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        
        // Load releases asynchronously
        Task {
            await self.loadReleases()
        }
    }
    
    private func loadReleases() async {
        let releasesURL = documentsURL.appendingPathComponent("releases.json")
        let loadedReleases = await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: releasesURL.path) else {
                return [Release]()
            }
            
            guard let data = try? Data(contentsOf: releasesURL),
                  let decoded = try? JSONDecoder().decode([Release].self, from: data) else {
                return [Release]()
            }
            return decoded
        }.value
        
        releases = loadedReleases
    }
    
    private func saveReleases() {
        let releasesURL = documentsURL.appendingPathComponent("releases.json")
        let releasesToSave = releases
        
        Task.detached(priority: .utility) { [releasesToSave, releasesURL] in
            guard let data = try? JSONEncoder().encode(releasesToSave) else { return }
            
            do {
                try await Task.detached(priority: .utility) {
                    try data.write(to: releasesURL, options: .atomic)
                }.value
            } catch {
                // Silently fail - will retry on next save
                return
            }
        }
    }
    
    func fetchAll() -> [Release] {
        return releases.sorted { $0.date > $1.date }
    }
    
    func fetch(id: UUID) -> Release? {
        return releases.first { $0.id == id }
    }
    
    func save(_ release: Release) {
        if let index = releases.firstIndex(where: { $0.id == release.id }) {
            releases[index] = release
        } else {
            releases.append(release)
        }
        saveReleases()
    }
    
    func delete(id: UUID) {
        releases.removeAll { $0.id == id }
        saveReleases()
    }
    
    /// Convert releases to markdown format for GitHub
    func releasesToMarkdown() -> String {
        var markdown = "# Releases\n\nA collection of weekly summaries and interesting findings.\n\n"
        
        for release in releases.sorted(by: { $0.date > $1.date }) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: release.date)
            
            markdown += "## \(dateString) - \(release.title)\n\n"
            markdown += "**Status:** \(release.isApproved ? "Approved" : "Draft")\n"
            markdown += "**Notes Included:** \(release.noteIds.count)\n\n"
            
            // Add the approved draft if available, otherwise the LinkedIn draft
            let content = release.approvedDraft ?? release.linkedInDraft
            markdown += content + "\n\n"
            
            markdown += "---\n\n"
        }
        
        return markdown
    }
    
    /// Parse markdown to extract releases
    func parseMarkdownReleases(_ markdown: String) -> [Release] {
        var parsedReleases: [Release] = []
        
        // Split by release sections
        let sections = markdown.components(separatedBy: "---\n\n")
        
        for section in sections {
            let lines = section.components(separatedBy: .newlines)
            guard lines.count > 1 else { continue }
            
            // Parse header line (## YYYY-MM-DD - Title)
            let headerLine = lines[0]
            guard headerLine.hasPrefix("##") else { continue }
            
            let headerContent = String(headerLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            let parts = headerContent.components(separatedBy: " - ")
            
            guard parts.count >= 1 else { continue }
            
            let dateString = parts[0]
            let title = parts.count > 1 ? parts[1] : "Release"
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = dateFormatter.date(from: dateString) ?? Date()
            
            // Parse status (Approved or Draft)
            var isApproved = false
            var contentStart = 1
            
            for (index, line) in lines.enumerated() {
                if line.contains("**Status:**") {
                    isApproved = line.contains("Approved")
                    contentStart = index + 1
                    break
                }
            }
            
            // Extract content
            var content = ""
            for i in contentStart..<lines.count {
                let line = lines[i]
                if !line.trimmingCharacters(in: .whitespaces).isEmpty && 
                   !line.contains("**Notes Included:**") &&
                   !line.contains("**Status:**") {
                    content += line + "\n"
                }
            }
            
            let release = Release(
                date: date,
                title: title,
                noteIds: [],
                linkedInDraft: content.trimmingCharacters(in: .whitespacesAndNewlines),
                approvedDraft: isApproved ? content.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                isApproved: isApproved,
                dateCreated: date,
                dateApproved: isApproved ? date : nil
            )
            
            parsedReleases.append(release)
        }
        
        return parsedReleases
    }
}

