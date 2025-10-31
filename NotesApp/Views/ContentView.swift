import SwiftUI

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
                ReviewNoteView(note: note, analysis: NoteAnalysis(
                    title: note.title,
                    summary: note.summary,
                    tags: note.tags,
                    category: note.category,
                    whatIsIt: nil,
                    whyAdvantageous: nil
                ))
            }
        }
        .onAppear {
            setupNotificationObserver()
        }
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
    }
}

