import SwiftUI

struct NoteSelectionContentView: View {
    @ObservedObject var viewModel: NoteSelectionViewModel
    let onNotesSelected: ([UUID]) -> Void
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
                
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading notes...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.displayedNotes.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: CGFloat.adaptiveSpacingM) {
                            // Header
                            headerSection
                                .adaptiveHorizontalPadding()
                                .padding(.top, CGFloat.adaptiveSpacingM)
                            
                            // Filter controls
                            filterControlsSection
                                .adaptiveHorizontalPadding()
                            
                            // Notes list
                            notesListSection
                                .adaptiveHorizontalPadding()
                        }
                        .adaptiveFrame()
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .task {
                await viewModel.loadNotes()
            }
    }
}

// MARK: - Extensions for private helpers on NoteSelectionContentView

extension NoteSelectionContentView {
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Select Notes for Release")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(viewModel.selectedNoteIds.count) of \(viewModel.displayedNotes.count) selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Quick selection buttons
            HStack(spacing: 8) {
                Button("Select All") {
                    #if os(iOS)
                    HapticFeedback.selection()
                    #endif
                    viewModel.selectedNoteIds = Set(viewModel.displayedNotes.map { $0.id })
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("Clear") {
                    #if os(iOS)
                    HapticFeedback.selection()
                    #endif
                    viewModel.selectedNoteIds.removeAll()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
    
    private var filterControlsSection: some View {
        VStack(spacing: 12) {
            Picker("Time Range", selection: $viewModel.selectedRange) {
                Text("Auto Suggest").tag(TimeRange.autoSuggest)
                Text("Last 7 Days").tag(TimeRange.sevenDays)
                Text("Last 30 Days").tag(TimeRange.thirtyDays)
                Text("Custom Range").tag(TimeRange.custom)
            }
            .onChange(of: viewModel.selectedRange) { _, newValue in
                Task {
                    await viewModel.updateDisplayedNotes(for: newValue)
                }
            }
            
            if viewModel.selectedRange == .custom {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("From")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        DatePicker("", selection: $viewModel.customStartDate, displayedComponents: .date)
                            .onChange(of: viewModel.customStartDate) { _, _ in
                                Task {
                                    await viewModel.updateDisplayedNotes(for: .custom)
                                }
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        DatePicker("", selection: $viewModel.customEndDate, displayedComponents: .date)
                            .onChange(of: viewModel.customEndDate) { _, _ in
                                Task {
                                    await viewModel.updateDisplayedNotes(for: .custom)
                                }
                            }
                    }
                }
                .padding(12)
                .background(Color.systemGray6)
                .cornerRadius(10)
            }
        }
        .padding(12)
        .background(Color.systemBackground)
        .cornerRadius(12)
    }
    
    private var notesListSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.displayedNotes, id: \.id) { note in
                NoteSelectionCard(
                    note: note,
                    isSelected: viewModel.selectedNoteIds.contains(note.id),
                    onToggle: {
                        #if os(iOS)
                        HapticFeedback.selection()
                        #endif
                        viewModel.toggleSelection(for: note.id)
                    }
                )
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "note.text")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.gray, Color.gray.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 8) {
                    Text("No Notes Found")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("There are no notes in the selected date range")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Legacy wrapper that includes NavigationStack for standalone use
struct NoteSelectionView: View {
    @StateObject private var viewModel = NoteSelectionViewModel()
    @Environment(\.dismiss) var dismiss
    var onNotesSelected: ([UUID]) -> Void
    
    var body: some View {
        NavigationStack {
            NoteSelectionContentView(viewModel: viewModel, onNotesSelected: onNotesSelected)
                .navigationTitle("Select Notes")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            HapticFeedback.success()
                            onNotesSelected(Array(viewModel.selectedNoteIds))
                            dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Done")
                            }
                        }
                        .disabled(viewModel.selectedNoteIds.isEmpty)
                        .buttonStyle(.borderless)
                    }
                    #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: {
                            onNotesSelected(Array(viewModel.selectedNoteIds))
                            dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Done")
                            }
                        }
                        .disabled(viewModel.selectedNoteIds.isEmpty)
                    }
                    #endif
                }
        }
    }
}

// MARK: - Card View for Note Selection

struct NoteSelectionCard: View {
    let note: Note
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.5))
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(note.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let category = note.category {
                            Label(category, systemImage: "tag")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        
                        Label(note.dateCreated.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.systemBackground)
                    .stroke(
                        isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Time Range Enum

enum TimeRange: String, CaseIterable, Identifiable {
    case autoSuggest = "Auto Suggest"
    case sevenDays = "Last 7 Days"
    case thirtyDays = "Last 30 Days"
    case custom = "Custom Range"
    
    var id: String { self.rawValue }
}

// MARK: - Note Selection View Model

@MainActor
class NoteSelectionViewModel: ObservableObject {
    @Published var displayedNotes: [Note] = []
    @Published var selectedNoteIds: Set<UUID> = []
    @Published var selectedRange: TimeRange = .autoSuggest
    @Published var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    @Published var customEndDate: Date = Date()
    @Published var isLoading = false
    
    private let releaseService = ReleaseService.shared
    
    func loadNotes() async {
        isLoading = true
        defer { isLoading = false }
        
        await updateDisplayedNotes(for: selectedRange)
    }
    
    func updateDisplayedNotes(for range: TimeRange) async {
        let notes: [Note]
        
        switch range {
        case .autoSuggest:
            notes = await releaseService.getNotesForAutoSuggestion()
        case .sevenDays:
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            notes = await releaseService.getNotesByDateRange(from: startDate, to: Date())
        case .thirtyDays:
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            notes = await releaseService.getNotesByDateRange(from: startDate, to: Date())
        case .custom:
            notes = await releaseService.getNotesByDateRange(from: customStartDate, to: customEndDate)
        }
        
        displayedNotes = notes.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    func toggleSelection(for noteId: UUID) {
        if selectedNoteIds.contains(noteId) {
            selectedNoteIds.remove(noteId)
        } else {
            selectedNoteIds.insert(noteId)
        }
    }
}

#Preview {
    NoteSelectionView(onNotesSelected: { _ in })
        .environmentObject(ReleaseService.shared)
}

