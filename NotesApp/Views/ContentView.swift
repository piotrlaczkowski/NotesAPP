import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) var scenePhase
    @State private var selectedTab = 0
    @State private var lastPendingNoteCheck = Date.distantPast
    
    var body: some View {
        #if os(macOS)
        // macOS: Use NavigationSplitView with sidebar for better UX
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("Notes", systemImage: "note.text")
                    .tag(0)
                Label("Releases", systemImage: "sparkles")
                    .tag(1)
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
                    .tag(2)
                Label("Settings", systemImage: "gearshape")
                    .tag(3)
            }
            .frame(minWidth: 200)
            .navigationTitle("NotesApp")
        } detail: {
            Group {
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    ReleaseView()
                case 2:
                    ChatView()
                case 3:
                    SettingsView()
                default:
                    HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(item: $appState.pendingNoteToReview) { note in
            #if os(macOS)
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
            .onDisappear {
                appState.pendingNoteAnalysis = nil
            }
            #else
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
                appState.pendingNoteAnalysis = nil
            }
            #endif
        }
        .onAppear {
            setupNotificationObserver()
            Task {
                checkPendingNoteWithDebounce()
            }
        }
        #else
        // iOS: Use TabView - ensure it fills the entire screen
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(0)
            
            ReleaseView()
                .tabItem {
                    Label("Releases", systemImage: "sparkles")
                }
                .tag(1)
            
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .sheet(item: $appState.pendingNoteToReview) { note in
            #if os(macOS)
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
            .onDisappear {
                // Clear analysis when sheet dismisses
                appState.pendingNoteAnalysis = nil
            }
            #else
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
            #endif
        }
        .onAppear {
            setupNotificationObserver()
            // Check for pending URLs when app becomes active (with debounce)
            // Use Task to avoid blocking UI
            Task {
                checkPendingNoteWithDebounce()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // When scene becomes active, check for pending URLs
            if newPhase == .active {
                // Switch to Home tab to show the note creation
                selectedTab = 0
                // Use Task to avoid blocking UI
                Task {
                    checkPendingNoteWithDebounce()
                }
            }
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // When app becomes active, check for pending URLs from Share Extension
            // Use Task to avoid blocking UI
            Task {
                checkPendingNoteWithDebounce()
            }
        }
        #endif
        #endif
    }
    
    private func checkPendingNoteWithDebounce() {
        let now = Date()
        // Debounce: only check if at least 0.5 seconds have passed since last check
        guard now.timeIntervalSince(lastPendingNoteCheck) > 0.5 else {
            return
        }
        lastPendingNoteCheck = now
        
        Task { @MainActor in
            await appState.processPendingNote()
        }
    }
    
    private func setupNotificationObserver() {
        // Since ContentView is a struct (value type), we capture appState reference
        let appStateRef = appState
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NewNoteShared"),
            object: nil,
            queue: .main
        ) { _ in
            // Use debounced check to avoid multiple simultaneous calls
            // Note: Since ContentView is a struct, we need to access appState directly
            // The debounce is handled by AppState itself, so this is safe
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
            // Use debounced check to avoid multiple simultaneous calls
            Task { @MainActor in
                await appStateRef.processPendingNote()
            }
        }
    }
}

