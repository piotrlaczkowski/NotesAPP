import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Test view for URL extraction - can be added to Settings or run independently
struct URLExtractionTestView: View {
    @StateObject private var testRunner = URLExtractionTestRunner()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status
                    if testRunner.isRunning {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                ProgressView()
                                Text("Running tests...")
                            }
                            if !testRunner.statusMessage.isEmpty {
                                Text(testRunner.statusMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    } else if testRunner.hasCompleted {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Tests completed")
                            }
                            if !testRunner.statusMessage.isEmpty {
                                Text(testRunner.statusMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Error message
                    if let error = testRunner.errorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Results
                    if !testRunner.results.isEmpty {
                        ForEach(testRunner.results, id: \.number) { result in
                            TestResultView(result: result)
                        }
                    } else if !testRunner.isRunning && testRunner.hasCompleted {
                        Text("No results yet. Check error messages above.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    // Summary
                    if testRunner.hasCompleted {
                        SummaryView(
                            total: testRunner.results.count,
                            titleMatches: testRunner.titleMatches,
                            descMatches: testRunner.descMatches,
                            tagMatches: testRunner.tagMatches
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("URL Extraction Tests")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Run Tests") {
                        Task {
                            await testRunner.runTests()
                        }
                    }
                    .disabled(testRunner.isRunning)
                }
            }
        }
    }
}

struct TestResultView: View {
    let result: TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test \(result.number): \(result.url.absoluteString)")
                .font(.headline)
            
            if let title = result.extracted.title {
                HStack {
                    Text("Title:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(title)
                    if result.titleMatch {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            
            if let description = result.extracted.description {
                VStack(alignment: .leading) {
                    Text("Description:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(description)
                        .font(.caption)
                    if result.descMatch {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            
            if !result.extracted.tags.isEmpty {
                HStack {
                    Text("Tags:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(result.extracted.tags.joined(separator: ", "))
                        .font(.caption)
                    if result.tagMatch {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        #if os(iOS)
        .background(Color(uiColor: .systemGray6))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .cornerRadius(10)
    }
}

struct SummaryView: View {
    let total: Int
    let titleMatches: Int
    let descMatches: Int
    let tagMatches: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
            
            HStack {
                Text("Title matches:")
                Spacer()
                Text("\(titleMatches)/\(total) (\(Int(Double(titleMatches)/Double(total)*100))%)")
            }
            
            HStack {
                Text("Description matches:")
                Spacer()
                Text("\(descMatches)/\(total) (\(Int(Double(descMatches)/Double(total)*100))%)")
            }
            
            HStack {
                Text("Tag matches:")
                Spacer()
                Text("\(tagMatches)/\(total) (\(Int(Double(tagMatches)/Double(total)*100))%)")
            }
        }
        .padding()
        #if os(iOS)
        .background(Color(uiColor: .systemGray6))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .cornerRadius(10)
    }
}

struct TestResult {
    let number: Int
    let url: URL
    let extracted: URLMetadata
    let expected: ExpectedResult?
    let titleMatch: Bool
    let descMatch: Bool
    let tagMatch: Bool
}

struct ExpectedResult {
    let number: Int
    let title: String
    let description: String
    let whyUseful: String
    let tags: [String]
}

@MainActor
class URLExtractionTestRunner: ObservableObject {
    @Published var isRunning = false
    @Published var hasCompleted = false
    @Published var results: [TestResult] = []
    @Published var titleMatches = 0
    @Published var descMatches = 0
    @Published var tagMatches = 0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    
    private let expectedResults: [Int: ExpectedResult] = [
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
    
    func runTests() async {
        isRunning = true
        hasCompleted = false
        results = []
        titleMatches = 0
        descMatches = 0
        tagMatches = 0
        statusMessage = "Starting tests..."
        errorMessage = nil
        
        defer {
            isRunning = false
            hasCompleted = true
        }
        
        // Check if LLM is loaded first, and wait for models to load if needed
        let llmManager = LLMManager.shared
        let modelDownloader = ModelDownloader.shared
        
        // Wait for models to be loaded (with timeout)
        if !llmManager.isModelLoaded {
            statusMessage = "Models downloading/loading, waiting..."
            
            // Check if models are downloaded but not loaded
            let extractionModel = ModelConfig.recommendedModel(for: .extraction)
            let ragModel = ModelConfig.recommendedModel(for: .rag)
            
            let extractionDownloaded = await modelDownloader.isModelDownloaded(extractionModel)
            let ragDownloaded = await modelDownloader.isModelDownloaded(ragModel)
            
            if extractionDownloaded || ragDownloaded {
                // Models are downloaded, try to load them
                statusMessage = "Loading models..."
                await llmManager.loadSpecializedModels()
            } else {
                // Models not downloaded, wait for download and load
                statusMessage = "Waiting for models to download and load..."
                var attempts = 0
                while !llmManager.isModelLoaded && attempts < 60 { // Wait up to 60 seconds
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    attempts += 1
                    
                    // Try loading if models are now downloaded
                    let extractionDownloaded = await modelDownloader.isModelDownloaded(extractionModel)
                    let ragDownloaded = await modelDownloader.isModelDownloaded(ragModel)
                    if extractionDownloaded || ragDownloaded {
                        await llmManager.loadSpecializedModels()
                    }
                }
            }
        }
        
        // Final check
        guard llmManager.isModelLoaded else {
            statusMessage = "Error: LLM model not loaded"
            errorMessage = "Please ensure models are downloaded and loaded in Settings before running tests. Models may still be downloading."
            return
        }
        
        statusMessage = "Reading TODO.md..."
        
        // Try multiple paths to find TODO.md
        var todoContent: String?
        var todoPath: URL?
        
        // Path 1: Try relative to app bundle (for macOS app)
        if let bundlePath = Bundle.main.resourcePath {
            let path1 = URL(fileURLWithPath: bundlePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("TODO.md")
            if let content = try? String(contentsOf: path1, encoding: .utf8) {
                todoContent = content
                todoPath = path1
            }
        }
        
        // Path 2: Try Documents directory
        if todoContent == nil {
            let fileManager = FileManager.default
            if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let path2 = documentsPath.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Desktop/PROJECT/NotesApp/TODO.md")
                if let content = try? String(contentsOf: path2, encoding: .utf8) {
                    todoContent = content
                    todoPath = path2
                }
            }
        }
        
        // Path 3: Try current working directory
        if todoContent == nil {
            let fileManager = FileManager.default
            let currentDir = fileManager.currentDirectoryPath
            let path3 = URL(fileURLWithPath: currentDir).appendingPathComponent("TODO.md")
            if let content = try? String(contentsOf: path3, encoding: .utf8) {
                todoContent = content
                todoPath = path3
            }
        }
        
        // Path 4: Try hardcoded path
        if todoContent == nil {
            let path4 = URL(fileURLWithPath: "/Users/piotrlaczkowski/Desktop/PROJECT/NotesApp/TODO.md")
            if let content = try? String(contentsOf: path4, encoding: .utf8) {
                todoContent = content
                todoPath = path4
            }
        }
        
        guard let content = todoContent else {
            statusMessage = "Error: Could not find TODO.md"
            errorMessage = "TODO.md not found. Please ensure it exists in the project directory."
            return
        }
        
        statusMessage = "Found TODO.md at: \(todoPath?.path ?? "unknown")"
        statusMessage += "\nParsing URLs..."
        
        await processURLs(from: content)
    }
    
    private func processURLs(from todoContent: String) async {
        // Parse URLs
        let lines = todoContent.components(separatedBy: .newlines)
        var urls: [(Int, URL)] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || !trimmed.hasPrefix("(") { continue }
            
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
        
        guard !urls.isEmpty else {
            statusMessage = "Error: No URLs found in TODO.md"
            errorMessage = "Could not parse any URLs from TODO.md. Please check the file format."
            return
        }
        
        statusMessage = "Found \(urls.count) URLs to test"
        
        // Final check before testing - ensure model is still loaded
        let llmManager = LLMManager.shared
        guard llmManager.isModelLoaded else {
            statusMessage = "Error: LLM model not loaded"
            errorMessage = "Model became unavailable. Please ensure a model is loaded in Settings before running tests."
            return
        }
        
        statusMessage = "Testing \(urls.count) URLs..."
        
        // Test each URL
        for (index, (number, url)) in urls.enumerated() {
            statusMessage = "Testing \(index + 1)/\(urls.count): \(url.absoluteString)"
            do {
                // Extract content
                await MainActor.run {
                    statusMessage = "Testing \(index + 1)/\(urls.count): Extracting content from \(url.absoluteString)"
                }
                
                let contentExtractor = URLContentExtractor.shared
                let result = try await contentExtractor.extractContentWithMetadata(from: url)
                let content = result.content
                let metadata = result.metadata
                
                await MainActor.run {
                    statusMessage = "Testing \(index + 1)/\(urls.count): Calling LLM..."
                }
                
                // Build prompt
                let prompt = buildExtractionPrompt(url: url, content: content, metadata: metadata.contextString())
                
                // Call LLM - generateChatResponse will use RAG model if available, or general model as fallback
                let response: String
                do {
                    response = try await llmManager.generateChatResponse(prompt: prompt, context: nil)
                } catch let error as LLMError {
                    await MainActor.run {
                        statusMessage = "LLM Error: \(error.message)"
                        errorMessage = "Failed to generate response: \(error.message). Ensure models are loaded."
                    }
                    throw error
                } catch {
                    await MainActor.run {
                        statusMessage = "LLM Error: \(error.localizedDescription)"
                        errorMessage = "Failed to generate response: \(error.localizedDescription)"
                    }
                    throw error
                }
                
                await MainActor.run {
                    statusMessage = "Testing \(index + 1)/\(urls.count): Parsing response..."
                }
                
                // Debug: Print raw response for terminal
                let separator = String(repeating: "=", count: 80)
                let dashSeparator = String(repeating: "-", count: 80)
                print("\n\(separator)")
                print("TEST \(number): \(url.absoluteString)")
                print(separator)
                print("RAW LLM RESPONSE:")
                print(response)
                print(dashSeparator)
                
                // Parse response using URLMetadataExtractor
                let extractedMetadata = URLMetadataExtractor.parseJSONResponse(response) ?? URLMetadataExtractor.parseTextResponse(response)
                
                // Debug: Print extracted metadata
                print("EXTRACTED METADATA:")
                print("Title: \(extractedMetadata.title ?? "nil")")
                print("Description: \(extractedMetadata.description ?? "nil")")
                print("Tags: \(extractedMetadata.tags.joined(separator: ", "))")
                print(separator + "\n")
                
                // Compare with expected
                let expected = expectedResults[number]
                let titleMatch = expected?.title.lowercased() == extractedMetadata.title?.lowercased() || 
                                (extractedMetadata.title?.lowercased().contains(expected?.title.lowercased() ?? "") ?? false)
                let descMatch = extractedMetadata.description?.lowercased().contains(expected?.description.lowercased().prefix(50) ?? "") ?? false
                let expectedTagsSet = Set(expected?.tags.map { $0.lowercased() } ?? [])
                let actualTagsSet = Set(extractedMetadata.tags.map { $0.lowercased() })
                let tagMatch = expectedTagsSet.intersection(actualTagsSet).count >= min(3, expected?.tags.count ?? 0)
                
                let testResult = TestResult(
                    number: number,
                    url: url,
                    extracted: extractedMetadata,
                    expected: expected,
                    titleMatch: titleMatch,
                    descMatch: descMatch,
                    tagMatch: tagMatch
                )
                
                await MainActor.run {
                    results.append(testResult)
                    if titleMatch { titleMatches += 1 }
                    if descMatch { descMatches += 1 }
                    if tagMatch { tagMatches += 1 }
                    statusMessage = "Completed \(index + 1)/\(urls.count): \(titleMatch && descMatch && tagMatch ? "✅" : "⚠️")"
                }
                
            } catch {
                await MainActor.run {
                    statusMessage = "Error testing \(index + 1)/\(urls.count): \(error.localizedDescription)"
                    errorMessage = "Failed to test URL \(number): \(error.localizedDescription)"
                    
                    // Add error result
                    let errorResult = TestResult(
                        number: number,
                        url: url,
                        extracted: URLMetadata(title: nil, description: nil, tags: []),
                        expected: expectedResults[number],
                        titleMatch: false,
                        descMatch: false,
                        tagMatch: false
                    )
                    results.append(errorResult)
                }
            }
            
            // Small delay between requests
            if index < urls.count - 1 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        // Get final results for summary
        let finalResults = await MainActor.run { results }
        let finalTitleMatches = await MainActor.run { titleMatches }
        let finalDescMatches = await MainActor.run { descMatches }
        let finalTagMatches = await MainActor.run { tagMatches }
        
        await MainActor.run {
            statusMessage = "✅ Tests completed! \(finalTitleMatches)/\(urls.count) title matches, \(finalDescMatches)/\(urls.count) description matches, \(finalTagMatches)/\(urls.count) tag matches"
        }
        
        // Print final summary to terminal
        let separator = String(repeating: "=", count: 80)
        print("\n\(separator)")
        print("FINAL TEST SUMMARY")
        print(separator)
        print("Total Tests: \(urls.count)")
        print("Title Matches: \(finalTitleMatches)/\(urls.count)")
        print("Description Matches: \(finalDescMatches)/\(urls.count)")
        print("Tag Matches: \(finalTagMatches)/\(urls.count)")
        print("\nDetailed Results:")
        for result in finalResults {
            print("\nTest \(result.number): \(result.url.absoluteString)")
            print("  Title: \(result.extracted.title ?? "nil") - \(result.titleMatch ? "✅" : "❌")")
            if let desc = result.extracted.description {
                let preview = desc.count > 100 ? String(desc.prefix(100)) + "..." : desc
                print("  Description: \(preview) - \(result.descMatch ? "✅" : "❌")")
            } else {
                print("  Description: nil - \(result.descMatch ? "✅" : "❌")")
            }
            print("  Tags: \(result.extracted.tags.joined(separator: ", ")) - \(result.tagMatch ? "✅" : "❌")")
        }
        print(separator + "\n")
    }
    
    private func buildExtractionPrompt(url: URL, content: String, metadata: String?) -> String {
        var prompt = """
        You are an expert technical analyst specializing in extracting deep insights about projects, research papers, and code repositories.
        
        Extract comprehensive metadata from this URL: \(url.absoluteString)
        
        CRITICAL INSTRUCTIONS:
        
        1. TITLE: Extract the exact, precise project/paper/repository name. Be specific and accurate.
        
        2. DESCRIPTION: Write a comprehensive, deep description that includes:
           - A detailed overview (2-4 sentences) explaining:
             * What the resource is and what it does
             * The core technology, approach, or methodology
             * Key features and capabilities
             * What problem it solves or what gap it fills
           
           - A value proposition section starting with "Why it is useful:" that details:
             * CRITICAL: Extract ACTUAL, SPECIFIC value from the content. Do NOT use generic statements.
             * FORBIDDEN generic phrases (DO NOT USE): "presents novel approach", "innovative solution", "practical and applicable", "comprehensive resource", "state-of-the-art", "cutting-edge", "valuable information"
             * REQUIRED: Extract REAL, CONCRETE value such as:
               - Specific metrics: "97% storage savings", "10x faster inference", "runs on edge devices with 2GB RAM"
               - Actual problems solved: "eliminates the need for cloud API calls", "enables offline document processing", "reduces model size from 7B to 1.2B parameters"
               - Real use cases: "ideal for mobile apps requiring privacy", "enables real-time translation without internet", "supports batch processing of 1000+ documents"
               - Measurable benefits: "reduces deployment costs by 80%", "improves accuracy by 15% over baseline", "processes 10x more requests per second"
               - Specific innovations: "first framework to support WebGPU acceleration", "introduces novel attention mechanism reducing memory by 50%"
             * If you cannot find specific value, extract the most detailed benefit mentioned in the content, even if it's not quantified
             * NEVER use vague statements - always be specific about WHAT makes it useful and WHY
             
           Example format: "Detailed overview of what it is and does. Why it is useful: [Specific metrics like '97% storage savings', actual problems solved, real use cases, measurable benefits, specific innovations - NOT generic statements]"
        
        3. TAGS: Provide 5-10 relevant keywords covering:
           - Domain/field (e.g., machine-learning, ai, nlp)
           - Technologies used (e.g., python, transformers, webgpu)
           - Type of resource (e.g., research-paper, framework, tool)
           - Key concepts (e.g., retrieval-augmented-generation, edge-ai)
        
        CRITICAL OUTPUT REQUIREMENTS:
        - Return ONLY a valid JSON object
        - Do NOT repeat any instructions or prompt text
        - Do NOT include phrases like "You are an expert" or instruction bullets
        - Start directly with { and end with }
        - The description field should contain ONLY the actual description text, not instructions
        
        {
          "title": "exact title here",
          "description": "Write the actual description here. Include what it is, what it does, and why it's useful with specific details. Do NOT include instruction text.",
          "tags": ["tag1", "tag2", "tag3", "tag4", "tag5"]
        }
        
        IMPORTANT: The description field must contain ONLY the actual description text about the resource, NOT the instructions above.
        
        """
        
        if let metadata = metadata, !metadata.isEmpty {
            prompt += "Metadata:\n\(metadata)\n\n"
        }
        
        // Include more content for deeper analysis (increased from 3000 to 5000)
        let maxContentLength = 5000
        let contentToInclude: String
        if content.count > maxContentLength {
            let beginning = String(content.prefix(maxContentLength * 2 / 3))
            let end = String(content.suffix(maxContentLength / 3))
            contentToInclude = "\(beginning)\n\n[... truncated ...]\n\n\(end)"
        } else {
            contentToInclude = content
        }
        
        prompt += """
        
        CONTENT TO ANALYZE:
        \(contentToInclude)
        
        IMPORTANT: Analyze the content deeply. Look for:
        - Specific metrics, benchmarks, or performance numbers
        - Novel technical approaches or innovations
        - Unique features or capabilities
        - Practical use cases and applications
        - Scalability, efficiency, or performance advantages
        - Research contributions or technical insights
        
        Return ONLY valid JSON, no markdown, no code blocks, no additional text:
        """
        
        return prompt
    }
    
}

