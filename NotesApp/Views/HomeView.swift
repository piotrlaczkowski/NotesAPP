import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var searchText = ""
    @State private var showReviewView = false
    @State private var selectedNote: Note?
    @AppStorage("notesLayoutStyle") private var layoutStyle: LayoutStyle = .grid
    @State private var selectedCategory: String? = nil
    @State private var selectedTags: Set<String> = []
    @State private var showFilters = false
    @State private var noteToDelete: Note?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if viewModel.notes.isEmpty && !viewModel.isLoading {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            // Header with stats
                            headerSection
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                            
                            // Filter sections
                            if hasFilters {
                                VStack(spacing: 16) {
                                    // Category filter
                                    if hasCategories {
                                        categoryFilterSection
                                            .padding(.horizontal, 20)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                    
                                    // Tag filter
                                    if hasTags {
                                        tagFilterSection
                                            .padding(.horizontal, 20)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                }
                                .padding(.bottom, 8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showFilters)
                            }
                            
                            // Notes display
                            if layoutStyle == .grid {
                                notesGrid
                            } else {
                                notesCarousel
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
                
                if viewModel.isLoading || isSearching {
                    ZStack {
                        Color(.systemBackground)
                            .opacity(0.8)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.blue)
                            
                            if isSearching {
                                Text("Searching...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading || isSearching)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search notes...")
            .overlay(alignment: .topTrailing) {
                if viewModel.isSyncing {
                    VStack {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                        )
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        #if os(iOS)
                        HapticFeedback.selection()
                        #endif
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showFilters.toggle()
                        }
                    } label: {
                        Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundColor(hasActiveFilters ? .blue : .secondary)
                            .symbolEffect(.bounce, value: showFilters)
                    }
                    .buttonStyle(.borderless)
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            #if os(iOS)
                            HapticFeedback.selection()
                            #endif
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                layoutStyle = layoutStyle == .grid ? .carousel : .grid
                            }
                        } label: {
                            Image(systemName: layoutStyle == .grid ? "rectangle.grid.1x2" : "square.grid.2x2")
                        }
                        .buttonStyle(.borderless)
                        
                        Button {
                            #if os(iOS)
                            HapticFeedback.medium()
                            #endif
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.showAddURLSheet = true
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                        
                        Menu {
                            Button {
                                Task {
                                    await viewModel.sync()
                                }
                            } label: {
                                Label("Sync (Push & Pull)", systemImage: "arrow.triangle.2.circlepath")
                            }
                            
                            Button {
                                Task {
                                    await viewModel.push()
                                }
                            } label: {
                                Label("Push to GitHub", systemImage: "arrow.up.circle")
                            }
                            
                            Button {
                                Task {
                                    await viewModel.pull()
                                }
                            } label: {
                                Label("Pull from GitHub", systemImage: "arrow.down.circle")
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                                .rotationEffect(.degrees(viewModel.isSyncing ? 360 : 0))
                                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: viewModel.isSyncing)
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.isSyncing)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddURLSheet) {
                AddURLView(viewModel: viewModel)
            }
            .sheet(item: $viewModel.pendingNoteToReview) { note in
                NavigationStack {
                    ReviewNoteView(
                        note: note,
                        analysis: viewModel.pendingNoteAnalysis ?? NoteAnalysis(
                            title: note.title,
                            summary: note.summary,
                            tags: note.tags,
                            category: note.category,
                            whatIsIt: nil,
                            whyAdvantageous: nil
                        )
                    )
                }
                .onDisappear {
                    // Clear analysis when sheet dismisses
                    viewModel.pendingNoteAnalysis = nil
                }
            }
            .sheet(item: $selectedNote) { note in
                NoteDetailView(note: note)
            }
            .alert("Delete Note", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let note = noteToDelete {
                        Task {
                            await deleteNote(note)
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this note? This action cannot be undone.")
            }
        }
        .task {
            await viewModel.loadNotes()
            // Initialize with all notes
            filteredNotesResult = viewModel.notes
            updateFilteredNotes()
        }
        .onChange(of: searchText) { _, _ in
            updateFilteredNotes()
        }
        .onChange(of: selectedCategory) { _, _ in
            updateFilteredNotes()
        }
        .onChange(of: selectedTags) { _, _ in
            updateFilteredNotes()
        }
        .onChange(of: viewModel.notes) { _, _ in
            updateFilteredNotes()
        }
    }
    
    @State private var filteredNotesResult: [Note] = []
    @State private var isSearching = false
    
    private var filteredNotes: [Note] {
        // Return cached result if available, otherwise return all notes
        return filteredNotesResult.isEmpty && !viewModel.notes.isEmpty ? viewModel.notes : filteredNotesResult
    }
    
    private func updateFilteredNotes() {
        Task {
            await MainActor.run {
                isSearching = true
            }
            
            defer {
                Task { @MainActor in
                    isSearching = false
                }
            }
            
            var notes = viewModel.notes
            let searchService = SearchService.shared
            
            // Apply category filter
            if let selectedCategory = selectedCategory {
                notes = await searchService.filterByCategory(notes, category: selectedCategory)
            }
            
            // Apply tag filter
            if !selectedTags.isEmpty {
                notes = await searchService.filterByTags(notes, tags: selectedTags)
            }
            
            // Apply enhanced search
            if !searchText.isEmpty {
                let searchResults = await searchService.search(notes: notes, query: searchText)
                notes = searchResults.map { $0.note }
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    filteredNotesResult = notes
                }
            }
        }
    }
    
    private func deleteNote(_ note: Note) async {
        await viewModel.deleteNote(note)
        noteToDelete = nil
        #if os(iOS)
        HapticFeedback.success()
        #endif
    }
    
    private var hasFilters: Bool {
        showFilters && (hasCategories || hasTags)
    }
    
    private var hasActiveFilters: Bool {
        selectedCategory != nil || !selectedTags.isEmpty
    }
    
    private var hasCategories: Bool {
        !uniqueCategories.isEmpty
    }
    
    private var uniqueCategories: [String] {
        Array(Set(viewModel.notes.compactMap { $0.category })).sorted()
    }
    
    private var hasTags: Bool {
        !allTags.isEmpty
    }
    
    private var allTags: [String] {
        Array(Set(viewModel.notes.flatMap { $0.tags })).sorted()
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Notes")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("\(filteredNotes.count) \(filteredNotes.count == 1 ? "note" : "notes")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }
    
    private var categoryFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("Categories")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    CategoryFilterChip(
                        title: "All",
                        isSelected: selectedCategory == nil
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = nil
                        }
                        #if os(iOS)
                        HapticFeedback.selection()
                        #endif
                    }
                    
                    ForEach(uniqueCategories, id: \.self) { category in
                        CategoryFilterChip(
                            title: category,
                            isSelected: selectedCategory == category
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = selectedCategory == category ? nil : category
                            }
                            #if os(iOS)
                            HapticFeedback.selection()
                            #endif
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .opacity(0.6)
        )
    }
    
    private var tagFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .font(.caption)
                    .foregroundColor(.purple)
                Text("Tags")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if !selectedTags.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTags.removeAll()
                            }
                            #if os(iOS)
                            HapticFeedback.selection()
                            #endif
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear All")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }
                    
                    ForEach(allTags, id: \.self) { tag in
                        TagFilterChip(
                            tag: tag,
                            isSelected: selectedTags.contains(tag)
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }
                            #if os(iOS)
                            HapticFeedback.selection()
                            #endif
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .opacity(0.6)
        )
    }
    
    private var notesGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 20
        ) {
            ForEach(Array(filteredNotes.enumerated()), id: \.element.id) { index, note in
                NotesCardView(note: note) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedNote = note
                    }
                    #if os(iOS)
                    HapticFeedback.selection()
                    #endif
                }
                .animatedCard(index: index)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        noteToDelete = note
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }
    
    private var notesCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(filteredNotes.enumerated()), id: \.element.id) { index, note in
                    NotesCardView(note: note) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedNote = note
                        }
                        #if os(iOS)
                        HapticFeedback.selection()
                        #endif
                    }
                    .frame(width: 320)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            noteToDelete = note
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

