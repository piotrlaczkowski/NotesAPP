import SwiftUI
import Combine

struct ReleaseView: View {
    @StateObject private var viewModel = ReleaseViewModel()
    @State private var showCreateRelease = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
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
                            .scaleEffect(1.5)
                            .tint(.blue)
                        
                        Text("Loading releases...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.approvedReleases.isEmpty && viewModel.draftReleases.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: CGFloat.adaptiveSpacingL) {
                            // Header
                            headerSection
                                .adaptiveHorizontalPadding()
                                .padding(.top, CGFloat.adaptiveSpacingM)
                            
                            // Approved Releases
                            if !viewModel.approvedReleases.isEmpty {
                                releasesSection(
                                    title: "Published Releases",
                                    releases: viewModel.approvedReleases,
                                    isApproved: true
                                )
                                .adaptiveHorizontalPadding()
                            }
                            
                            // Draft Releases
                            if !viewModel.draftReleases.isEmpty {
                                releasesSection(
                                    title: "Drafts",
                                    releases: viewModel.draftReleases,
                                    isApproved: false
                                )
                                .adaptiveHorizontalPadding()
                            }
                        }
                        .adaptiveFrame()
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        #if os(iOS)
                        HapticFeedback.medium()
                        #endif
                        showCreateRelease = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            #if os(macOS)
                            Text("New Release")
                            #endif
                        }
                        .font(.title3)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .sheet(isPresented: $showCreateRelease, onDismiss: {
                // Reload releases when sheet is dismissed (after creating a release)
                Task {
                    await viewModel.loadReleases()
                }
            }) {
                NavigationStack {
                    ReleaseCreationView()
                }
            }
            .task {
                await viewModel.loadReleases()
            }
            .refreshable {
                await viewModel.loadReleases()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Releases")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Create and manage release summaries")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let lastReleaseDate = viewModel.lastReleaseDate {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Release")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(lastReleaseDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func releasesSection(title: String, releases: [Release], isApproved: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(releases.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isApproved ? Color.green : Color.orange)
                    .cornerRadius(6)
            }
            
            VStack(spacing: 12) {
                ForEach(releases, id: \.id) { release in
                    NavigationLink(destination: ReleaseDetailView(release: release)) {
                        releaseCard(release: release)
                    }
                }
            }
        }
    }
    
    private func releaseCard(release: Release) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(release.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        
                        Text(release.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(release.isApproved ? "Published" : "Draft")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(release.isApproved ? Color.green : Color.orange)
                        .cornerRadius(6)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.caption)
                        Text("\(release.noteIds.count)")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // Preview of content
            Text(release.approvedDraft ?? release.linkedInDraft)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.systemBackground)
                .stroke(
                    LinearGradient(
                        colors: [
                            release.isApproved ? Color.green.opacity(0.3) : Color.orange.opacity(0.3),
                            Color.gray.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.15),
                                    Color.blue.opacity(0.1)
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
                                    Color.purple.opacity(0.2),
                                    Color.blue.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 12) {
                    Text("Create Your First Release")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Summarize your recent discoveries into a polished release")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            Button(action: {
                #if os(iOS)
                HapticFeedback.medium()
                #endif
                showCreateRelease = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Release")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
                .font(.headline)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}

@MainActor
class ReleaseViewModel: ObservableObject {
    @Published var approvedReleases: [Release] = []
    @Published var draftReleases: [Release] = []
    @Published var lastReleaseDate: Date?
    @Published var isLoading = false
    
    private let releaseService = ReleaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe ReleaseService changes
        releaseService.$releases
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateReleases()
            }
            .store(in: &cancellables)
        
        releaseService.$lastReleaseDate
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastReleaseDate)
    }
    
    func loadReleases() async {
        isLoading = true
        defer { isLoading = false }
        
        await releaseService.loadReleases()
        updateReleases()
    }
    
    private func updateReleases() {
        let all = releaseService.releases
        approvedReleases = all.filter { $0.isApproved }
        draftReleases = all.filter { !$0.isApproved }
        lastReleaseDate = releaseService.lastReleaseDate
    }
}

#Preview {
    ReleaseView()
        .environmentObject(ReleaseService.shared)
}

