import SwiftUI

struct NotesListView: View {
    let notes: [Note]
    let onNoteTap: (Note) -> Void
    let onRefresh: () -> Void
    let isLoading: Bool
    
    var body: some View {
        List {
            ForEach(notes) { note in
                NoteRowView(note: note)
                    .onTapGesture {
                        onNoteTap(note)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .refreshable {
            onRefresh()
        }
    }
}

struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if let category = note.category {
                        CategoryBadge(category: category)
                    }
                    
                    Text(note.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                }
                
                Spacer()
                
                SyncStatusBadge(status: note.syncStatus)
            }
            
            Text(note.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(note.tags.prefix(5), id: \.self) { tag in
                            TagView(text: tag)
                        }
                    }
                }
            }
            
            HStack {
                if let url = note.url {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text(url.host ?? "URL")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(note.dateCreated, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondarySystemBackground)
        )
    }
}

// MARK: - Supporting Views
private struct CategoryBadge: View {
    let category: String
    
    var body: some View {
        Text(category)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(categoryColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(categoryColor.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(categoryColor.opacity(0.3), lineWidth: 0.5)
                    )
            )
    }
    
    private var categoryColor: Color {
        switch category {
        case "Research Paper":
            return .purple
        case "Code Repository":
            return .blue
        case "Tutorial":
            return .green
        case "Article":
            return .orange
        case "Documentation":
            return .cyan
        case "News":
            return .red
        case "Video":
            return .pink
        case "Podcast":
            return .indigo
        case "Book":
            return .brown
        default:
            return .gray
        }
    }
}

private struct SyncStatusBadge: View {
    let status: SyncStatus
    
    var body: some View {
        Group {
            switch status {
            case .synced:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .pending:
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
            case .conflict:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.caption)
    }
}
