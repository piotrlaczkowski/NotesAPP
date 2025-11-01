import SwiftUI

@main
struct NotesApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // Suppress harmless macOS system warnings
        // Note: LogSuppression is a utility class for future log filtering
        // Currently these warnings are harmless and expected from macOS system frameworks
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.colorScheme)
        }
    }
}

