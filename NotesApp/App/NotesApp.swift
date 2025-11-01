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
                .onOpenURL { url in
                    // Handle URL scheme from Share Extension
                    if url.scheme == "notesapp" {
                        Task { @MainActor in
                            await handleURLScheme(url: url)
                        }
                    }
                }
        }
    }
    
    @MainActor
    private func handleURLScheme(url: URL) async {
        print("NotesApp: Received URL scheme: \(url.absoluteString)")
        
        // Handle "open" URL - this just wakes up the app
        // The actual URL to process is stored in App Group
        if url.host == "open" || url.host == "process" {
            // Check for query parameter first (legacy support)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let urlQuery = components?.queryItems?.first(where: { $0.name == "url" }),
               let urlString = urlQuery.value,
               let targetURL = URL(string: urlString) {
                print("NotesApp: Processing URL from scheme query: \(targetURL.absoluteString)")
                await appState.processURLFromShareExtension(url: targetURL)
                return
            }
        }
        
        // Primary mechanism: check App Group for pending URL
        // This is more reliable than URL scheme parameters
        print("NotesApp: Checking App Group for pending URL")
        await appState.processPendingNote()
    }
}