enum LayoutStyle: String, Codable {
    case grid
    case carousel
}

struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                colors: [Color(.systemGray5), Color(.systemGray5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .clipShape(Capsule())
                .shadow(
                    color: isSelected ? Color.blue.opacity(0.3) : Color.clear,
                    radius: isSelected ? 6 : 0,
                    x: 0,
                    y: isSelected ? 3 : 0
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

@MainActor
class HomeViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = false
    @Published var isSyncing = false  // Separate flag for actual sync operations
    @Published var showAddURLSheet = false
    @Published var errorMessage: String?
    
    private let noteRepository = NoteRepository.shared
    private var notificationObserver: NSObjectProtocol?
    
    init() {
        // Subscribe to notes change notifications
        setupNotificationObserver()
    }
    
    deinit {
        // Clean up notification observer
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NoteRepository.notesDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Automatically reload notes when they change (silently, no loading indicator)
            Task {
                await self?.loadNotes()
            }
        }
    }
    
    func loadNotes() async {
        // Don't show loading indicator for quick note loads
        notes = await noteRepository.fetchAll()
    }
    
    func refresh() async {
        await loadNotes()
        // Pull will check if GitHub is configured - no need to check here
        // Use try? to silently handle errors (not configured is expected)
        try? await RepositoryManager.shared.pull()
        await loadNotes()
    }
    
    func sync() async {
        isSyncing = true
        defer { isSyncing = false }
        await RepositoryManager.shared.sync()
        await loadNotes()
    }
    
    func push() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await RepositoryManager.shared.push()
            await loadNotes()
            #if os(iOS)
            HapticFeedback.success()
            #endif
        } catch {
            errorMessage = "Push failed: \(error.localizedDescription)"
            #if os(iOS)
            HapticFeedback.error()
            #endif
        }
    }
    
    func pull() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await RepositoryManager.shared.pull()
            await loadNotes()
            #if os(iOS)
            HapticFeedback.success()
            #endif
        } catch {
            errorMessage = "Pull failed: \(error.localizedDescription)"
            #if os(iOS)
            HapticFeedback.error()
            #endif
        }
    }
    
    func deleteNote(_ note: Note) async {
        // Delete from repository (triggers notification which updates UI)
        await noteRepository.delete(note)
    }
    
    func analyzeURL(_ urlString: String) async {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Invalid URL. Please enter a valid URL."
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let contentExtractor = URLContentExtractor.shared
            // Use enhanced extraction with metadata
            let result = try await contentExtractor.extractContentWithMetadata(from: url)
            let content = result.content
            let metadata = result.metadata
            
            // Try to analyze with LLM using metadata
            let llmManager = LLMManager.shared
            let analysis: NoteAnalysis
            
            if llmManager.isModelLoaded {
                do {
                    analysis = try await llmManager.analyzeContent(content, metadata: metadata)
                } catch {
                    // Fallback if LLM fails
                    analysis = createFallbackAnalysis(from: content, url: url, metadata: metadata)
                }
            } else {
                analysis = createFallbackAnalysis(from: content, url: url, metadata: metadata)
            }
            
            // Create note
            let note = Note(
                title: analysis.title,
                summary: analysis.summary,
                content: content,
                url: url,
                tags: analysis.tags,
                category: analysis.category,
                syncStatus: .pending
            )
            
            // Store analysis for ReviewNoteView
            await MainActor.run {
                self.pendingNoteToReview = note
                self.pendingNoteAnalysis = analysis
                self.showAddURLSheet = false
            }
        } catch {
            errorMessage = "Failed to analyze URL: \(error.localizedDescription)"
        }
    }
    
    @Published var pendingNoteToReview: Note?
    @Published var pendingNoteAnalysis: NoteAnalysis?
    
    private func createFallbackAnalysis(from content: String, url: URL, metadata: ContentMetadata?) -> NoteAnalysis {
        // Use metadata if available for better fallback
        let title: String
        if let ogTitle = metadata?.openGraphTitle {
            title = ogTitle
        } else if let pageTitle = metadata?.pageTitle {
            title = pageTitle
        } else {
            title = url.host ?? "Untitled"
        }
        
        let summary: String
        if let ogDesc = metadata?.openGraphDescription {
            summary = ogDesc
        } else if let metaDesc = metadata?.metaDescription {
            summary = metaDesc
        } else {
            summary = String(content.prefix(200))
        }
        
        var tags = metadata?.keywords ?? []
        tags.append(contentsOf: extractBasicTags(from: content, url: url))

        return NoteAnalysis(
            title: title,
            summary: summary,
            tags: Array(Set(tags)).prefix(5).map { $0 },
            category: extractBasicCategory(from: content, url: url, metadata: metadata),
            whatIsIt: metadata?.openGraphDescription ?? metadata?.metaDescription ?? "Content extracted from \(url.host ?? "URL")",
            whyAdvantageous: "Reference material for future use"
        )
    }
    
    private func extractBasicCategory(from content: String, url: URL, metadata: ContentMetadata?) -> String? {
        // Use OpenGraph type if available
        if let ogType = metadata?.openGraphType {
            switch ogType.lowercased() {
            case "article", "article:article":
                return "Article"
            default:
                break
            }
        }
        
        // Fallback to domain/content-based detection
        if let host = url.host {
            if host.contains("arxiv") {
                return "Research Paper"
            } else if host.contains("github") {
                return "Code Repository"
            }
        }
        
        let lowercased = content.lowercased()
        if lowercased.contains("tutorial") || lowercased.contains("guide") {
            return "Tutorial"
        }
        
        return "General"
    }
    
    private func extractBasicTags(from content: String, url: URL) -> [String] {
        var tags: [String] = []
        
        if let host = url.host {
            if host.contains("arxiv") {
                tags.append("paper")
                tags.append("research")
            } else if host.contains("github") {
                tags.append("github")
                tags.append("code")
            } else if host.contains("news") || host.contains("article") {
                tags.append("news")
            }
        }
        
        return tags
    }
    
    private func extractBasicCategory(from content: String, url: URL) -> String? {
        let lowercased = content.lowercased()
        if let host = url.host {
            if host.contains("arxiv") {
                return "Research Paper"
            } else if host.contains("github") {
                return "Code Repository"
            }
        }
        if lowercased.contains("tutorial") || lowercased.contains("guide") {
            return "Tutorial"
        }
        return "General"
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                ZStack {
                    // Animated gradient background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.15),
                                    Color.purple.opacity(0.1),
                                    Color.blue.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.2),
                                    Color.purple.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 12) {
                    Text("Start Your Collection")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Add your first note to begin organizing your knowledge")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                VStack(spacing: 20) {
                    HStack(spacing: 24) {
                        FeatureIcon(icon: "safari", text: "Share from Safari", color: .blue)
                        FeatureIcon(icon: "link", text: "Add URLs", color: .green)
                    }
                    
                    HStack(spacing: 24) {
                        FeatureIcon(icon: "sparkles", text: "AI Analysis", color: .purple)
                        FeatureIcon(icon: "arrow.triangle.2.circlepath", text: "GitHub Sync", color: .orange)
                    }
                }
                .padding(.top, 16)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}

struct FeatureIcon: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 110)
    }
}

