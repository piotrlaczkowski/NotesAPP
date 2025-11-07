import SwiftUI

// Import components
// Components are now in ChatViewComponents.swift

struct ChatMessage: Identifiable {
    let id = UUID()
    var content: String
    let isUser: Bool
    let timestamp: Date
    var sources: [Note] = []
    var isStreaming: Bool = false
}

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var inputHeight: CGFloat = 44
    @State private var selectedNote: Note?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                AnimatedGradientBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Messages list
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                if viewModel.messages.isEmpty {
                                    // Enhanced empty state
                                    EmptyChatStateView(isModelLoaded: viewModel.isModelLoaded)
                                        .transition(.opacity.combined(with: .scale))
                                        .id("empty-state")
                                }
                                
                                ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                    MessageBubble(message: message) { note in
                                        selectedNote = note
                                    }
                                        .id(message.id)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: message.isUser ? .trailing : .leading)
                                                .combined(with: .opacity)
                                                .combined(with: .scale(scale: 0.9)),
                                            removal: .opacity
                                        ))
                                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: message.id)
                                }
                                
                                if viewModel.isGenerating {
                                    TypingIndicatorView()
                                        .id("generating")
                                        .transition(.opacity.combined(with: .scale))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: viewModel.messages.count) { oldCount, newCount in
                            if newCount > oldCount, let lastMessage = viewModel.messages.last {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.smoothSpring) {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onChange(of: viewModel.isGenerating) { _, isGenerating in
                            if isGenerating {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.smoothSpring) {
                                        proxy.scrollTo("generating", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Enhanced input area
                    EnhancedInputView(
                        messageText: $messageText,
                        isTextFieldFocused: $isTextFieldFocused,
                        isGenerating: viewModel.isGenerating,
                        isModelLoaded: viewModel.isModelLoaded,
                        onSend: sendMessage
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        .ultraThinMaterial,
                        in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 20)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 10, y: -4)
                }
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        viewModel.clearChat()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .sheet(item: $selectedNote) { note in
                NoteDetailView(note: note)
            }
            .onAppear {
                // Refresh model status when view appears (e.g., returning from Settings)
                // Do this asynchronously to avoid blocking
                Task {
                    await viewModel.refreshModelStatus()
                }
            }
            .onChange(of: viewModel.isModelLoaded) { oldValue, newValue in
                // UI will automatically update via @Published property
                if newValue && !oldValue {
                    // Model was just loaded - could show a toast or update UI
                }
            }
        }
    }
    
    private func sendMessage() {
        let query = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        messageText = ""
        isTextFieldFocused = false
        
        Task {
            await viewModel.sendMessage(query)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let onNoteTap: ((Note) -> Void)?
    @State private var isVisible = false
    
    init(message: ChatMessage, onNoteTap: ((Note) -> Void)? = nil) {
        self.message = message
        self.onNoteTap = onNoteTap
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(message.content)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: 20,
                                bottomTrailingRadius: 4,
                                topTrailingRadius: 20
                            )
                        )
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    if !message.sources.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.caption2)
                            Text("\(message.sources.count) source\(message.sources.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.2))
                        )
                        .padding(.trailing, 8)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        Text("AI Assistant")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .bottom, spacing: 8) {
                        Text(message.content)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.primary)
                        
                        // Streaming indicator
                        if message.isStreaming {
                            Text("▊")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.blue)
                                .opacity(0.8)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true),
                                    value: message.isStreaming
                                )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        .ultraThinMaterial,
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: 4,
                            bottomLeadingRadius: 20,
                            bottomTrailingRadius: 20,
                            topTrailingRadius: 20
                        )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    
                    if !message.sources.isEmpty {
                        SourceNotesView(sources: message.sources, onNoteTap: onNoteTap)
                    }
                }
                
                Spacer(minLength: 60)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : (message.isUser ? 20 : -20))
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

