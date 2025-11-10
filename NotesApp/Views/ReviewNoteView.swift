import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ReviewNoteView: View {
    @State var note: Note
    @State var analysis: NoteAnalysis
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ReviewNoteViewModel()
    @State private var availableCategories: [String] = []
    @State private var editableWhatIsIt: String = ""
    @State private var editableWhyAdvantageous: String = ""
    @State private var hasInitialized = false
    @State private var userModifiedTags = false
    @State private var isUpdatingTags = false  // Prevent recursive updates
    
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
                VStack(spacing: CGFloat.adaptiveSpacingL) {
                    // Basic Info Card
                    basicInfoCard
                        .padding(.top, CGFloat.adaptiveSpacingL)
                    
                    // Analysis Cards
                    if !editableWhatIsIt.isEmpty || !editableWhyAdvantageous.isEmpty {
                        analysisCards
                    }
                    
                    // Tags Card
                    tagsCard
                    
                    // Preview Card
                    previewCard
                }
                .adaptiveHorizontalPadding()
                .padding(.vertical, CGFloat.adaptiveSpacingL)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            
            // Footer with actions
            footerSection
        }
        .frame(width: 900, height: 700)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
        }
        .overlay {
            if viewModel.isSaving {
                savingOverlay
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
            if !hasInitialized {
                initializeData()
            }
        }
        .onSubmit {
            if !viewModel.isSaving {
                saveNote()
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Review Note")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Review and edit before saving")
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
        .padding(.horizontal, CGFloat.adaptivePadding)
        .padding(.vertical, 20)
    }
    
    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Label("Title", systemImage: "text.bubble")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                TextField("Note title", text: $note.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.controlBackgroundColor))
                    }
            }
            
            // Category and Summary Row
            HStack(spacing: 16) {
                // Category
                VStack(alignment: .leading, spacing: 8) {
                    Label("Category", systemImage: "folder")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    categoryPicker
                }
                .frame(maxWidth: .infinity)
                
                // URL (if available)
                if note.url != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Source", systemImage: "link")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        urlLinkView
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            // Summary
            VStack(alignment: .leading, spacing: 8) {
                Label("Summary", systemImage: "doc.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                TextEditor(text: $note.summary)
                    .font(.system(size: 14))
                    .frame(height: 120)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.controlBackgroundColor))
                    }
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }
    
    private var categoryPicker: some View {
        Menu {
            Button("None") {
                note.category = nil
            }
            
            if let analysisCategory = analysis.category, !analysisCategory.isEmpty {
                Divider()
                Text("Suggested")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Button {
                    note.category = analysisCategory
                } label: {
                    HStack {
                        Text(analysisCategory)
                        if note.category == analysisCategory {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            if !availableCategories.isEmpty {
                Divider()
                Text("Categories")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                ForEach(availableCategories, id: \.self) { cat in
                    Button {
                        note.category = cat
                    } label: {
                        HStack {
                            Text(cat)
                            if note.category == cat {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(note.category ?? analysis.category ?? "Select category")
                    .foregroundColor(note.category != nil || analysis.category != nil ? .primary : .secondary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
        }
        .buttonStyle(.plain)
    }
    
    private var urlLinkView: some View {
        Group {
            if let url = note.url {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                        Text(url.host ?? url.absoluteString)
                            .lineLimit(1)
                            .font(.system(size: 13))
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.1))
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text("No URL")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.controlBackgroundColor))
                    }
            }
        }
    }
    
    private var analysisCards: some View {
        VStack(spacing: 16) {
            if !editableWhatIsIt.isEmpty {
                analysisCard(
                    title: "What is this?",
                    icon: "questionmark.circle.fill",
                    text: $editableWhatIsIt,
                    color: .blue
                )
            }
            
            if !editableWhyAdvantageous.isEmpty {
                analysisCard(
                    title: "Why is this useful?",
                    icon: "star.circle.fill",
                    text: $editableWhyAdvantageous,
                    color: .orange
                )
            }
        }
    }
    
    private func analysisCard(title: String, icon: String, text: Binding<String>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            TextEditor(text: text)
                .font(.system(size: 14))
                .frame(height: 100)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                }
                .scrollContentBackground(.hidden)
                .onChange(of: text.wrappedValue) { _, newValue in
                    updateAnalysis()
                }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }
    
    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.purple)
                Text("Tags")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            TagEditorView(tags: Binding(
                get: { 
                    // Always return current tags
                    note.tags 
                },
                set: { newTags in
                    // Prevent recursive updates
                    guard !isUpdatingTags else {
                        print("ReviewNoteView (macOS): Skipping tag update - already updating")
                        return
                    }
                    
                    // Debug logging
                    print("ReviewNoteView (macOS): Binding setter called")
                    print("  Current tags: \(note.tags)")
                    print("  New tags: \(newTags)")
                    print("  User modified tags flag: \(userModifiedTags)")
                    
                    // CRITICAL: Always update tags when binding is set (TagEditorView handles preservation)
                    // The TagEditorView ensures all existing tags are preserved when adding
                    let oldTags = note.tags
                    
                    // Only update if tags actually changed to avoid unnecessary updates
                    guard newTags != oldTags else {
                        print("  Tags unchanged, skipping update")
                        return
                    }
                    
                    // Update tags atomically with guard to prevent recursive calls
                    isUpdatingTags = true
                    defer { isUpdatingTags = false }
                    
                    note.tags = newTags
                    userModifiedTags = true
                    print("  Tags changed, updating analysis...")
                    // Update analysis with current tags to preserve them
                    updateAnalysis()
                }
            ))
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }
    
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green)
                Text("Content Preview")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            ScrollView {
                Text(note.content)
                    .font(.system(size: 13, design: .default))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 120)
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Button(action: { dismiss() }) {
                    Text("Discard")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                HStack(spacing: 12) {
                    keyboardShortcutHint(key: "⌘S", description: "Save")
                    keyboardShortcutHint(key: "Esc", description: "Discard")
                }
            }
            .padding(.horizontal, CGFloat.adaptivePadding)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            // Save Button
            HStack {
                Spacer()
                
                Button(action: saveNote) {
                    HStack(spacing: 10) {
                        if viewModel.isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(viewModel.isSaving ? "Saving..." : "Save Note")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .frame(height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.isSaving ? Color.accentColor.opacity(0.7) : Color.accentColor)
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Save note (⌘↩)")
                
                Spacer()
            }
            .padding(.horizontal, CGFloat.adaptivePadding)
            .padding(.bottom, 20)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
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
    
    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                    .tint(.white)
                
                Text("Saving note...")
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
    private var iosFormContent: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $note.title)
            }
            
            Section("Category") {
                categoryPicker
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
                        updateAnalysis()
                    }
            }
            
            Section("Why is this useful?") {
                TextEditor(text: $editableWhyAdvantageous)
                    .frame(height: 100)
                    .font(.subheadline)
                    .onChange(of: editableWhyAdvantageous) { _, newValue in
                        updateAnalysis()
                    }
            }
            
            Section("Tags") {
            TagEditorView(tags: Binding(
                get: { 
                    // Always return current tags
                    note.tags 
                },
                set: { newTags in
                    // Prevent recursive updates
                    guard !isUpdatingTags else {
                        print("ReviewNoteView (iOS): Skipping tag update - already updating")
                        return
                    }
                    
                    // Debug logging
                    print("ReviewNoteView (iOS): Binding setter called")
                    print("  Current tags: \(note.tags)")
                    print("  New tags: \(newTags)")
                    print("  User modified tags flag: \(userModifiedTags)")
                    
                    // CRITICAL: Always update tags when binding is set (TagEditorView handles preservation)
                    // The TagEditorView ensures all existing tags are preserved when adding
                    let oldTags = note.tags
                    
                    // Only update if tags actually changed to avoid unnecessary updates
                    guard newTags != oldTags else {
                        print("  Tags unchanged, skipping update")
                        return
                    }
                    
                    // Update tags atomically with guard to prevent recursive calls
                    isUpdatingTags = true
                    defer { isUpdatingTags = false }
                    
                    note.tags = newTags
                    userModifiedTags = true
                    print("  Tags changed, updating analysis...")
                    // Update analysis with current tags to preserve them
                    updateAnalysis()
                }
            ))
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
    }
    
    private var categoryPicker: some View {
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
    
    private var iosView: some View {
        NavigationStack {
            iosFormContent
                .navigationTitle("Review Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Discard") {
                            HapticFeedback.selection()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            saveNote()
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
                    if !hasInitialized {
                        initializeData()
                    }
                }
        }
    }
    #endif
    
    // MARK: - Helper Methods
    private func initializeData() {
        // Only initialize once - never overwrite user changes
        guard !hasInitialized else { return }
        
        // Apply analysis results only if note fields are empty or not set
        if note.title.isEmpty {
            note.title = analysis.title
        }
        if note.summary.isEmpty {
            note.summary = analysis.summary
        }
        
        // Only set tags from analysis if note has no tags AND user hasn't modified them
        // CRITICAL: Once userModifiedTags is true, NEVER modify tags from analysis
        // Also prevent updates if we're currently updating tags to avoid conflicts
        if !isUpdatingTags {
            if note.tags.isEmpty && !userModifiedTags {
                isUpdatingTags = true
                defer { isUpdatingTags = false }
                note.tags = analysis.tags
            } else if !note.tags.isEmpty && !userModifiedTags {
                // Merge: add analysis tags that aren't already present (only on first init)
                let existingTagsSet = Set(note.tags.map { $0.lowercased() })
                let newTags = analysis.tags.filter { !existingTagsSet.contains($0.lowercased()) }
                if !newTags.isEmpty {
                    isUpdatingTags = true
                    defer { isUpdatingTags = false }
                    var mergedTags = note.tags
                    mergedTags.append(contentsOf: newTags)
                    note.tags = mergedTags
                }
            }
        }
        // If userModifiedTags is true, don't touch tags at all - preserve user's tags
        
        if note.category == nil {
            note.category = analysis.category
        }
        
        // Initialize editable fields from analysis (only if empty)
        if editableWhatIsIt.isEmpty {
            editableWhatIsIt = analysis.whatIsIt ?? ""
        }
        if editableWhyAdvantageous.isEmpty {
            editableWhyAdvantageous = analysis.whyAdvantageous ?? ""
        }
        
        // Load categories
        Task {
            await loadCategories()
        }
        
        hasInitialized = true
    }
    
    private func updateAnalysis() {
        // Use note.tags to preserve user modifications
        // CRITICAL: Always use note.tags (current state) to preserve any user edits
        // If note.tags is empty but userModifiedTags is true, keep it empty (user cleared them)
        // Otherwise, use note.tags which contains the current state
        let tagsToUse = note.tags // Always use current note.tags to preserve user changes
        let updatedAnalysis = NoteAnalysis(
            title: note.title,
            summary: note.summary,
            tags: tagsToUse, // Always use current note.tags to preserve user changes
            category: note.category ?? analysis.category,
            whatIsIt: editableWhatIsIt.isEmpty ? nil : editableWhatIsIt,
            whyAdvantageous: editableWhyAdvantageous.isEmpty ? nil : editableWhyAdvantageous
        )
        analysis = updatedAnalysis
        appState.pendingNoteAnalysis = updatedAnalysis
    }
    
    private func saveNote() {
        // Ensure analysis is updated with latest note data before saving
        updateAnalysis()
        
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

