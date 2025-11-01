import SwiftUI

struct ReviewNoteView: View {
    @State var note: Note
    @State var analysis: NoteAnalysis
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ReviewNoteViewModel()
    @State private var availableCategories: [String] = []
    @State private var editableWhatIsIt: String = ""
    @State private var editableWhyAdvantageous: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $note.title)
                }
                
                Section("Category") {
                    Picker("Category", selection: Binding(
                        get: { note.category ?? analysis.category },
                        set: { 
                            if $0?.isEmpty ?? true {
                                note.category = nil
                            } else {
                                note.category = $0
                            }
                        }
                    )) {
                        Text("None").tag(String?.none)
                        
                        // Add a divider by creating two groups
                        if let analysisCategory = analysis.category, !analysisCategory.isEmpty {
                            Section("Suggested") {
                                Text(analysisCategory).tag(analysisCategory as String?)
                            }
                        }
                        
                        Section("Categories") {
                            ForEach(availableCategories, id: \.self) { cat in
                                Text(cat).tag(cat as String?)
                            }
                        }
                    }
                }
                
                Section("Summary") {
                    TextEditor(text: $note.summary)
                        .frame(height: 100)
                }
                
                Section("What is this?") {
                    TextEditor(text: $editableWhatIsIt)
                        .frame(height: 100)
                        .font(.subheadline)
                        .onChange(of: editableWhatIsIt) { _, newValue in
                            // Update both local analysis and AppState when user edits
                            let updatedAnalysis = NoteAnalysis(
                                title: analysis.title,
                                summary: analysis.summary,
                                tags: analysis.tags,
                                category: analysis.category,
                                whatIsIt: newValue.isEmpty ? nil : newValue,
                                whyAdvantageous: analysis.whyAdvantageous
                            )
                            analysis = updatedAnalysis
                            appState.pendingNoteAnalysis = updatedAnalysis
                        }
                }
                
                Section("Why is this useful?") {
                    TextEditor(text: $editableWhyAdvantageous)
                        .frame(height: 100)
                        .font(.subheadline)
                        .onChange(of: editableWhyAdvantageous) { _, newValue in
                            // Update both local analysis and AppState when user edits
                            let updatedAnalysis = NoteAnalysis(
                                title: analysis.title,
                                summary: analysis.summary,
                                tags: analysis.tags,
                                category: analysis.category,
                                whatIsIt: analysis.whatIsIt,
                                whyAdvantageous: newValue.isEmpty ? nil : newValue
                            )
                            analysis = updatedAnalysis
                            appState.pendingNoteAnalysis = updatedAnalysis
                        }
                }
                
                Section("Tags") {
                    TagEditorView(tags: $note.tags)
                }
                
                Section("URL") {
                    if let url = note.url {
                        Link(destination: url) {
                            Text(url.absoluteString)
                                .lineLimit(2)
                        }
                    }
                }
                
                Section("Content Preview") {
                    Text(note.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(5)
                }
            }
            .navigationTitle("Review Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        #if os(iOS)
                        HapticFeedback.selection()
                        #endif
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            // Update analysis with edited values before approving
                            var updatedAnalysis = analysis
                            // Note: NoteAnalysis is a struct with let properties, so we can't modify it
                            // Instead, we just save the note (the analysis is already stored separately)
                            // The edited values are for display/review only
                            
                            await viewModel.approve(note: note)
                            if viewModel.errorMessage == nil {
                                #if os(iOS)
                                HapticFeedback.success()
                                #endif
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dismiss()
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text("Approve")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSaving)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                // Apply analysis results
                note.title = analysis.title
                note.summary = analysis.summary
                note.tags = analysis.tags
                if note.category == nil {
                    note.category = analysis.category
                }
                
                // Initialize editable fields from analysis
                editableWhatIsIt = analysis.whatIsIt ?? ""
                editableWhyAdvantageous = analysis.whyAdvantageous ?? ""
                
                // Load categories
                Task {
                    await loadCategories()
                }
            }
        }
    }
    
    private func loadCategories() async {
        availableCategories = await CategoryManager.shared.getAllCategories()
    }
}

@MainActor
class ReviewNoteViewModel: ObservableObject {
    private let noteRepository = NoteRepository.shared
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    func approve(note: Note) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        // Always save locally first
        await noteRepository.save(note)
        
        // Sync to GitHub in background (non-blocking)
        // Use Task with priority to ensure it completes but doesn't block
        Task(priority: .background) {
            await RepositoryManager.shared.commitBackground(note: note)
        }
        
        // Local save always succeeds
        #if os(iOS)
        HapticFeedback.success()
        #endif
    }
}

