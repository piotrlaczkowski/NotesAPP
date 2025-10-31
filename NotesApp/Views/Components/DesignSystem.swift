import SwiftUI

// MARK: - Colors
extension Color {
    static let appBackground = Color(light: .white, dark: .black)
    static let cardBackground = Color(light: Color(hex: "F5F5F7"), dark: Color(hex: "1C1C1E"))
    static let accent = Color.accentColor
    static let secondaryText = Color.secondary
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static func light(_ lightColor: Color, dark darkColor: Color) -> Color {
        #if os(iOS)
        return Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(darkColor) : UIColor(lightColor)
        })
        #else
        return Color(NSColor { appearance in
            appearance.name == .darkAqua ? NSColor(darkColor) : NSColor(lightColor)
        })
        #endif
    }
}

// MARK: - Typography
extension Font {
    static let appTitle = Font.system(.title, design: .rounded)
    static let appTitle2 = Font.system(.title2, design: .rounded)
    static let appHeadline = Font.system(.headline, design: .rounded)
    static let appBody = Font.system(.body, design: .default)
    static let appCaption = Font.system(.caption, design: .default)
}

// MARK: - Spacing
extension CGFloat {
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32
}

// MARK: - Corner Radius
extension CGFloat {
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 16
}

// MARK: - Shadows
extension View {
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    func elevatedShadow() -> some View {
        self.shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Animations
extension Animation {
    static let smoothSpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let bouncySpring = Animation.spring(response: 0.5, dampingFraction: 0.6)
    static let quickEase = Animation.easeInOut(duration: 0.2)
}

// MARK: - Reusable Components
struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(.radiusM)
            .cardShadow()
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appHeadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accent)
                .cornerRadius(.radiusM)
        }
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appHeadline)
                .foregroundColor(.accent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accent.opacity(0.1))
                .cornerRadius(.radiusM)
        }
    }
}

#if os(iOS)
import UIKit

extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
#else
import AppKit

extension Color {
    init(light: Color, dark: Color) {
        self.init(NSColor { appearance in
            appearance.name == .darkAqua ? NSColor(dark) : NSColor(light)
        })
    }
}
#endif

