import SwiftUI

struct SettingsStatusIndicator: View {
    let status: ConfigurationStatus
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status badge
            if status != .unknown {
                Text(status.label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.2))
                    .foregroundColor(status.color)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

enum ConfigurationStatus {
    case configured
    case partial
    case notConfigured
    case working
    case error
    case unknown
    
    var icon: String {
        switch self {
        case .configured, .working:
            return "checkmark.circle.fill"
        case .partial:
            return "exclamationmark.circle.fill"
        case .notConfigured:
            return "xmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .configured, .working:
            return .green
        case .partial:
            return .orange
        case .notConfigured:
            return .gray
        case .error:
            return .red
        case .unknown:
            return .secondary
        }
    }
    
    var label: String {
        switch self {
        case .configured:
            return "Configured"
        case .partial:
            return "Partial"
        case .notConfigured:
            return "Not Set"
        case .working:
            return "Active"
        case .error:
            return "Error"
        case .unknown:
            return "Unknown"
        }
    }
}

