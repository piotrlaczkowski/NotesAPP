import SwiftUI

struct NoteDetailView: View {
    @State var note: Note
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = NoteDetailViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // URL
                    if let url = note.url {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "link")
                                Text(url.absoluteString)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Title", text: $note.title)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $note.summary)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TagEditorView(tags: $note.tags)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ScrollView {
                            Text(note.content)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .frame(maxHeight: 300)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.save(note: note)
                            if viewModel.errorMessage == nil {
                                #if os(iOS)
                                HapticFeedback.success()
                                #endif
                                dismiss()
                            }
                        }
                    }
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
        }
    }
}

@MainActor
class NoteDetailViewModel: ObservableObject {
    private let noteRepository = NoteRepository.shared
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    func save(note: Note) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        // Always save locally first
        await noteRepository.update(note)
        
        // Sync to GitHub in background (non-blocking)
        // Use Task with priority to ensure it completes but doesn't block
        Task(priority: .background) {
            await RepositoryManager.shared.commitBackground(note: note)
        }
        
        // Local save always succeeds - no error shown
    }
}

