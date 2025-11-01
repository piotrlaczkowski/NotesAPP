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
        
        // Handle both "open" and "process" URLs
        if url.host == "open" || url.host == "process" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let urlQuery = components?.queryItems?.first(where: { $0.name == "url" }),
               let urlString = urlQuery.value,
               let targetURL = URL(string: urlString) {
                print("NotesApp: Processing URL from scheme: \(targetURL.absoluteString)")
                // Process the URL using AppState immediately
                // This will show the ReviewNoteView sheet automatically
                await appState.processURLFromShareExtension(url: targetURL)
                print("NotesApp: URL processing completed, review view should be shown")
                return
            }
        }
        
        // Fallback: check App Group for pending URL
        print("NotesApp: Falling back to checking App Group for pending URL")
        await appState.processPendingNote()
    }
}

