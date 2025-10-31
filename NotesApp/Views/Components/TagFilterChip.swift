import SwiftUI

struct TagFilterChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(tag)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

