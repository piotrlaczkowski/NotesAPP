import SwiftUI

struct ReviewNoteView: View {
    @State var note: Note
    @State var analysis: NoteAnalysis
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ReviewNoteViewModel()
    @State private var availableCategories: [String] = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $note.title)
                }
                
                Section("Category") {
                    if let category = analysis.category {
                        Picker("Category", selection: Binding(
                            get: { note.category ?? category },
                            set: { note.category = $0 }
                        )) {
                            ForEach(availableCategories, id: \.self) { cat in
                                Text(cat).tag(cat as String?)
                            }
                            Text("None").tag(String?.none)
                        }
                    } else {
                        Picker("Category", selection: $note.category) {
                            ForEach(availableCategories, id: \.self) { cat in
                                Text(cat).tag(cat as String?)
                            }
                            Text("None").tag(String?.none)
                        }
                    }
                }
                
                Section("Summary") {
                    TextEditor(text: $note.summary)
                        .frame(height: 100)
                }
                
                if let whatIsIt = analysis.whatIsIt, !whatIsIt.isEmpty {
                    Section("What is this?") {
                        Text(whatIsIt)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    }
                }
                
                if let whyAdvantageous = analysis.whyAdvantageous, !whyAdvantageous.isEmpty {
                    Section("Why is this useful?") {
                        Text(whyAdvantageous)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
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

