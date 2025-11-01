import Foundation

actor RepositoryManager {
    static let shared = RepositoryManager()
    
    private let githubClient = GitHubClient.shared
    private let commitQueue = CommitQueue.shared
    private let noteRepository = NoteRepository.shared
    
    // Cache config to avoid repeated UserDefaults access
    private var cachedConfig: (owner: String, repo: String, branch: String)?
    
    private func getConfig() async -> (owner: String, repo: String, branch: String) {
        if let cached = cachedConfig {
            return cached
        }
        let config = await Task.detached(priority: .utility) {
            (
                owner: UserDefaults.standard.string(forKey: "githubOwner") ?? "",
                repo: UserDefaults.standard.string(forKey: "githubRepo") ?? "",
                branch: UserDefaults.standard.string(forKey: "githubBranch") ?? "main"
            )
        }.value
        cachedConfig = config
        return config
    }
    
    private var owner: String {
        // This shouldn't be called directly - use getConfig() instead
        // Keeping for backward compatibility but it should be async
        return cachedConfig?.owner ?? ""
    }
    private var repo: String {
        return cachedConfig?.repo ?? ""
    }
    private var branch: String {
        return cachedConfig?.branch ?? "main"
    }
    
    private init() {}
    
    /// Clear cached config (call when settings change)
    func clearConfigCache() {
        cachedConfig = nil
    }
    
    func commit(note: Note) async throws {
        // Check if GitHub is configured (async to avoid blocking)
        let config = await getConfig()
        guard !config.owner.isEmpty && !config.repo.isEmpty && GitHubAuth.shared.hasAuthentication() else {
            // Not configured - just queue for later
            await commitQueue.enqueue(note: note)
            var updatedNote = note
            updatedNote.syncStatus = .pending
            await noteRepository.update(updatedNote)
            return
        }
        
        let filename = generateFilename(for: note)
        let folderPath = generateFolderPath(for: note)
        let path = "\(folderPath)/\(filename)"
        let content = generateMarkdownContent(for: note)
        let message = generateCommitMessage(for: note)
        
        // Encode content as base64
        guard let contentData = content.data(using: .utf8) else {
            throw RepositoryError.encodingError
        }
        
        let base64Content = contentData.base64EncodedString()
        
        do {
            // First, ensure the repository is initialized (in case it's empty)
            do {
                try await githubClient.initializeEmptyRepository(
                    owner: config.owner,
                    repo: config.repo,
                    branch: config.branch
                )
            } catch {
                // Repository might already be initialized, that's fine
                // Continue with the commit
            }
            
            try await githubClient.createOrUpdateFile(
                path: path,
                content: base64Content,
                message: message,
                owner: config.owner,
                repo: config.repo,
                branch: config.branch
            )
            
            // Update note sync status
            var updatedNote = note
            updatedNote.syncStatus = .synced
            await noteRepository.update(updatedNote)
        } catch {
            // Queue for retry - don't throw, just queue it
            await commitQueue.enqueue(note: note)
            var updatedNote = note
            updatedNote.syncStatus = .pending
            await noteRepository.update(updatedNote)
            // Don't throw - we've queued it for background sync
        }
    }
    
    /// Attempts to commit a note to GitHub without throwing errors
    /// Returns true if successful, false if queued or failed
    func commitBackground(note: Note) async -> Bool {
        do {
            try await commit(note: note)
            return true
        } catch {
            // Always queue on error - don't throw
            await commitQueue.enqueue(note: note)
            var updatedNote = note
            updatedNote.syncStatus = .pending
            await noteRepository.update(updatedNote)
            return false
        }
    }
    
    private func isGitHubConfigured(config: (owner: String, repo: String, branch: String)) -> Bool {
        guard !config.owner.isEmpty && !config.repo.isEmpty else {
            return false
        }
        // Check if authentication is set up
        return GitHubAuth.shared.hasAuthentication()
    }
    
    func pull() async throws {
        // Get config asynchronously
        let config = await getConfig()
        
        // Only pull if GitHub is fully configured
        guard isGitHubConfigured(config: config) else {
            // Silently return if not configured - no error
            return
        }
        
        // Verify we have owner and repo
        guard !config.owner.isEmpty && !config.repo.isEmpty else {
            return
        }
        
        do {
            // Recursively pull notes from all category folders
            let baseFolders = try await listCategoryFolders(owner: config.owner, repo: config.repo, branch: config.branch)
            
            // Process files from all folders
            for folder in baseFolders {
                let files: [GitHubFile]
                do {
                    files = try await githubClient.listFiles(
                        path: folder,
                        owner: config.owner,
                        repo: config.repo,
                        branch: config.branch
                    )
                } catch let error as GitHubError {
                    // If folder doesn't exist, skip it
                    if case .apiError(let message) = error, message.contains("404") || message.contains("Not Found") {
                        continue
                    }
                    // Re-throw other errors
                    throw error
                }
                
                // Process files in this folder
                for file in files where file.type == .file {
                    do {
                        let content = try await githubClient.getFile(
                            path: "\(folder)/\(file.name)",
                            owner: config.owner,
                            repo: config.repo,
                            branch: config.branch
                        )
                        
                        if let note = parseMarkdownContent(content, filename: file.name) {
                            await noteRepository.save(note)
                        }
                    } catch {
                        // Log but continue with other files
                        print("Error loading file \(file.name): \(error.localizedDescription)")
                        continue
                    }
                }
            }
        } catch let error as GitHubError {
            // Only log real errors (suppresses expected 404s)
            let message = error.localizedDescription
            // Suppress expected errors (404, not configured, etc.)
            if !message.contains("404") && !message.contains("Not Found") {
                // Real error - but don't spam logs, just silently fail
                // print("Error pulling from GitHub: \(message)")
            }
            // Don't throw - just fail silently for better UX
        } catch {
            // Unexpected errors - suppress to avoid log spam
            // print("Unexpected error pulling from GitHub: \(error.localizedDescription)")
        }
    }
    
    func sync() async {
        // Get config asynchronously
        let config = await getConfig()
        
        // Only sync if GitHub is configured
        guard isGitHubConfigured(config: config) else {
            // Just process any pending commits that might be queued
            await commitQueue.processQueue()
            return
        }
        
        // Process pending commits (push local changes)
        await commitQueue.processQueue()
        
        // Pull latest changes (if configured)
        // Use try? to silently fail if pull doesn't work
        // This prevents error spam in logs
        try? await pull()
    }
    
    /// Push all pending notes to GitHub
    func push() async throws {
        let config = await getConfig()
        guard isGitHubConfigured(config: config) else {
            throw RepositoryError.notConfigured
        }
        
        // Process all pending commits in the queue
        await commitQueue.processQueue()
        
        // Also commit any notes that are marked as pending
        let allNotes = await noteRepository.fetchAll()
        let pendingNotes = allNotes.filter { $0.syncStatus == .pending }
        
        for note in pendingNotes {
            do {
                try await commit(note: note)
            } catch {
                // Continue with other notes even if one fails
                print("Failed to commit note \(note.id): \(error.localizedDescription)")
            }
        }
    }
    
    /// Generate a unique filename for a note
    /// Format: YYYY-MM-DD-uuid-short-title.md
    /// This ensures uniqueness even if multiple notes have the same title/date
    private func generateFilename(for note: Note) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: note.dateCreated)
        
        // Use first 8 characters of UUID for uniqueness
        let uuidPrefix = String(note.id.uuidString.prefix(8))
        
        // Sanitize title (limit length to avoid very long filenames)
        let sanitizedTitle = note.title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
            .prefix(50) // Limit title length
        
        return "\(dateString)-\(uuidPrefix)-\(sanitizedTitle).md"
    }
    
    /// Generate folder path based on note category
    /// Organizes notes into category-specific folders for better repository organization
    private func generateFolderPath(for note: Note) -> String {
        let baseFolder = "notes"
        
        guard let category = note.category, !category.isEmpty else {
            // No category - put in general folder
            return "\(baseFolder)/general"
        }
        
        // Sanitize category name for folder
        let sanitizedCategory = category
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        
        // Map common categories to folder names
        let folderMap: [String: String] = [
            "research-paper": "research-papers",
            "code-repository": "code-repositories",
            "tutorial": "tutorials",
            "article": "articles",
            "documentation": "documentation",
            "news": "news",
            "video": "videos",
            "podcast": "podcasts",
            "book": "books"
        ]
        
        let folderName = folderMap[sanitizedCategory] ?? sanitizedCategory
        return "\(baseFolder)/\(folderName)"
    }
    
    /// Generate descriptive commit message for the note
    private func generateCommitMessage(for note: Note) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: note.dateCreated)
        
        var message = "📝 Add note: \(note.title)"
        
        // Add category to commit message if available
        if let category = note.category {
            message += " [\(category)]"
        }
        
        // Add tags if available
        if !note.tags.isEmpty {
            let tagList = note.tags.prefix(3).joined(separator: ", ")
            message += " #\(tagList)"
        }
        
        message += " (\(dateString))"
        
        return message
    }
    
    private func generateMarkdownContent(for note: Note) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: note.dateCreated)
        
        // Enhanced front matter with more metadata
        let frontMatter = """
        ---
        title: \(escapeYAMLString(note.title))
        url: \(note.url?.absoluteString ?? "")
        tags: [\(note.tags.map { escapeYAMLString($0) }.joined(separator: ", "))]
        category: \(note.category ?? "")
        date: \(dateString)
        id: \(note.id.uuidString)
        created: \(ISO8601DateFormatter().string(from: note.dateCreated))
        modified: \(ISO8601DateFormatter().string(from: note.dateModified))
        ---
        
        """
        
        // Build markdown content
        var markdown = "# \(note.title)\n\n"
        
        // Add summary section
        if !note.summary.isEmpty {
            markdown += "## Summary\n\n"
            markdown += "\(note.summary)\n\n"
        }
        
        // Add category badge if available
        if let category = note.category {
            markdown += "**Category:** `\(category)`  \n\n"
        }
        
        // Add tags section
        if !note.tags.isEmpty {
            markdown += "**Tags:** "
            markdown += note.tags.map { "`\($0)`" }.joined(separator: " ")
            markdown += "\n\n"
        }
        
        // Add URL if available
        if let url = note.url {
            markdown += "**Source:** [\(url.absoluteString)](\(url.absoluteString))\n\n"
        }
        
        // Add content section
        if !note.content.isEmpty {
            markdown += "---\n\n"
            markdown += "## Content\n\n"
            markdown += "\(note.content)\n"
        }
        
        return frontMatter + markdown
    }
    
    /// Escape special characters in YAML strings
    private func escapeYAMLString(_ string: String) -> String {
        // If string contains special characters, quote it
        if string.contains(":") || string.contains("\"") || string.contains("'") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return string
    }
    
    private func parseMarkdownContent(_ content: String, filename: String) -> Note? {
        // Robust markdown parser - extract front matter and content
        
        // Check for front matter (YAML between ---)
        let frontMatterPattern = "^---\\s*\\n(.*?)\\n---\\s*\\n(.*)$"
        
        guard let regex = try? NSRegularExpression(pattern: frontMatterPattern, options: [.dotMatchesLineSeparators, .anchorsMatchLines]),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              match.numberOfRanges >= 3 else {
            // No front matter, parse as simple markdown
            return parseMarkdownWithoutFrontMatter(content: content, filename: filename)
        }
        
        let frontMatterRange = Range(match.range(at: 1), in: content)!
        let bodyRange = Range(match.range(at: 2), in: content)!
        
        let frontMatter = String(content[frontMatterRange])
        let body = String(content[bodyRange])
        
        // Parse front matter
        var title = ""
        var url: URL?
        var tags: [String] = []
        var category: String?
        var dateString = ""
        var noteId: UUID?
        var createdDate: Date?
        var modifiedDate: Date?
        
        for line in frontMatter.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("title:") {
                let value = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                // Handle quoted strings
                title = value
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("url:") {
                let value = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                url = URL(string: value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")))
            } else if trimmed.hasPrefix("tags:") {
                let value = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                // Handle both [tag1, tag2] and "tag1, tag2" formats
                let cleaned = value
                    .trimmingCharacters(in: CharacterSet(charactersIn: "[\\]\"'"))
                tags = cleaned
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } else if trimmed.hasPrefix("category:") {
                let value = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                let cleaned = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                category = cleaned.isEmpty ? nil : cleaned
            } else if trimmed.hasPrefix("date:") {
                dateString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            } else if trimmed.hasPrefix("id:") {
                let value = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                noteId = UUID(uuidString: value)
            } else if trimmed.hasPrefix("created:") {
                let value = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                createdDate = ISO8601DateFormatter().date(from: value)
            } else if trimmed.hasPrefix("modified:") {
                let value = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                modifiedDate = ISO8601DateFormatter().date(from: value)
            }
        }
        
        // Parse date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var date = dateFormatter.date(from: dateString)
        
        // Try alternative date formats
        if date == nil {
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            date = dateFormatter.date(from: dateString)
        }
        if date == nil {
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            date = dateFormatter.date(from: dateString)
        }
        
        let finalDate = date ?? Date()
        
        // Extract summary and content from body
        let bodyLines = body.components(separatedBy: .newlines)
        
        // Skip markdown headers and find first substantial paragraph
        var summary = ""
        var contentStart = 0
        
        for (index, line) in bodyLines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip headers and empty lines
            if trimmed.hasPrefix("#") || trimmed.isEmpty {
                continue
            }
            
            // First substantial line is summary
            if summary.isEmpty && trimmed.count > 10 {
                summary = trimmed
                contentStart = index
                break
            }
        }
        
        // Extract full content (skip title if it's a markdown header)
        var contentLines = Array(bodyLines.dropFirst(contentStart))
        
        // Remove markdown title if present (first # header)
        if let firstLine = contentLines.first, firstLine.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            contentLines.removeFirst()
        }
        
        let fullContent = contentLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use summary from content if front matter summary wasn't explicit
        if summary.isEmpty {
            summary = String(fullContent.prefix(200))
        }
        
        // Use parsed dates if available, otherwise use parsed date or current date
        let finalCreatedDate = createdDate ?? finalDate
        let finalModifiedDate = modifiedDate ?? finalDate
        
        return Note(
            id: noteId ?? UUID(),
            title: title.isEmpty ? extractTitleFromFilename(filename) : title,
            summary: summary.isEmpty ? "No summary available" : summary,
            content: fullContent.isEmpty ? body : fullContent,
            url: url,
            tags: tags,
            category: category,
            dateCreated: finalCreatedDate,
            dateModified: finalModifiedDate,
            syncStatus: .synced
        )
    }
    
    private func parseMarkdownWithoutFrontMatter(content: String, filename: String) -> Note? {
        // Parse markdown without front matter
        let lines = content.components(separatedBy: .newlines)
        
        var title = ""
        var summary = ""
        var contentLines: [String] = []
        
        // Extract title (first # header or first line)
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("# ") {
                title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                contentLines = Array(lines.dropFirst(index + 1))
                break
            } else if !trimmed.isEmpty && title.isEmpty {
                title = trimmed
                contentLines = Array(lines.dropFirst(index + 1))
                break
            }
        }
        
        // Extract summary (first paragraph after title)
        for line in contentLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                summary = trimmed
                break
            }
        }
        
        let fullContent = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        return Note(
            title: title.isEmpty ? extractTitleFromFilename(filename) : title,
            summary: summary.isEmpty ? String(fullContent.prefix(200)) : summary,
            content: fullContent,
            url: nil,
            tags: [],
            category: nil,
            dateCreated: Date(),
            dateModified: Date(),
            syncStatus: .synced
        )
    }
    
    /// List all category folders under notes/
    private func listCategoryFolders(owner: String, repo: String, branch: String) async throws -> [String] {
        var folders: [String] = []
        
        // Try to list notes directory
        do {
            let files = try await githubClient.listFiles(
                path: "notes",
                owner: owner,
                repo: repo,
                branch: branch
            )
            
            // Add all directories
            for file in files where file.type == .directory {
                folders.append("notes/\(file.name)")
            }
            
            // If no directories found, check if there are files directly in notes/
            // (legacy format - we'll still support it)
            let directFiles = files.filter { $0.type == .file }
            if !directFiles.isEmpty {
                // Files are directly in notes/, not in subfolders
                // We'll handle this by checking notes/ directly too
                folders.append("notes")
            }
        } catch let error as GitHubError {
            // If notes directory doesn't exist yet, that's OK
            if case .apiError(let message) = error, message.contains("404") || message.contains("Not Found") {
                return []
            }
            throw error
        }
        
        // If no folders found, return base notes folder as fallback
        return folders.isEmpty ? ["notes"] : folders
    }
    
    private func extractTitleFromFilename(_ filename: String) -> String {
        // Extract title from filename like "2025-01-15-uuid-short-title.md"
        var title = filename
            .replacingOccurrences(of: ".md", with: "", options: .caseInsensitive)
        
        // Remove date and UUID prefix if present (format: YYYY-MM-DD-UUID-)
        let pattern = "^\\d{4}-\\d{2}-\\d{2}-[a-f0-9]{8}-"
        if let range = title.range(of: pattern, options: .regularExpression) {
            title = String(title[range.upperBound...])
        } else {
            // Try just date pattern (legacy format)
            if let dateRange = title.range(of: "^\\d{4}-\\d{2}-\\d{2}-", options: .regularExpression) {
                title = String(title[dateRange.upperBound...])
            }
        }
        
        // Replace dashes with spaces and capitalize
        title = title.replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
        
        return title.isEmpty ? "Untitled" : title
    }
}

enum RepositoryError: Error {
    case encodingError
    case decodingError
    case notConfigured
}

