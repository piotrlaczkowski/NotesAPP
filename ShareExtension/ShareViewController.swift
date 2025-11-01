import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupShareView()
    }
    
    private func setupShareView() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            presentShareNoteView(url: nil)
            return
        }
        
        // Extract URL from extension item - try multiple methods
        if let itemProviders = extensionItem.attachments {
            var urlFound = false
            
            // Method 1: Direct URL type
            for provider in itemProviders {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
                        guard let self = self else { return }
                        if let urlItem = item as? URL {
                            DispatchQueue.main.async {
                                self.presentShareNoteView(url: urlItem)
                            }
                            return
                        }
                        // If URL type failed, try as string
                        if let urlString = item as? String, let url = URL(string: urlString) {
                            DispatchQueue.main.async {
                                self.presentShareNoteView(url: url)
                            }
                            return
                        }
                    }
                    urlFound = true
                    break
                }
            }
            
            // Method 2: Text that might be a URL
            if !urlFound {
                for provider in itemProviders {
                    if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] item, error in
                            guard let self = self else { return }
                            if let textItem = item as? String {
                                // Check if text is a URL
                                if let url = URL(string: textItem.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                    DispatchQueue.main.async {
                                        self.presentShareNoteView(url: url)
                                    }
                                    return
                                }
                            }
                        }
                        break
                    }
                }
            }
            
            // Method 3: Property list (for web pages)
            for provider in itemProviders {
                if provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier, options: nil) { [weak self] item, error in
                        guard let self = self else { return }
                        if let dictionary = item as? [String: Any] {
                            var urlString: String?
                            // Try direct URL key
                            if let url = dictionary["URL"] as? String {
                                urlString = url
                            }
                            // Try JavaScript preprocessing results
                            else if let jsResults = dictionary["NSExtensionJavaScriptPreprocessingResultsKey"] as? [String: Any],
                                    let url = jsResults["URL"] as? String {
                                urlString = url
                            }
                            
                            if let urlString = urlString, let url = URL(string: urlString) {
                                DispatchQueue.main.async {
                                    self.presentShareNoteView(url: url)
                                }
                                return
                            }
                        }
                    }
                    break
                }
            }
        } else {
            // No attachments found
            presentShareNoteView(url: nil)
        }
    }
    
    private func presentShareNoteView(url: URL?) {
        let shareView = ShareNoteView(url: url) { note in
            // Save note and dismiss
            Task {
                await self.saveNote(note)
                DispatchQueue.main.async {
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
            }
        } onCancel: {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
        
        let hostingController = UIHostingController(rootView: shareView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.didMove(toParent: self)
    }
    
    private func saveNote(_ note: Note) async {
        // Save to shared UserDefaults - this will be processed by the main app
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.piotrlaczkowski.NotesApp") else {
            // App Group not configured - log and continue
            print("Warning: App Group UserDefaults not available")
            return
        }
        
        // Access UserDefaults on main thread for thread safety
        await MainActor.run {
            if let noteData = try? JSONEncoder().encode(note) {
                sharedDefaults.set(noteData, forKey: "pendingNote")
                // synchronize() is deprecated and not needed on modern iOS/macOS
                // The system automatically syncs when needed
            }
            
            NotificationCenter.default.post(name: NSNotification.Name("NewNoteShared"), object: nil)
        }
    }
}

struct ShareNoteView: View {
    let url: URL?
    let onSave: (Note) -> Void
    let onCancel: () -> Void
    
    @StateObject private var viewModel = ShareNoteViewModel()
    @State private var selectedTags: [String] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isAnalyzing {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Analyzing content...")
                            .padding()
                    }
                } else if let analysis = viewModel.analysis {
                    Form {
                        Section("Analysis Results") {
                            TextField("Title", text: Binding(
                                get: { viewModel.note?.title ?? "" },
                                set: { viewModel.note?.title = $0 }
                            ))
                            
                            TextEditor(text: Binding(
                                get: { viewModel.note?.summary ?? "" },
                                set: { viewModel.note?.summary = $0 }
                            ))
                            .frame(height: 80)
                            
                            TagEditorView(tags: $selectedTags)
                        }
                        
                        Button("Save to Notes") {
                            if var note = viewModel.note {
                                note.tags = selectedTags
                                onSave(note)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Text("Loading...")
                }
            }
            .navigationTitle("Share to Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .task {
            if let url = url {
                await viewModel.analyze(url: url)
                if let analysis = viewModel.analysis {
                    selectedTags = analysis.tags
                }
            }
        }
    }
}

@MainActor
class ShareNoteViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysis: NoteAnalysis?
    @Published var note: Note?
    @Published var errorMessage: String?
    
    private let contentExtractor = URLContentExtractor.shared
    
    func analyze(url: URL) async {
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        
        do {
            // Extract content
            let content = try await contentExtractor.extractContent(from: url)
            
            // Get LLM service (if available)
            // In extension, we might need to use a shared service or direct service
            let llmService = MLCLLMService()
            
            // Check if model is loaded
            if !llmService.isModelLoaded {
                // For extension, use fallback analysis
                let fallbackAnalysis = createFallbackAnalysis(from: content, url: url)
                self.analysis = fallbackAnalysis
                self.note = Note(
                    title: fallbackAnalysis.title,
                    summary: fallbackAnalysis.summary,
                    content: content,
                    url: url,
                    tags: fallbackAnalysis.tags,
                    category: fallbackAnalysis.category,
                    syncStatus: .pending
                )
            } else {
                // Analyze with LLM
                let analysis = try await llmService.analyzeContent(content: content)
                self.analysis = analysis
                
                // Create note
                self.note = Note(
                    title: analysis.title,
                    summary: analysis.summary,
                    content: content,
                    url: url,
                    tags: analysis.tags,
                    category: analysis.category,
                    syncStatus: .pending
                )
            }
        } catch {
            errorMessage = "Failed to analyze content: \(error.localizedDescription)"
            // Create note with fallback
            let fallbackNote = createFallbackNote(url: url)
            self.note = fallbackNote
            self.analysis = NoteAnalysis(
                title: fallbackNote.title,
                summary: fallbackNote.summary,
                tags: fallbackNote.tags,
                category: fallbackNote.category,
                whatIsIt: "Content from \(url.host ?? "URL")",
                whyAdvantageous: "Reference material"
            )
        }
    }
    
    private func createFallbackAnalysis(from content: String, url: URL) -> NoteAnalysis {
        let title = ContentParser.extractTitle(from: content) ?? url.host ?? "Untitled"
        let summary = String(content.prefix(200))
        let tags = extractKeywords(from: content)
        let category: String?
        if url.host?.contains("arxiv") == true {
            category = "Research Paper"
        } else if url.host?.contains("github") == true {
            category = "Code Repository"
        } else {
            category = "General"
        }
        
        return NoteAnalysis(
            title: title,
            summary: summary,
            tags: tags,
            category: category,
            whatIsIt: "Content extracted from \(url.host ?? "URL")",
            whyAdvantageous: "Reference material for future use"
        )
    }
    
    private func createFallbackNote(url: URL) -> Note {
        Note(
            title: url.host ?? "Untitled",
            summary: "Content from \(url.absoluteString)",
            content: "",
            url: url,
            tags: [],
            syncStatus: .pending
        )
    }
    
    private func extractKeywords(from content: String) -> [String] {
        // Simple keyword extraction
        let keywords = ["AI", "Research", "Technology", "Science", "Programming"]
        return Array(keywords.prefix(3))
    }
}

