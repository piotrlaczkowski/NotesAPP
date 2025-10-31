import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AddURLView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var urlText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter URL", text: $urlText)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .focused($isTextFieldFocused)
                        .onAppear {
                            // Try to paste from clipboard
                            pasteFromClipboard()
                            isTextFieldFocused = true
                        }
                    
                    Button("Paste from Clipboard") {
                        pasteFromClipboard()
                    }
                } header: {
                    Text("URL")
                } footer: {
                    Text("Enter a URL to analyze and create a note. You can also paste a URL from your clipboard.")
                }
                
                Section {
                    Button {
                        Task {
                            #if os(iOS)
                            HapticFeedback.medium()
                            #endif
                            await viewModel.analyzeURL(urlText)
                            if viewModel.errorMessage == nil && viewModel.pendingNoteToReview != nil {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dismiss()
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text("Analyze URL")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlText.isEmpty || viewModel.isLoading)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
                }
            }
            .navigationTitle("Add Note from URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
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
    
    private func pasteFromClipboard() {
        #if os(iOS)
        if let clipboardString = UIPasteboard.general.string,
           clipboardString.contains("http://") || clipboardString.contains("https://") {
            urlText = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        if let clipboardString = pasteboard.string(forType: .string),
           clipboardString.contains("http://") || clipboardString.contains("https://") {
            urlText = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
    }
}

