#!/usr/bin/env swift

// MARK: - URL Metadata Extraction Test Script
// This script integrates with the app's modules (URLContentExtractor, LLMManager)
// Run from Xcode or as part of the app's test target
// Usage: Add this file to your Xcode project and run it, or use the standalone version

import Foundation
// Note: This script requires access to app modules:
// - URLContentExtractor
// - LLMManager  
// - ContentMetadata
// To use this script, either:
// 1. Add it to your Xcode project and run as a test
// 2. Import the modules if running standalone
// 3. Use test_url_extraction_standalone.swift for true standalone execution

// MARK: - Data Structures

struct URLMetadata: Codable {
    let title: String?
    let description: String?
    let tags: [String]
    
    init(title: String? = nil, description: String? = nil, tags: [String] = []) {
        self.title = title
        self.description = description
        self.tags = tags
    }
}

// MARK: - Expected Results (for comparison)

struct ExpectedResult {
    let number: Int
    let title: String
    let description: String
    let whyUseful: String
    let tags: [String]
}

let expectedResults: [Int: ExpectedResult] = [
    1: ExpectedResult(
        number: 1,
        title: "NeuralForecast",
        description: "A comprehensive collection of neural forecasting models focusing on performance, usability, and scalability. Includes popular architectures such as RNNs, LSTMs, Transformers, and TimeLLM for time-series forecasting.",
        whyUseful: "Enables researchers and practitioners to easily experiment with state-of-the-art deep learning forecasting models in a consistent Python interface.",
        tags: ["time-series", "forecasting", "deep-learning", "transformers", "neural-networks", "python"]
    ),
    2: ExpectedResult(
        number: 2,
        title: "Tiny Recursive Models (TRM)",
        description: "A lightweight implementation of the TRM (Tiny Recursive Model) architecture based on the research paper \"Tiny Recursive Models\" (arXiv:2510.04871v1).",
        whyUseful: "Offers a minimal and educational implementation for studying recursive models and understanding efficient model design.",
        tags: ["machine-learning", "deep-learning", "transformers", "research", "recursive-models"]
    ),
    3: ExpectedResult(
        number: 3,
        title: "Granite Docling 258M WebGPU",
        description: "A Hugging Face Space by IBM Granite that converts document images into HTML using 🤗 Transformers.js. Runs directly in the browser with WebGPU acceleration.",
        whyUseful: "Enables real-time, private document-to-HTML conversion without server-side processing — ideal for web apps and document automation.",
        tags: ["document-processing", "transformers", "webgpu", "ocr", "html", "huggingface"]
    ),
    4: ExpectedResult(
        number: 4,
        title: "Enterprise Deep Research",
        description: "A Salesforce AI Research project focused on building deep research assistants that can reason over enterprise data. Combines LLMs, retrieval systems, and structured reasoning.",
        whyUseful: "Helps organizations build intelligent research agents capable of summarizing and reasoning over large-scale enterprise knowledge bases.",
        tags: ["enterprise-ai", "llm", "retrieval-augmented-generation", "deep-research", "salesforce"]
    ),
    5: ExpectedResult(
        number: 5,
        title: "Open Agent Builder",
        description: "An open-source framework to design, compose, and deploy AI agents powered by Firecrawl. Allows building autonomous or semi-autonomous systems using modular blocks.",
        whyUseful: "Makes it easy for developers to create AI agents for automation, web interaction, and data processing without proprietary dependencies.",
        tags: ["ai-agents", "open-source", "automation", "firecrawl", "llm"]
    ),
    6: ExpectedResult(
        number: 6,
        title: "Efficient Memory in Long Context Transformers",
        description: "A research paper exploring methods for improving memory and efficiency in handling long sequences with transformer architectures.",
        whyUseful: "Offers insights and algorithms that enhance transformer performance for long-context tasks such as document QA and summarization.",
        tags: ["transformers", "memory", "long-context", "ai-research", "nlp"]
    ),
    7: ExpectedResult(
        number: 7,
        title: "Adaptive Fine-Tuning Strategies for Large Language Models",
        description: "Recent research published on Hugging Face Papers discussing methods to fine-tune LLMs efficiently across diverse tasks and data domains.",
        whyUseful: "Helps improve the adaptability and cost-effectiveness of LLM fine-tuning workflows in production environments.",
        tags: ["fine-tuning", "large-language-models", "huggingface", "optimization", "ai-research"]
    ),
    8: ExpectedResult(
        number: 8,
        title: "LEANN (Lightweight Efficient Attention Neural Network)",
        description: "A GitHub project introducing LEANN — a lightweight attention-based neural network designed for efficiency in edge and resource-constrained environments.",
        whyUseful: "Enables deploying attention models on low-power hardware without sacrificing performance.",
        tags: ["attention-models", "lightweight-ai", "edge-ai", "neural-networks", "efficiency"]
    )
]

