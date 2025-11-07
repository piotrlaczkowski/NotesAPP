import SwiftUI
import Foundation

struct ReleaseCreationView: View {
    @StateObject private var viewModel = ReleaseCreationViewModel()
    @StateObject private var noteSelectionViewModel = NoteSelectionViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.systemBackground,
                    Color.systemBackground.opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Step indicator and content
            VStack(spacing: 0) {
                // Step progress bar
                stepProgressBar
                    .frame(height: 60)
                    .background(Color.systemGray6)
                
                // Content based on current step
                ZStack {
                    switch viewModel.currentStep {
                    case .selectNotes:
                        // Use a simpler inline note selection view without NavigationStack
                        NoteSelectionContentView(
                            viewModel: noteSelectionViewModel,
                            onNotesSelected: { selectedNoteIds in
                                viewModel.selectedNoteIds = Set(selectedNoteIds)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        viewModel.currentStep = .generating
                                    }
                                }
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .generating:
                        generatingView
                    case .editing:
                        ReleaseDraftEditor(
                            draftText: $viewModel.draftText,
                            releaseTitle: $viewModel.releaseTitle
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .reviewing:
                        reviewingView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom action buttons
                bottomActionsBar
                    .background(Color.systemGray6)
                    .frame(height: 70)
            }
        }
        .task {
            await viewModel.initializeReleaseService()
        }
    }
    
    private var stepProgressBar: some View {
        HStack(spacing: 0) {
            ForEach(ReleaseStep.allCases, id: \.self) { step in
                VStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isStepCompleted(step) || step == viewModel.currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(step.order))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(
                                    viewModel.isStepCompleted(step) || step == viewModel.currentStep ? .white : .secondary
                                )
                        )
                    
                    Text(step.title)
                        .font(.caption2)
                        .foregroundColor(step == viewModel.currentStep ? .blue : .secondary)
                }
                
                if step != ReleaseStep.allCases.last {
                    Divider()
                        .overlay(
                            Color.blue.opacity(viewModel.isStepCompleted(step) ? 1 : 0.2)
                        )
                }
            }
        }
        .padding(10)
    }
    
    private var generatingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 8) {
                    Text("Generating LinkedIn Post")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Our AI is crafting an engaging post from your selected notes...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                ProgressView(value: viewModel.generationProgress)
                    .frame(height: 4)
                    .tint(.blue)
            }
            .padding(32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var reviewingView: some View {
        ScrollView {
            VStack(spacing: CGFloat.adaptiveSpacingL) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Release Summary")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Title:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(viewModel.releaseTitle)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Notes Included:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(viewModel.selectedNoteIds.count)")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Date:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(Date().formatted(date: .abbreviated, time: .omitted))
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(12)
                    .background(Color.systemGray6)
                    .cornerRadius(10)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("LinkedIn Post Preview")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        MarkdownPreviewView(text: viewModel.draftText)
                    }
                    .padding(16)
                    .background(Color.systemBackground)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Source Notes Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Source Notes")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    SourceNotesListView(viewModel: viewModel)
                }
            }
            .adaptiveHorizontalPadding()
            .padding(.vertical, CGFloat.adaptiveSpacingM)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var bottomActionsBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                #if os(iOS)
                HapticFeedback.selection()
                #endif
                withAnimation {
                    viewModel.previousStep()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(10)
                .font(.subheadline)
                .fontWeight(.semibold)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentStep == .selectNotes || viewModel.isProcessing)
            
            if viewModel.currentStep == .reviewing {
                Button(action: {
                    #if os(iOS)
                    HapticFeedback.medium()
                    #endif
                    Task {
                        await viewModel.approveAndSave()
                        dismiss()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve & Save")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
            } else {
                Button(action: {
                    #if os(iOS)
                    HapticFeedback.selection()
                    #endif
                    // Sync selectedNoteIds from noteSelectionViewModel when moving from selectNotes
                    if viewModel.currentStep == .selectNotes {
                        viewModel.selectedNoteIds = noteSelectionViewModel.selectedNoteIds
                    }
                    withAnimation {
                        viewModel.nextStep()
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(viewModel.currentStep == .editing ? "Review" : "Next")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.plain)
                .disabled(
                    (viewModel.currentStep == .selectNotes && noteSelectionViewModel.selectedNoteIds.isEmpty) ||
                    (viewModel.currentStep == .generating && !viewModel.generationComplete) ||
                    viewModel.isProcessing
                )
            }
        }
        .padding(12)
    }
}

enum ReleaseStep: CaseIterable, Hashable {
    case selectNotes
    case generating
    case editing
    case reviewing
    
    var title: String {
        switch self {
        case .selectNotes: return "Select"
        case .generating: return "Generate"
        case .editing: return "Edit"
        case .reviewing: return "Review"
        }
    }
    
    var order: Int {
        switch self {
        case .selectNotes: return 1
        case .generating: return 2
        case .editing: return 3
        case .reviewing: return 4
        }
    }
}

@MainActor
class ReleaseCreationViewModel: ObservableObject {
    @Published var currentStep: ReleaseStep = .selectNotes
    @Published var selectedNoteIds: Set<UUID> = []
    @Published var releaseTitle: String = "Weekly Release"
    @Published var draftText: String = ""
    @Published var generationProgress: Double = 0
    @Published var generationComplete: Bool = false
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    private let releaseService = ReleaseService.shared
    private let llmManager = LLMManager.shared
    private let repositoryManager = RepositoryManager.shared
    private let noteRepository = NoteRepository.shared
    
    func initializeReleaseService() async {
        await releaseService.loadReleases()
    }
    
    func nextStep() {
        if currentStep == .selectNotes {
            currentStep = .generating
            Task {
                await generateLinkedInPost()
            }
        } else if currentStep == .generating {
            currentStep = .editing
        } else if currentStep == .editing {
            currentStep = .reviewing
        }
    }
    
    func previousStep() {
        switch currentStep {
        case .selectNotes:
            break
        case .generating:
            currentStep = .selectNotes
        case .editing:
            currentStep = .generating
        case .reviewing:
            currentStep = .editing
        }
    }
    
    func isStepCompleted(_ step: ReleaseStep) -> Bool {
        let currentOrder = currentStep.order
        return step.order < currentOrder
    }
    
    /// Get the actual Note objects for selected note IDs
    func getSelectedNotes() async -> [Note] {
        let allNotes = await noteRepository.fetchAll()
        return allNotes.filter { selectedNoteIds.contains($0.id) }
    }
    
    private func generateLinkedInPost() async {
        await MainActor.run {
            isProcessing = true
            generationProgress = 0
            generationComplete = false
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                generationComplete = true
            }
        }
        
        // Get selected notes
        let allNotes = await noteRepository.fetchAll()
        let selectedNotes = allNotes.filter { selectedNoteIds.contains($0.id) }
        // Build comprehensive summaries - include all relevant fields for complete context
        let summaries = selectedNotes.map { note -> String in
            var summaryParts: [String] = []
            
            // Always include title
            summaryParts.append("Title: \(note.title)")
            
            // Include summary (preferred) or content preview
            if !note.summary.isEmpty {
                summaryParts.append("Summary: \(note.summary)")
            } else if !note.content.isEmpty {
                // Use first 400 chars of content as summary for better context
                let contentPreview = String(note.content.prefix(400)) + (note.content.count > 400 ? "..." : "")
                summaryParts.append("Summary: \(contentPreview)")
            }
            
            // Include full content if it's not too long (for LLM to understand context)
            if !note.content.isEmpty && note.content.count < 2000 {
                summaryParts.append("Full Content: \(note.content)")
            } else if !note.content.isEmpty {
                // For long content, include beginning and key sections
                let beginning = String(note.content.prefix(500))
                summaryParts.append("Content Preview: \(beginning)...")
            }
            
            // Include URL if available (important for source attribution)
            if let url = note.url {
                summaryParts.append("Source URL: \(url.absoluteString)")
            }
            
            // Include category and tags for context
            if let category = note.category {
                summaryParts.append("Category: \(category)")
            }
            if !note.tags.isEmpty {
                summaryParts.append("Tags: \(note.tags.joined(separator: ", "))")
            }
            
            // Include date for temporal context
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            summaryParts.append("Date Saved: \(dateFormatter.string(from: note.dateCreated))")
            
            return summaryParts.joined(separator: "\n")
        }
        
        // Simulate generation progress with proper MainActor updates
        for i in 0..<5 {
            await MainActor.run {
                generationProgress = Double(i + 1) / 5.0
            }
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        }
        
        // Generate with timeout
        do {
            let post = try await withTimeout(seconds: 60) { [self, summaries] in
                try await self.llmManager.generateLinkedInPost(
                    noteSummaries: summaries,
                    topic: nil
                )
            }
            
            await MainActor.run {
                self.draftText = post
                self.generationProgress = 1.0
                self.generationComplete = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to generate post: \(error.localizedDescription)"
                self.showError = true
                self.draftText = "Unable to generate LinkedIn post. Please try again or edit manually."
                self.generationProgress = 1.0 // Set to 1.0 even on error so user can proceed
                self.generationComplete = true
            }
        }
    }
    
    // Helper function for timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Generation timed out after \(Int(seconds)) seconds"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    func approveAndSave() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Create release
            await releaseService.createRelease(
                title: releaseTitle,
                noteIds: Array(selectedNoteIds),
                linkedInDraft: draftText
            )
            
            // Get current release and approve it
            let releases = releaseService.releases
            if let firstDraft = releases.first(where: { !$0.isApproved && $0.title == releaseTitle }) {
                await releaseService.approveRelease(id: firstDraft.id, with: draftText)
                
                // Commit to GitHub if configured
                // Get a copy of all releases for markdown export
                let allReleases = releaseService.releases
                var markdown = "# Releases\n\nA collection of weekly summaries and interesting findings.\n\n"
                
                for release in allReleases.sorted(by: { $0.date > $1.date }) {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let dateString = dateFormatter.string(from: release.date)
                    
                    markdown += "## \(dateString) - \(release.title)\n\n"
                    markdown += "**Status:** \(release.isApproved ? "Approved" : "Draft")\n"
                    markdown += "**Notes Included:** \(release.noteIds.count)\n\n"
                    
                    let content = release.approvedDraft ?? release.linkedInDraft
                    markdown += content + "\n\n"
                    markdown += "---\n\n"
                }
                
                try? await repositoryManager.commitReleases(markdown)
            }
            
            // Reload releases in service to ensure list is updated and sorted
            await releaseService.loadReleases()
            
            #if os(iOS)
            HapticFeedback.success()
            #endif
        } catch {
            errorMessage = "Failed to save release: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Source Notes List View
struct SourceNotesListView: View {
    @ObservedObject var viewModel: ReleaseCreationViewModel
    @State private var notes: [Note] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if notes.isEmpty {
                Text("No notes selected")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            // Title
                            Text(note.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            // Summary or content preview
                            if !note.summary.isEmpty {
                                Text(note.summary)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else if !note.content.isEmpty {
                                Text(String(note.content.prefix(300)) + (note.content.count > 300 ? "..." : ""))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            // Metadata
                            HStack(spacing: 12) {
                                if let category = note.category {
                                    Label(category, systemImage: "tag.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                
                                if !note.tags.isEmpty {
                                    Label(note.tags.joined(separator: ", "), systemImage: "bookmark.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let url = note.url {
                                    Link(destination: url) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "link")
                                            Text("Source")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.systemGray6)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .task {
            notes = await viewModel.getSelectedNotes()
            isLoading = false
        }
    }
}

#Preview {
    ReleaseCreationView()
        .environmentObject(ReleaseService.shared)
}

