import SwiftUI

struct NotesCardView: View {
    let note: Note
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with category and sync status
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let category = note.category {
                            CategoryBadge(category: category)
                        }
                        
                        Text(note.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    SyncStatusBadge(status: note.syncStatus)
                }
                
                // Summary
                Text(note.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Tags
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(note.tags.prefix(4), id: \.self) { tag in
                                TagView(text: tag)
                            }
                            if note.tags.count > 4 {
                                Text("+\(note.tags.count - 4)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                // Footer with URL and date
                HStack {
                    if let url = note.url {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text(url.host ?? "URL")
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Text(note.dateCreated, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(CardButtonStyle())
    }
}

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct CategoryBadge: View {
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
