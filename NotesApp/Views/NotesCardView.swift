import SwiftUI

struct NotesCardView: View {
    let note: Note
    let onTap: () -> Void
    
    var body: some View {
        let buttonContent = VStack(alignment: .leading, spacing: 16) {
                // Header with category and sync status
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let category = note.category {
                            CategoryBadge(category: category)
                        }
                        
                        Text(note.title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
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
                    .fixedSize(horizontal: false, vertical: true)
                
                // Tags
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(note.tags.prefix(4), id: \.self) { tag in
                                TagView(text: tag)
                            }
                            if note.tags.count > 4 {
                                Text("+\(note.tags.count - 4)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                
                // Footer with URL and date
                HStack(alignment: .center) {
                    if let url = note.url {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.caption2)
                                .foregroundColor(.blue.opacity(0.8))
                            Text(url.host ?? "URL")
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                        Text(note.dateCreated, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(cardPadding)
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.systemBackground,
                                Color.systemBackground.opacity(0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
                    .shadow(color: Color.blue.opacity(0.04), radius: 12, x: 0, y: 4)
            )
            .overlay(
                // Category color stripe on the left edge
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(categoryStripeColor)
                        .frame(width: 4)
                    
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.12),
                                Color.purple.opacity(0.06),
                                Color.blue.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        
        #if os(macOS)
        return Button {
            onTap()
        } label: {
            buttonContent
        }
        .buttonStyle(CardButtonStyle())
        #else
        return Button(action: onTap) {
            buttonContent
        }
        .buttonStyle(CardButtonStyle())
        #endif
    }
    
    private var cardPadding: CGFloat {
        #if os(macOS)
        return 24
        #else
        return 20
        #endif
    }
    
    private var cardCornerRadius: CGFloat {
        #if os(macOS)
        return 16
        #else
        return 24
        #endif
    }
    
    private var categoryStripeColor: Color {
        guard let category = note.category else {
            return Color.clear
        }
        
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

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
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
