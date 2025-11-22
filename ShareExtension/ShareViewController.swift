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
        // Simplified: Just extract URL and save it
        // The main app will handle all LLM analysis with full intelligence
        guard let url = url else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        
        // Save URL immediately
        Task {
            await self.saveURLToProcess(url: url)
        }
        
        // Show confirmation view
        let quickView = QuickShareView(url: url) {
            // User tapped "Done" - complete extension
            // They will manually switch to NotesApp where the URL is already saved
            self.extensionContext?.completeRequest(returningItems: nil)
        }
        
        let hostingController = UIHostingController(rootView: quickView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.didMove(toParent: self)
    }
    
    private func saveNote(_ note: Note) async {
        // Instead of saving a full note, we'll just save the URL
        // The main app will handle full LLM analysis using its robust system
        guard let url = note.url else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        
        await saveURLToProcess(url: url)
    }
    
    private func saveURLToProcess(url: URL) async {
        // Small delay to let system initialize cfprefsd connection
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Capture extensionContext on main actor before detached task
        let context = extensionContext
        
        // Save URL to shared UserDefaults - main app will process it
        // Initialize UserDefaults fully asynchronously to avoid blocking
        let suiteName = "group.com.piotrlaczkowski.NotesApp"
        let urlString = url.absoluteString
        
        Task.detached(priority: .userInitiated) {
            guard let sharedDefaults = UserDefaults(suiteName: suiteName) else {
                print("Warning: App Group UserDefaults not available")
                await MainActor.run {
                    context?.completeRequest(returningItems: nil)
                }
                return
            }
            
            // Save the URL string for the main app to process
            sharedDefaults.set(urlString, forKey: "pendingURLToAnalyze")
            // Don't call synchronize() - it blocks and iOS handles persistence automatically
            
            // Post notification on main thread
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("NewURLShared"), object: nil)
                
                // Try to open the app, but don't rely on it working
                // iOS security may prevent automatic switching
                if let appURL = URL(string: "notesapp://open") {
                    print("Extension: Attempting to open app with URL scheme")
                    context?.open(appURL, completionHandler: { success in
                        print("Extension: URL scheme open result: \(success)")
                    })
                }
            }
        }
    }
}

// View that clearly instructs user to switch to NotesApp
struct QuickShareView: View {
    let url: URL
    let onDone: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.green)
                    .padding(.bottom, 8)
                
                // Title
                Text("URL Saved!")
                    .font(.title)
                    .fontWeight(.bold)
                
                // URL Preview
                VStack(spacing: 12) {
                    Text("URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 8) {
                        if let host = url.host {
                            Text(host)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Text(url.absoluteString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                
                // Clear instructions
                VStack(spacing: 12) {
                    Text("Switch to NotesApp")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("The note will be created automatically")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Instruction card
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pull down from the top")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Then tap NotesApp icon")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                }
                
                Spacer()
                
                // Done button
                Button {
                    #if os(iOS)
                    HapticFeedback.success()
                    #endif
                    onDone()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.title3)
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .navigationTitle("Share to Notes")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


