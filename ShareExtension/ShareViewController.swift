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
        // Simplified: Just extract URL and open main app immediately
        // The main app will handle all LLM analysis with full intelligence
        guard let url = url else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        
        // Show a brief loading view while the app opens
        let quickView = QuickShareView(url: url, autoConfirm: true) {
            // Save URL and open app immediately
            Task {
                await self.saveURLToProcess(url: url)
            }
        } onCancel: {
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
        // Save URL to shared UserDefaults - main app will process it
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.piotrlaczkowski.NotesApp") else {
            print("Warning: App Group UserDefaults not available")
            await MainActor.run {
                extensionContext?.completeRequest(returningItems: nil)
            }
            return
        }
        
        // Save the URL string for the main app to process
        await MainActor.run {
            sharedDefaults.set(url.absoluteString, forKey: "pendingURLToAnalyze")
            sharedDefaults.synchronize()
            
            // Post notification to wake up the main app
            NotificationCenter.default.post(name: NSNotification.Name("NewURLShared"), object: nil)
            
            // Open the main app using URL scheme - this must happen on main thread
            // Use a simpler URL scheme format that's more reliable
            // First, try opening with the full URL
            let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            var appURL: URL?
            
            // Try simple format first (more reliable)
            if let simpleURL = URL(string: "notesapp://open?url=\(encodedURL)") {
                appURL = simpleURL
            } else if let processURL = URL(string: "notesapp://process?url=\(encodedURL)") {
                appURL = processURL
            }
            
            if let appURL = appURL, let context = self.extensionContext {
                // Use extensionContext to open URL - this should switch to the main app
                print("Extension: Opening app with URL: \(appURL.absoluteString)")
                
                // CRITICAL: Don't complete the extension immediately
                // iOS needs the extension to stay alive for the app switch to work
                // Open the URL and wait a moment before completing
                context.open(appURL) { [weak self] success in
                    print("Extension: Open result - success: \(success)")
                    
                    if success {
                        // App opened successfully - wait longer to ensure switch completes
                        // The extension sheet will be dismissed automatically when app opens
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            print("Extension: Completing extension request after successful open")
                            self?.extensionContext?.completeRequest(returningItems: nil)
                        }
                    } else {
                        // Open failed - complete quickly
                        print("Extension: Failed to open app, completing anyway")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.extensionContext?.completeRequest(returningItems: nil)
                        }
                    }
                }
            } else {
                // Fallback: just complete and rely on notification/app activation
                print("Extension: Could not construct app URL, using fallback")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
            }
        }
    }
}

// Simplified view that shows loading state while app opens
struct QuickShareView: View {
    let url: URL
    let autoConfirm: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var isOpening = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Loading indicator
                if isOpening {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding(.bottom, 8)
                } else {
                    // Icon
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.bottom, 8)
                }
                
                // Title
                Text(isOpening ? "Opening NotesApp..." : "Share to Notes")
                    .font(.title2)
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
                
                // Description
                VStack(spacing: 8) {
                    Text(isOpening ? "Switching to NotesApp..." : "This will open NotesApp")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("to analyze the content with AI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action Button (hidden if auto-opening)
                if !autoConfirm {
                    Button {
                        #if os(iOS)
                        HapticFeedback.success()
                        #endif
                        isOpening = true
                        onConfirm()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                            Text("Continue in NotesApp")
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
            }
            .navigationTitle("Share to Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !autoConfirm {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            #if os(iOS)
                            HapticFeedback.selection()
                            #endif
                            onCancel()
                        }
                    }
                }
            }
            .onAppear {
                if autoConfirm {
                    // Auto-confirm immediately to open app right away
                    isOpening = true
                    // Use minimal delay just to show loading state briefly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onConfirm()
                    }
                }
            }
        }
    }
}