// MARK: - Prompt Builder

func buildExtractionPrompt(url: URL, content: String, metadata: String?) -> String {
    // Improved prompt with clearer instructions and examples
    var prompt = """
    Extract metadata from this URL. Return ONLY valid JSON, no other text.
    
    URL: \(url.absoluteString)
    
    Instructions:
    1. Title: Extract the exact project/paper/repo name (be precise)
    2. Description: Write 2-3 sentences summarizing what it does, then add "Why it is useful: [reason]"
    3. Tags: Provide 3-8 relevant keywords (technologies, domains, concepts)
    
    Required JSON format (return ONLY this, no markdown, no code blocks):
    {
      "title": "exact title here",
      "description": "summary. Why it is useful: reason here",
      "tags": ["tag1", "tag2", "tag3"]
    }
    
    """
    
    if let metadata = metadata, !metadata.isEmpty {
        prompt += "Metadata:\n\(metadata)\n\n"
    }
    
    // Include content (truncate if too long)
    let maxContentLength = 3000  // Reduced for better focus
    let contentToInclude: String
    if content.count > maxContentLength {
        // Prioritize beginning (usually has most important info)
        let beginning = String(content.prefix(maxContentLength * 2 / 3))
        let end = String(content.suffix(maxContentLength / 3))
        contentToInclude = "\(beginning)\n\n[... truncated ...]\n\n\(end)"
    } else {
        contentToInclude = content
    }
    
    prompt += "Content:\n\(contentToInclude)\n\n"
    prompt += "Return JSON only:"
    
    return prompt
}

// MARK: - JSON Parser