struct SourceNotesView: View {
    let sources: [Note]
    @State private var isExpanded = false
    var onNoteTap: ((Note) -> Void)?
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 12) {
                ForEach(sources, id: \.id) { note in
                    SourceNoteCard(note: note) {
                        onNoteTap?(note)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("\(sources.count) source note\(sources.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 4)
        }
        .font(.caption2)
    }
}

struct SourceNoteCard: View {
    let note: Note
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Note icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Note content
                VStack(alignment: .leading, spacing: 6) {
                    // Title and category
                    VStack(alignment: .leading, spacing: 4) {
                        if let category = note.category {
                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .font(.caption2)
                                Text(category)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                        }
                        
                        Text(note.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Summary
                    if !note.summary.isEmpty {
                        Text(note.summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Tags (if any)
                    if !note.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(note.tags.prefix(3), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                                if note.tags.count > 3 {
                                    Text("+\(note.tags.count - 3)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // URL if available
                    if let url = note.url {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text(url.host ?? "Link")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundColor(.blue.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.systemGray6.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        #if os(iOS)
        .onTapGesture {
            HapticFeedback.selection()
            onTap()
        }
        #endif
    }
}

// Helper extension for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: CornerSet) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct CornerSet: OptionSet {
    let rawValue: Int
    
    static let topLeft = CornerSet(rawValue: 1 << 0)
    static let topRight = CornerSet(rawValue: 1 << 1)
    static let bottomLeft = CornerSet(rawValue: 1 << 2)
    static let bottomRight = CornerSet(rawValue: 1 << 3)
    
    static let top: CornerSet = [.topLeft, .topRight]
    static let bottom: CornerSet = [.bottomLeft, .bottomRight]
    static let left: CornerSet = [.topLeft, .bottomLeft]
    static let right: CornerSet = [.topRight, .bottomRight]
    static let all: CornerSet = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: CornerSet = .all
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0
        
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        
        if tr > 0 {
            path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr),
                            control: CGPoint(x: rect.maxX, y: rect.minY))
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        
        if br > 0 {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY),
                            control: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        
        if bl > 0 {
            path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bl),
                            control: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        
        if tl > 0 {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
            path.addQuadCurve(to: CGPoint(x: rect.minX + tl, y: rect.minY),
                            control: CGPoint(x: rect.minX, y: rect.minY))
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        
        path.closeSubpath()
        return path
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isGenerating = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var isModelLoaded = false
    
    private let ragService = RAGService.shared
    private let llmManager = LLMManager.shared
    private var modelStatusTask: Task<Void, Never>?
    
    init() {
        // Initialize model status asynchronously to avoid blocking init
        Task { @MainActor in
            await refreshModelStatus()
        }
        
        // Periodically check model status (simple polling since LLMManager doesn't publish isModelLoaded)
        // Start with a delay to avoid blocking view initialization
        modelStatusTask = Task {
            // Initial delay to let view render first
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            while !Task.isCancelled {
                await refreshModelStatus()
                try? await Task.sleep(nanoseconds: 3_000_000_000) // Check every 3 seconds (reduced frequency)
            }
        }
    }
    
    deinit {
        modelStatusTask?.cancel()
    }
    
    func refreshModelStatus() async {
        // Access LLMManager - this is a simple property read, shouldn't block
        // But we're already on MainActor, so this should be fast
        let newStatus = llmManager.isModelLoaded
        
        if newStatus != isModelLoaded {
            isModelLoaded = newStatus
        }
    }
    
    func sendMessage(_ query: String) async {
        // Add user message
        let userMessage = ChatMessage(
            content: query,
            isUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Check if model is loaded
        guard llmManager.isModelLoaded else {
            let errorMsg = ChatMessage(
                content: "Please download and load an LLM model in Settings to use the chat feature.",
                isUser: false,
                timestamp: Date()
            )
            messages.append(errorMsg)
            return
        }
        
        isGenerating = true
        errorMessage = nil
        
        // Check if RAG will be used
        let willUseRAG = await ragService.willUseRAG(for: query)
        let sourceNotes = await ragService.getSourceNotes(for: query, maxNotes: 5)
        
        // Create streaming message with unique ID
        var streamingMessage = ChatMessage(
            content: "",
            isUser: false,
            timestamp: Date(),
            sources: sourceNotes,
            isStreaming: true
        )
        // Store the ID before appending
        let streamingMessageId = streamingMessage.id
        messages.append(streamingMessage)
        
        defer {
            isGenerating = false
            // Mark streaming as complete
            if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                messages[index].isStreaming = false
            }
        }
        
        do {
            // Refresh model status before generating (async, non-blocking)
            await refreshModelStatus()
            
            // Double-check model is loaded
            guard isModelLoaded else {
                if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                    messages[index].content = "Model is not currently loaded. Please go to Settings and reload the model."
                    messages[index].isStreaming = false
                }
                return
            }
            
            // Use streaming response (actor method needs await)
            let stream = await ragService.generateResponseStream(query: query, maxNotes: 5)
            
            for try await chunk in stream {
                // Update streaming message content
                if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                    messages[index].content += chunk
                }
            }
            
            // Mark streaming complete
            if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                messages[index].isStreaming = false
            }
            
            #if os(iOS)
            HapticFeedback.success()
            #endif
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            
            // Update streaming message with error
            if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                messages[index].content = "Sorry, I encountered an error: \(error.localizedDescription)"
                messages[index].isStreaming = false
            }
            
            #if os(iOS)
            HapticFeedback.error()
            #endif
        }
    }
    
    func clearChat() {
        messages.removeAll()
    }
}

