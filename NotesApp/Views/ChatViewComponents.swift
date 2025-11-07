import SwiftUI

// MARK: - Animated Background
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.systemBackground,
                Color.systemBackground.opacity(0.98),
                Color.blue.opacity(0.03),
                Color.purple.opacity(0.02),
                Color.systemBackground
            ]),
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .animation(
            Animation.easeInOut(duration: 8)
                .repeatForever(autoreverses: true),
            value: animateGradient
        )
        .onAppear {
            animateGradient = true
        }
    }
}

// MARK: - Empty State
struct EmptyChatStateView: View {
    let isModelLoaded: Bool
    @State private var bounce = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(bounce ? 1.05 : 1.0)
                    .animation(
                        .spring(response: 2.0, dampingFraction: 0.6)
                        .repeatForever(autoreverses: true),
                        value: bounce
                    )
            }
            .onAppear {
                bounce = true
            }
            
            VStack(spacing: 12) {
                Text("Chat with Your Notes")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                
                Text("Ask questions about your notes and get AI-powered answers based on your saved content.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if !isModelLoaded {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LLM model not loaded")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Download a model in Settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            } else {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Model ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.top, 100)
    }
}

// MARK: - Typing Indicator
struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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
            
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.3 : 1.0)
                        .opacity(animationPhase == index ? 1.0 : 0.6)
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
            
            Spacer()
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
    }
}

// MARK: - Enhanced Input View
struct EnhancedInputView: View {
    @Binding var messageText: String
    var isTextFieldFocused: FocusState<Bool>.Binding
    let isGenerating: Bool
    let isModelLoaded: Bool
    let onSend: () -> Void
    
    @State private var characterCount = 0
    private let maxCharacters = 1000
    
    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isGenerating &&
        characterCount <= maxCharacters
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Character count (only show when approaching limit)
            if characterCount > maxCharacters * 7 / 10 {
                HStack {
                    Spacer()
                    Text("\(characterCount) / \(maxCharacters)")
                        .font(.caption2)
                        .foregroundColor(characterCount > maxCharacters ? .red : .secondary)
                }
                .padding(.horizontal, 4)
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                // Text input
                ZStack(alignment: .leading) {
                    if messageText.isEmpty {
                        Text("Ask about your notes...")
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 4)
                    }
                    
                    TextField("", text: $messageText, axis: .vertical)
                        .focused(isTextFieldFocused)
                        .lineLimit(1...6)
                        #if os(iOS)
                        .textInputAutocapitalization(.sentences)
                        #endif
                        .autocorrectionDisabled(false)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 24)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    isTextFieldFocused.wrappedValue ?
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ) :
                                        LinearGradient(
                                            colors: [Color.clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                    lineWidth: isTextFieldFocused.wrappedValue ? 2 : 0
                                )
                        )
                        .animation(.spring(response: 0.3), value: isTextFieldFocused.wrappedValue)
                        .onChange(of: messageText) { _, newValue in
                            characterCount = newValue.count
                        }
                        .onSubmit {
                            if canSend {
                                onSend()
                            }
                        }
                }
                
                // Send button
                Button {
                    if canSend {
                        onSend()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                canSend ?
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(
                                color: canSend ? Color.blue.opacity(0.4) : Color.clear,
                                radius: canSend ? 8 : 0,
                                x: 0,
                                y: canSend ? 4 : 0
                            )
                        
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(!canSend)
                .scaleEffect(canSend ? 1.0 : 0.9)
                .animation(.spring(response: 0.3), value: canSend)
            }
        }
    }
}

