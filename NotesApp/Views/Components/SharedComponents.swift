import SwiftUI

// MARK: - Category Badge
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

// MARK: - Sync Status Badge
struct SyncStatusBadge: View {
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
