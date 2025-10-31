import SwiftUI

/// Custom modifier for animated card appearance
struct AnimatedCardModifier: ViewModifier {
    let index: Int
    
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
            .animation(
                .spring(response: 0.4, dampingFraction: 0.8)
                .delay(Double(index) * 0.05),
                value: index
            )
    }
}

extension View {
    func animatedCard(index: Int) -> some View {
        modifier(AnimatedCardModifier(index: index))
    }
}

