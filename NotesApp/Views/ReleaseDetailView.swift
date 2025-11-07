import SwiftUI

struct ReleaseDetailView: View {
    let release: Release
    @State private var isEditing = false
    @State private var editedDraft: String = ""
    @State private var editedTitle: String = ""
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.systemBackground,
                    Color.systemBackground.opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: CGFloat.adaptiveSpacingL) {
                    // Header
                    headerSection
                        .adaptiveHorizontalPadding()
                        .padding(.top, CGFloat.adaptiveSpacingM)
                    
                    // Metadata
                    metadataSection
                        .adaptiveHorizontalPadding()
                    
                    // Content
                    contentSection
                        .adaptiveHorizontalPadding()
                }
                .adaptiveFrame()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Release Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !release.isApproved {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        #if os(iOS)
                        HapticFeedback.selection()
                        #endif
                        editedDraft = release.linkedInDraft
                        editedTitle = release.title
                        isEditing = true
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                ReleaseDraftEditor(draftText: $editedDraft, releaseTitle: $editedTitle)
                    .toolbar {
                        #if os(iOS)
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                isEditing = false
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                Task {
                                    await ReleaseService.shared.updateRelease(
                                        id: release.id,
                                        linkedInDraft: editedDraft,
                                        title: editedTitle
                                    )
                                    HapticFeedback.success()
                                    isEditing = false
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                        #else
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isEditing = false
                            }
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                Task {
                                    await ReleaseService.shared.updateRelease(
                                        id: release.id,
                                        linkedInDraft: editedDraft,
                                        title: editedTitle
                                    )
                                    isEditing = false
                                }
                            }
                        }
                        #endif
                    }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(release.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        
                        Text(release.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text(release.isApproved ? "Published" : "Draft")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(release.isApproved ? Color.green : Color.orange)
                        .cornerRadius(8)
                    
                    if let dateApproved = release.dateApproved {
                        Text("Approved: \(dateApproved.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                metadataCard(
                    icon: "note.text",
                    title: "Notes",
                    value: "\(release.noteIds.count)"
                )
                
                metadataCard(
                    icon: "textformat.size",
                    title: "Characters",
                    value: "\(release.linkedInDraft.count)"
                )
                
                metadataCard(
                    icon: "words",
                    title: "Words",
                    value: "\(release.linkedInDraft.split(separator: " ").count)"
                )
            }
        }
    }
    
    private func metadataCard(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Content")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !release.isApproved {
                    Text("Draft")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                MarkdownPreviewView(text: release.approvedDraft ?? release.linkedInDraft)
            }
            .padding(16)
            .background(Color.systemBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
    }
}

#Preview {
    NavigationStack {
        ReleaseDetailView(
            release: Release(
                date: Date(),
                title: "Sample Release",
                noteIds: [UUID(), UUID()],
                linkedInDraft: "This is a sample LinkedIn post about recent findings...",
                isApproved: true
            )
        )
    }
}

