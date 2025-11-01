import SwiftUI

struct NoteDetailView: View {
    @State var note: Note
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = NoteDetailViewModel()
    @State private var showDeleteConfirmation = false
    @State private var isReady = false
    
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
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Delete button
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    
                    // Save button
                    Button {
                        Task {
                            await viewModel.save(note: note)
                            if viewModel.errorMessage == nil {
                                #if os(iOS)
                                HapticFeedback.success()
                                #endif
                                dismiss()
                            }
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .disabled(viewModel.isSaving || viewModel.isDeleting)
                }
            }
            .alert("Delete Note", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.delete(note: note)
                        if viewModel.errorMessage == nil {
                            #if os(iOS)
                            HapticFeedback.success()
                            #endif
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this note? This action cannot be undone.")
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
            .task {
                // Mark view as ready after initial render to prevent blocking
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                isReady = true
            }
        }
    }
}

@MainActor
class NoteDetailViewModel: ObservableObject {
    private let noteRepository = NoteRepository.shared
    @Published var isSaving = false
    @Published var isDeleting = false
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
    
    func delete(note: Note) async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        
        // Delete locally first
        await noteRepository.delete(note)
        
        // Notify GitHub about deletion (attempt to mark as deleted or remove from sync)
        // This is a background task - doesn't block the UI
        Task(priority: .background) {
            // GitHub deletion handling could be added here if needed
            // For now, local deletion is sufficient
        }
    }
}

