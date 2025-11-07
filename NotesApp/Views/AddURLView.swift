import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AddURLView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var urlText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var isValidURL = false
    @State private var urlPreview: String = ""
    
    var body: some View {
        #if os(macOS)
        macView
        #else
        iosView
        #endif
    }
    
    // MARK: - macOS View
    #if os(macOS)
    private var macView: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Main Content
            ScrollView {
                VStack(spacing: .adaptiveSpacingL) {
                    // URL Input Section
                    urlInputSection
                        .padding(.top, .adaptiveSpacingL)
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .adaptiveHorizontalPadding()
                .padding(.vertical, .adaptiveSpacingL)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            
            // Footer with keyboard shortcuts
            footerSection
        }
        .frame(width: 700, height: 500)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
        }
        .overlay {
            if viewModel.isLoading {
                loadingOverlay
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
        .onAppear {
            pasteFromClipboard()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
        .onChange(of: urlText) { _, newValue in
            validateURL(newValue)
        }
        .onSubmit {
            if isValidURL && !viewModel.isLoading {
                analyzeURL()
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Note from URL")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Analyze web content and create a note")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, .adaptivePadding)
        .padding(.vertical, 20)
    }
    
    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                
                Text("URL")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TextField("https://example.com", text: $urlText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, design: .default))
                        .focused($isTextFieldFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(
                                            isTextFieldFocused ? Color.accentColor : Color.clear,
                                            lineWidth: 2
                                        )
                                }
                        }
                        .overlay(alignment: .trailing) {
                            if !urlText.isEmpty {
                                HStack(spacing: 8) {
                                    if isValidURL {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 16))
                                    } else {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 16))
                                    }
                                    
                                    Button(action: { urlText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.trailing, 12)
                            }
                        }
                        .animation(.smoothSpring, value: isTextFieldFocused)
                        .animation(.smoothSpring, value: isValidURL)
                    
                    Button(action: pasteFromClipboard) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.1))
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Paste from clipboard (⌘V)")
                    .keyboardShortcut("v", modifiers: .command)
                }
                
                // URL Preview
                if !urlPreview.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(urlPreview)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: analyzeURL) {
                HStack(spacing: 10) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(viewModel.isLoading ? "Analyzing..." : "Analyze URL")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isValidURL && !viewModel.isLoading
                            ? Color.accentColor
                            : Color.accentColor.opacity(0.5)
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(!isValidURL || viewModel.isLoading)
            .help("Analyze URL (Return)")
            .keyboardShortcut(.return, modifiers: [])
            .animation(.smoothSpring, value: viewModel.isLoading)
            .animation(.smoothSpring, value: isValidURL)
            
            // Secondary actions
            HStack(spacing: 12) {
                Button(action: { urlText = "" }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Clear")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(urlText.isEmpty)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                HStack(spacing: 16) {
                    keyboardShortcutHint(key: "⌘V", description: "Paste")
                    keyboardShortcutHint(key: "↩", description: "Analyze")
                    keyboardShortcutHint(key: "Esc", description: "Close")
                }
                
                Spacer()
                
                if isValidURL {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Text("Valid URL")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, .adaptivePadding)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }
    
    private func keyboardShortcutHint(key: String, description: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                }
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                    .tint(.white)
                
                Text("Analyzing content...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }
        }
    }
    #endif
    
    // MARK: - iOS View
    #if os(iOS)
    private var iosView: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter URL", text: $urlText)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .focused($isTextFieldFocused)
                        .onAppear {
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
                        analyzeURL()
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
    #endif
    
    // MARK: - Helper Methods
    private func validateURL(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            isValidURL = false
            urlPreview = ""
            return
        }
        
        // Add https:// if no scheme
        var urlString = trimmed
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        // Validate URL
        if let url = URL(string: urlString), url.scheme != nil, url.host != nil {
            isValidURL = true
            urlPreview = url.host ?? ""
        } else {
            isValidURL = false
            urlPreview = ""
        }
    }
    
    private func analyzeURL() {
        var finalURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https:// if no scheme
        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
            finalURL = "https://" + finalURL
        }
        
        Task {
            await viewModel.analyzeURL(finalURL)
            if viewModel.errorMessage == nil && viewModel.pendingNoteToReview != nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    dismiss()
                }
            }
        }
    }
    
    private func pasteFromClipboard() {
        #if os(iOS)
        if let clipboardString = UIPasteboard.general.string,
           clipboardString.contains("http://") || clipboardString.contains("https://") {
            urlText = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
            validateURL(urlText)
        }
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        if let clipboardString = pasteboard.string(forType: .string),
           clipboardString.contains("http://") || clipboardString.contains("https://") {
            urlText = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
            validateURL(urlText)
        }
        #endif
    }
}

