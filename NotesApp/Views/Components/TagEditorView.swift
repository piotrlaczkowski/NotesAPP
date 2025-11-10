import SwiftUI

struct TagEditorView: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    @FocusState private var isTagFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Existing tags
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                            Button {
                                // CRITICAL: Capture current tags snapshot to avoid race conditions
                                let currentTags = tags
                                // Create a new array to ensure the binding is properly updated
                                // Only remove the specific tag, preserve all others
                                var updatedTags = currentTags
                                updatedTags.removeAll { $0 == tag }
                                
                                // Debug logging
                                print("TagEditorView: Removing tag '\(tag)'")
                                print("TagEditorView: Current tags: \(currentTags)")
                                print("TagEditorView: Updated tags: \(updatedTags)")
                                
                                tags = updatedTags
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2))
                        .foregroundColor(.accentColor)
                        .cornerRadius(8)
                    }
                }
            }
            
            // Add tag input
            HStack {
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTagFieldFocused)
                    .onSubmit {
                        addTag()
                    }
                
                Button {
                    addTag()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // CRITICAL: Capture current tags snapshot at the start to avoid race conditions
        let currentTags = tags
        
        // Check for duplicates (case-insensitive)
        let trimmedLower = trimmed.lowercased()
        let existingTagsLower = currentTags.map { $0.lowercased() }
        guard !existingTagsLower.contains(trimmedLower) else {
            // Tag already exists, just clear the input
            newTag = ""
            return
        }
        
        // CRITICAL: Preserve all existing tags
        // Create a new array with all current tags plus the new one
        let currentTagsCount = currentTags.count
        var updatedTags = currentTags  // Copy current tags array
        updatedTags.append(trimmed)  // Append new tag
        
        // Debug: Log to help identify issues
        print("TagEditorView: Adding tag '\(trimmed)'")
        print("TagEditorView: Current tags count: \(currentTagsCount), tags: \(currentTags)")
        print("TagEditorView: Updated tags count: \(updatedTags.count), tags: \(updatedTags)")
        
        // Verify we're preserving tags (log warning if not)
        if updatedTags.count != currentTagsCount + 1 {
            print("⚠️ TagEditorView WARNING: Tag count mismatch! Expected \(currentTagsCount + 1), got \(updatedTags.count)")
        }
        if Array(updatedTags.prefix(currentTagsCount)) != Array(currentTags.prefix(currentTagsCount)) {
            print("⚠️ TagEditorView WARNING: Existing tags were not preserved!")
            print("  Original tags: \(currentTags)")
            print("  Updated tags: \(updatedTags)")
        }
        
        // Update the binding with the new array atomically (this should preserve all tags)
        tags = updatedTags
        
        // Clear input field
        newTag = ""
        isTagFieldFocused = true
        #if os(iOS)
        HapticFeedback.light()
        #endif
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? 0,
            subviews: subviews,
            spacing: spacing
        )
        return result.bounds
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var bounds = CGSize.zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            bounds = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

