import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(1)
        }
        .sheet(item: $appState.pendingNoteToReview) { note in
            NavigationStack {
                ReviewNoteView(
                    note: note,
                    analysis: appState.pendingNoteAnalysis ?? NoteAnalysis(
                        title: note.title,
                        summary: note.summary,
                        tags: note.tags,
                        category: note.category,
                        whatIsIt: nil,
                        whyAdvantageous: nil
                    )
                )
            }
            .onDisappear {
                // Clear analysis when sheet dismisses
                appState.pendingNoteAnalysis = nil
            }
        }
        .onAppear {
            setupNotificationObserver()
            // Check for pending URLs when app becomes active
            Task { @MainActor in
                await appState.processPendingNote()
            }
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // When app becomes active, check for pending URLs from Share Extension
            Task { @MainActor in
                await appState.processPendingNote()
            }
        }
        #endif
    }
    
    private func setupNotificationObserver() {
        // Create a strong reference to appState to use in closure
        let appStateRef = appState
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NewNoteShared"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await appStateRef.processPendingNote()
            }
        }
        
        // Also listen for URL shared from Share Extension
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NewURLShared"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await appStateRef.processPendingNote()
            }
        }
    }
}

