import SwiftUI

struct TagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                    )
            )
            .foregroundColor(.accentColor)
    }
}