func parseJSONResponse(_ response: String) -> URLMetadata? {
    // Try to extract JSON from the response
    var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Remove markdown code blocks if present
    if jsonString.hasPrefix("```json") {
        jsonString = String(jsonString.dropFirst(7))
    } else if jsonString.hasPrefix("```") {
        jsonString = String(jsonString.dropFirst(3))
    }
    
    if jsonString.hasSuffix("```") {
        jsonString = String(jsonString.dropLast(3))
    }
    
    jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Try to find JSON object in the response - be more flexible
    // Look for the first { and matching }
    if let jsonStart = jsonString.range(of: "{"),
       let jsonEnd = jsonString.range(of: "}", options: .backwards, range: jsonStart.upperBound..<jsonString.endIndex) {
        let jsonRange = jsonStart.lowerBound..<jsonEnd.upperBound
        jsonString = String(jsonString[jsonRange])
    } else if let jsonStart = jsonString.range(of: "{") {
        // If no closing brace found, try to find it after the start
        let remaining = jsonString[jsonStart.upperBound...]
        if let jsonEnd = remaining.range(of: "}", options: .backwards) {
            let jsonRange = jsonStart.lowerBound..<jsonEnd.upperBound
            jsonString = String(jsonString[jsonRange])
        }
    }
    
    // Clean up common issues
    jsonString = jsonString.replacingOccurrences(of: "\\n", with: " ")
    jsonString = jsonString.replacingOccurrences(of: "\\t", with: " ")
    
    // Parse JSON
    guard let data = jsonString.data(using: .utf8) else {
        print("⚠️  Could not convert to data")
        return nil
    }
    
    do {
        let decoder = JSONDecoder()
        let metadata = try decoder.decode(URLMetadata.self, from: data)
        return metadata
    } catch {
        // Try to fix common JSON issues
        var fixedJson = jsonString
        
        // Fix unescaped quotes in strings
        fixedJson = fixedJson.replacingOccurrences(of: #"([^\\])"([^":,}\]]+)"([^:,}\]]*)"#, with: #"$1\"$2$3\""#, options: .regularExpression)
        
        // Try parsing again
        if let fixedData = fixedJson.data(using: .utf8),
           let metadata = try? JSONDecoder().decode(URLMetadata.self, from: fixedData) {
            return metadata
        }
        
        print("⚠️  JSON parsing error: \(error)")
        print("   Response preview: \(response.prefix(200))...")
        return nil
    }
}

// MARK: - Text Fallback Parser

func parseTextResponse(_ response: String) -> URLMetadata {
    var title: String? = nil
    var description: String? = nil
    var tags: [String] = []
    
    let lines = response.components(separatedBy: .newlines)
    
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            continue
        }
        
        // Try to extract title
        if title == nil {
            if trimmed.lowercased().hasPrefix("title:") {
                title = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.lowercased().hasPrefix("📘") || trimmed.lowercased().hasPrefix("title") {
                title = trimmed.replacingOccurrences(of: "📘", with: "")
                    .replacingOccurrences(of: "Title:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Try to extract description
        if description == nil {
            if trimmed.lowercased().hasPrefix("description:") {
                description = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.lowercased().hasPrefix("🧠") {
                description = trimmed.replacingOccurrences(of: "🧠", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Try to extract tags
        if trimmed.lowercased().hasPrefix("tags:") {
            let tagsString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            tags = tagsString.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else if trimmed.lowercased().hasPrefix("🏷️") {
            let tagsString = trimmed.replacingOccurrences(of: "🏷️", with: "").trimmingCharacters(in: .whitespaces)
            tags = tagsString.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
    }
    
    return URLMetadata(title: title, description: description, tags: tags)
}

// MARK: - Enhanced Freeform Response Parser

func extractFromFreeformResponse(_ response: String, url: URL) -> URLMetadata {
    var title: String? = nil
    var description: String? = nil
    var tags: [String] = []
    
    // Try to extract from various patterns
    
    // Extract title - look for patterns like "Title:", "Project:", "Name:", or first line if it looks like a title
    let titlePatterns = [
        #"title\s*[:=]\s*([^\n]+)"#,
        #"project\s*[:=]\s*([^\n]+)"#,
        #"name\s*[:=]\s*([^\n]+)"#,
        #"^([A-Z][^\n]{5,50})$"#  // First line that looks like a title
    ]
    
    for pattern in titlePatterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           match.numberOfRanges > 1,
           let titleRange = Range(match.range(at: 1), in: response) {
            title = String(response[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if title?.count ?? 0 > 3 && title?.count ?? 0 < 100 {
                break
            }
        }
    }
    
    // Extract description - look for longer text blocks
    let descPatterns = [
        #"description\s*[:=]\s*([^\n]{20,300})"#,
        #"summary\s*[:=]\s*([^\n]{20,300})"#,
        #"what\s+is\s+it\s*[:=]\s*([^\n]{20,300})"#
    ]
    
    for pattern in descPatterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           match.numberOfRanges > 1,
           let descRange = Range(match.range(at: 1), in: response) {
            description = String(response[descRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if description?.count ?? 0 > 20 {
                break
            }
        }
    }
    
    // Extract tags - look for arrays, comma-separated lists, or keywords
    let tagPatterns = [
        #"tags\s*[:=]\s*\[([^\]]+)\]"#,
        #"tags\s*[:=]\s*([^\n]+)"#,
        #"keywords\s*[:=]\s*([^\n]+)"#
    ]
    
    for pattern in tagPatterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           match.numberOfRanges > 1,
           let tagRange = Range(match.range(at: 1), in: response) {
            let tagString = String(response[tagRange])
            tags = tagString.components(separatedBy: CharacterSet(charactersIn: ",;|"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "") }
                .filter { !$0.isEmpty && $0.count > 2 && $0.count < 30 }
            if !tags.isEmpty {
                break
            }
        }
    }
    
    // Fallback: extract from URL if title not found
    if title == nil {
        if url.host?.contains("github.com") == true {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if let repoName = pathComponents.last {
                title = repoName
            }
        } else if let host = url.host {
            title = host.replacingOccurrences(of: "www.", with: "")
        }
    }
    
    return URLMetadata(title: title, description: description, tags: tags)
}

// MARK: - Result Formatter

func formatResult(number: Int, url: URL, metadata: URLMetadata, expected: ExpectedResult?) -> String {
    var output = "\n\(String(repeating: "=", count: 80))\n"
    output += "Test \(number): \(url.absoluteString)\n"
    output += String(repeating: "=", count: 80) + "\n\n"
    
    output += "📘 Title: \(metadata.title ?? "N/A")\n\n"
    
    if let description = metadata.description {
        output += "🧠 Description:\n\(description)\n\n"
    } else {
        output += "🧠 Description: N/A\n\n"
    }
    
    output += "🏷️ Tags: \(metadata.tags.joined(separator: ", "))\n\n"
    
    if let expected = expected {
        output += "--- Expected vs Actual ---\n\n"
        
        // Compare title
        let titleMatch = metadata.title?.lowercased().contains(expected.title.lowercased()) ?? false
        output += "Title: \(titleMatch ? "✅" : "❌")\n"
        output += "  Expected: \(expected.title)\n"
        output += "  Actual:   \(metadata.title ?? "N/A")\n\n"
        
        // Compare description
        let descMatch = metadata.description?.lowercased().contains(expected.description.lowercased().prefix(50)) ?? false
        output += "Description: \(descMatch ? "✅" : "❌")\n"
        output += "  Expected: \(expected.description)\n"
        output += "  Actual:   \(metadata.description ?? "N/A")\n\n"
        
        // Compare tags
        let expectedTagsSet = Set(expected.tags.map { $0.lowercased() })
        let actualTagsSet = Set(metadata.tags.map { $0.lowercased() })
        let commonTags = expectedTagsSet.intersection(actualTagsSet)
        let tagMatch = commonTags.count >= min(3, expected.tags.count)
        output += "Tags: \(tagMatch ? "✅" : "❌") (\(commonTags.count)/\(expected.tags.count) match)\n"
        output += "  Expected: \(expected.tags.joined(separator: ", "))\n"
        output += "  Actual:   \(metadata.tags.joined(separator: ", "))\n"
    }
    
    return output
}

// MARK: - Mock LLM Service (for testing without actual LLM)

class MockLLMService {
    func generateResponse(prompt: String) -> String {
        // This is a placeholder - in real testing, this would call the actual LLM
        // For now, return a mock JSON response for testing the parsing logic
        return """
        {
          "title": "Test Title",
          "description": "Test description. Why it is useful: It's useful for testing.",
          "tags": ["test", "example", "mock"]
        }
        """
    }
}

// MARK: - Main Test Function

@MainActor
func runTests() async {
    print("🚀 Starting URL Extraction Tests")
    print("Reading URLs from TODO.md...\n")
    
    // Read TODO.md
    let scriptPath = URL(fileURLWithPath: #file).deletingLastPathComponent()
    let todoPath = scriptPath.appendingPathComponent("TODO.md")
    
    guard let todoContent = try? String(contentsOf: todoPath, encoding: .utf8) else {
        print("❌ Error: Could not read TODO.md at \(todoPath.path)")
        print("   Make sure TODO.md is in the same directory as this script.")
        return
    }
    
    // Parse URLs
    let lines = todoContent.components(separatedBy: .newlines)
    var urls: [(Int, URL)] = []
    
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || !trimmed.hasPrefix("(") {
            continue
        }
        
        // Extract number and URL
        if let numberRange = trimmed.range(of: #"\(\d+\)"#, options: .regularExpression),
           let urlRange = trimmed.range(of: #"https?://[^\s]+"#, options: .regularExpression) {
            let numberString = String(trimmed[numberRange])
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
            
            if let number = Int(numberString) {
                let urlString = String(trimmed[urlRange]).trimmingCharacters(in: .whitespaces)
                if let url = URL(string: urlString) {
                    urls.append((number, url))
                }
            }
        }
    }
    
    print("Found \(urls.count) URLs to test\n")
    
    // Check if LLM is loaded
    let llmManager = LLMManager.shared
    guard llmManager.isModelLoaded else {
        print("❌ Error: LLM model is not loaded. Please load a model first.")
        print("   The test requires an LLM to be loaded via LLMManager.")
        print("   You can load a model in the app's Settings, or use the standalone script with API keys.")
        return
    }
    
    print("✅ LLM model is loaded. Starting extraction tests...\n")
    
    var results: [(Int, URL, URLMetadata, ExpectedResult?)] = []
    
    // Test each URL
    for (index, (number, url)) in urls.enumerated() {
        print("📋 Testing \(index + 1)/\(urls.count): \(url.absoluteString)")
        
        do {
            // Step 1: Extract content
            print("   ⏳ Extracting content...")
            let contentExtractor = URLContentExtractor.shared
            let result = try await contentExtractor.extractContentWithMetadata(from: url)
            let content = result.content
            let metadata = result.metadata
            
            print("   ✅ Content extracted (\(content.count) characters)")
            
            // Step 2: Build prompt
            let prompt = buildExtractionPrompt(
                url: url,
                content: content,
                metadata: metadata.contextString()
            )
            
            // Step 3: Call LLM
            print("   ⏳ Calling LLM...")
            let response = try await llmManager.generateChatResponse(prompt: prompt, context: Optional<String>.none)
            print("   ✅ LLM response received")
            
            // Step 4: Parse response (with improved parsing)
            var extractedMetadata = parseJSONResponse(response) ?? parseTextResponse(response)
            
            // If parsing failed, try enhanced extraction
            if extractedMetadata.title == nil && extractedMetadata.tags.isEmpty {
                extractedMetadata = extractFromFreeformResponse(response, url: url)
            }
            
            // Step 5: Store result
            let expected = expectedResults[number]
            results.append((number, url, extractedMetadata, expected))
            
            // Print immediate result
            print(formatResult(number: number, url: url, metadata: extractedMetadata, expected: expected))
            
        } catch {
            print("   ❌ Error processing URL: \(error.localizedDescription)")
            let expected = expectedResults[number]
            results.append((number, url, URLMetadata(), expected))
        }
        
        // Small delay between requests
        if index < urls.count - 1 {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
    
    // Print summary
    print("\n\(String(repeating: "=", count: 80))")
    print("📊 TEST SUMMARY")
    print(String(repeating: "=", count: 80))
    
    var titleMatches = 0, descMatches = 0, tagMatches = 0
    let total = results.count
    
    for (_, _, metadata, expected) in results {
        if let expected = expected {
            if metadata.title?.lowercased().contains(expected.title.lowercased()) ?? false {
                titleMatches += 1
            }
            if metadata.description?.lowercased().contains(expected.description.lowercased().prefix(50)) ?? false {
                descMatches += 1
            }
            let expectedTagsSet = Set(expected.tags.map { $0.lowercased() })
            let actualTagsSet = Set(metadata.tags.map { $0.lowercased() })
            if expectedTagsSet.intersection(actualTagsSet).count >= min(3, expected.tags.count) {
                tagMatches += 1
            }
        }
    }
    
    print("\nResults: \(total) URLs tested")
    print("Title matches: \(titleMatches)/\(total) (\(Int(Double(titleMatches)/Double(total)*100))%)")
    print("Description matches: \(descMatches)/\(total) (\(Int(Double(descMatches)/Double(total)*100))%)")
    print("Tag matches: \(tagMatches)/\(total) (\(Int(Double(tagMatches)/Double(total)*100))%)")
    print("\n✅ Tests completed!")
}

// MARK: - Entry Point

if #available(macOS 10.15, iOS 13.0, *) {
    Task { @MainActor in
        await runTests()
        exit(0)
    }
    RunLoop.main.run()
} else {
    print("❌ Requires macOS 10.15+ or iOS 13.0+")
    exit(1)
}
