import SwiftUI

struct ReleaseDraftEditor: View {
    @Binding var draftText: String
    @Binding var releaseTitle: String
    @State private var isPreviewMode = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.systemBackground,
                        Color.systemBackground.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: CGFloat.adaptiveSpacingM, pinnedViews: [.sectionHeaders]) {
                        // Title section
                        Section(header: sectionHeader("Release Title")) {
                            TextField("Enter release title", text: $releaseTitle)
                                .font(.headline)
                                .padding(12)
                                .background(Color.systemGray6)
                                .cornerRadius(10)
                        }
                        .adaptiveHorizontalPadding()
                        
                        // Mode toggle
                        Section(header: sectionHeader("Content")) {
                            segmentedControl
                        }
                        .adaptiveHorizontalPadding()
                        
                        // Editor or Preview
                        if isPreviewMode {
                            previewSection
                        } else {
                            editorSection
                        }
                        
                        // Character count
                        characterCountSection
                            .adaptiveHorizontalPadding()
                    }
                    .adaptiveFrame()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CGFloat.adaptiveSpacingM)
                }
            }
            .navigationTitle("Edit Draft")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
    
    private var segmentedControl: some View {
        Picker("Mode", selection: $isPreviewMode) {
            Text("Edit").tag(false)
            Text("Preview").tag(true)
        }
        .pickerStyle(.segmented)
    }
    
    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading) {
                #if os(iOS)
                TextEditor(text: $draftText)
                    .font(.body)
                    .frame(minHeight: 250, idealHeight: 350)
                    .padding(12)
                    .background(Color.systemBackground)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                #else
                TextEditor(text: $draftText)
                    .font(.body)
                    .frame(minHeight: 400)
                    .padding(12)
                    .background(Color.systemBackground)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                #endif
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Formatting Tips")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    formattingTip("**bold text**", result: "bold text")
                    formattingTip("*italic text*", result: "italic text")
                    formattingTip("[link text](url)", result: "link text")
                    formattingTip("- List item", result: "• List item")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
        .adaptiveHorizontalPadding()
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MarkdownPreviewView(text: draftText)
                        .frame(minHeight: 300)
                }
                .padding(16)
                .background(Color.systemBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .frame(maxHeight: 400)
        }
        .adaptiveHorizontalPadding()
    }
    
    private var characterCountSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(draftText.count)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Words")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(draftText.split(separator: " ").count)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Lines")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(draftText.split(separator: "\n").count)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            if draftText.count > 3000 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Good length")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(Color.systemGray6)
        .cornerRadius(10)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
    
    private func formattingTip(_ markdown: String, result: String) -> some View {
        HStack(spacing: 8) {
            Text(markdown)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.blue)
            
            Text("→")
                .foregroundColor(.secondary)
            
            Text(result)
                .foregroundColor(.primary)
        }
    }
}

/// Simple markdown preview view
struct MarkdownPreviewView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(text.split(separator: "\n", omittingEmptySubsequences: false).indices, id: \.self) { index in
                let line = String(text.split(separator: "\n", omittingEmptySubsequences: false)[index])
                
                if line.starts(with: "# ") {
                    Text(String(line.dropFirst(2)))
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                } else if line.starts(with: "## ") {
                    Text(String(line.dropFirst(3)))
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else if line.starts(with: "### ") {
                    Text(String(line.dropFirst(4)))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else if line.starts(with: "- ") {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .fontWeight(.semibold)
                        Text(String(line.dropFirst(2)))
                    }
                    .foregroundColor(.primary)
                } else if line.contains("**") {
                    // Simple bold rendering
                    Text(renderBoldText(line))
                        .foregroundColor(.primary)
                } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(line)
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    private func renderBoldText(_ text: String) -> AttributedString {
        var result = AttributedString()
        var temp = text
        var isBold = false
        
        while !temp.isEmpty {
            if let range = temp.range(of: "**") {
                result += AttributedString(temp[..<range.lowerBound])
                temp = String(temp[range.upperBound...])
                isBold.toggle()
                
                if let nextRange = temp.range(of: "**") {
                    var boldPart = AttributedString(temp[..<nextRange.lowerBound])
                    var container = AttributeContainer()
                    container.font = .system(.body, design: .default).bold()
                    boldPart.mergeAttributes(container)
                    result += boldPart
                    temp = String(temp[nextRange.upperBound...])
                    isBold = false
                }
            } else {
                result += AttributedString(temp)
                break
            }
        }
        
        return result
    }
}

#Preview {
    @State var draftText = "This is a sample LinkedIn post about recent findings..."
    @State var releaseTitle = "Weekly Release - Week 1"
    
    return ReleaseDraftEditor(draftText: $draftText, releaseTitle: $releaseTitle)
}

