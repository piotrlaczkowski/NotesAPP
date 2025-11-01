import Foundation

/// Suppresses harmless macOS system warnings that clutter the console
/// These warnings are normal macOS system messages and don't indicate errors
class LogSuppression {
    static func setup() {
        // Note: Most of these warnings are from macOS system frameworks
        // and cannot be directly suppressed, but they are harmless.
        // The warnings include:
        // - LSPrefs translocation warnings (normal for sandboxed apps)
        // - ViewBridge warnings (normal view lifecycle events)
        // - RTIInputSystemClient warnings (expected during text input)
        // - CFPrefsPlistSource warnings (app group preferences, normal)
        
        // These are informational system messages, not errors
        // They appear in the console but don't affect app functionality
    }
}

