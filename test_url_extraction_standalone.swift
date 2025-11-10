#!/usr/bin/env swift

// MARK: - Standalone URL Metadata Extraction Test Script
// This script can be run independently from command line
// Usage: swift test_url_extraction_standalone.swift
// Or: chmod +x test_url_extraction_standalone.swift && ./test_url_extraction_standalone.swift

import Foundation

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

// MARK: - Simple Content Extractor (standalone version)

func extractBasicContent(from url: URL) async throws -> (content: String, metadata: String) {
    var request = URLRequest(url: url)
    request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
    request.timeoutInterval = 30.0
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw NSError(domain: "HTTPError", code: (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
    
    guard let html = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "EncodingError", code: 0)
    }
    
    // Extract basic metadata
    var metadata = ""
    if let title = extractTitle(from: html) {
        metadata += "Title: \(title)\n"
    }
    if let description = extractMetaDescription(from: html) {
        metadata += "Description: \(description)\n"
    }
    
    // Extract main content (simple version)
    let content = extractMainContent(from: html)
    
    return (content: content, metadata: metadata)
}

func extractTitle(from html: String) -> String? {
    // Try <title> tag
    if let range = html.range(of: "<title[^>]*>([^<]+)</title>", options: .regularExpression) {
        let match = String(html[range])
        if let titleRange = match.range(of: ">([^<]+)<", options: .regularExpression) {
            return String(match[titleRange]).replacingOccurrences(of: ">", with: "").replacingOccurrences(of: "<", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return nil
}

func extractMetaDescription(from html: String) -> String? {
    let patterns = [
        "<meta[^>]*name=['\"]description['\"][^>]*content=['\"]([^'\"]*)['\"]",
        "<meta[^>]*content=['\"]([^'\"]*)['\"][^>]*name=['\"]description['\"]"
    ]
    
    for pattern in patterns {
        if let range = html.range(of: pattern, options: .regularExpression) {
            let match = String(html[range])
            if let contentRange = match.range(of: "content=['\"]([^'\"]*)['\"]", options: .regularExpression) {
                return String(match[contentRange]).replacingOccurrences(of: "content=\"", with: "").replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
    }
    return nil
}

func extractMainContent(from html: String) -> String {
    // Remove scripts and styles
    var cleaned = html
        .replacingOccurrences(of: "<script[^>]*>.*?</script>", with: "", options: [.regularExpression, .caseInsensitive])
        .replacingOccurrences(of: "<style[^>]*>.*?</style>", with: "", options: [.regularExpression, .caseInsensitive])
    
    // Extract text from common content tags
    let contentPatterns = [
        "<main[^>]*>(.*?)</main>",
        "<article[^>]*>(.*?)</article>",
        "<div[^>]*class=['\"][^'\"]*content[^'\"]*['\"][^>]*>(.*?)</div>",
        "<body[^>]*>(.*?)</body>"
    ]
    
    for pattern in contentPatterns {
        if let range = cleaned.range(of: pattern, options: [.regularExpression, .caseInsensitive, .dotMatchesLineSeparators]) {
            let content = String(cleaned[range])
            // Remove HTML tags
            let textOnly = content
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if textOnly.count > 100 {
                return textOnly
            }
        }
    }
    
    // Fallback: remove all HTML tags
    return cleaned
        .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Prompt Builder

func buildExtractionPrompt(url: URL, content: String, metadata: String?) -> String {
    var prompt = """
    You are an expert assistant at summarising links to projects, papers and code repositories.
    
    Task:
    Given the following link: \(url.absoluteString)
    1. Determine the Title of the project/paper/repo.
    2. Write a short Description: one or two sentences summarising what it does, then one sentence: 'Why it is useful: …'
    3. Provide Tags: 3-8 keywords covering domain, technology, type, and language.
    
    Output exactly in this JSON format (no additional text):
    {
      "title": "<Project Title or null>",
      "description": "<Short summary plus usefulness or null>",
      "tags": [ "tag1", "tag2", ... ]
    }
    
    If you cannot find a field, use null (for title/description) or [] for tags.
    """
    
    if let metadata = metadata, !metadata.isEmpty {
        prompt += "\n\nAdditional context:\n\(metadata)"
    }
    
    // Include content (truncate if too long)
    let maxContentLength = 4000
    let contentToInclude: String
    if content.count > maxContentLength {
        let beginning = String(content.prefix(maxContentLength / 2))
        let end = String(content.suffix(maxContentLength / 2))
        contentToInclude = "\(beginning)\n\n[... middle content truncated ...]\n\n\(end)"
    } else {
        contentToInclude = content
    }
    
    prompt += "\n\nContent extracted from the link:\n\(contentToInclude)"
    prompt += "\n\nLink: \(url.absoluteString)"
    
    return prompt
}

// MARK: - JSON Parser

func parseJSONResponse(_ response: String) -> URLMetadata? {
    var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Remove markdown code blocks
    if jsonString.hasPrefix("```json") {
        jsonString = String(jsonString.dropFirst(7))
    } else if jsonString.hasPrefix("```") {
        jsonString = String(jsonString.dropFirst(3))
    }
    
    if jsonString.hasSuffix("```") {
        jsonString = String(jsonString.dropLast(3))
    }
    
    jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Find JSON object
    if let jsonStart = jsonString.range(of: "{"),
       let jsonEnd = jsonString.range(of: "}", options: .backwards) {
        let jsonRange = jsonStart.lowerBound..<jsonEnd.upperBound
        jsonString = String(jsonString[jsonRange])
    }
    
    guard let data = jsonString.data(using: .utf8) else {
        return nil
    }
    
    do {
        let decoder = JSONDecoder()
        return try decoder.decode(URLMetadata.self, from: data)
    } catch {
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
        if trimmed.isEmpty { continue }
        
        if title == nil && trimmed.lowercased().hasPrefix("title:") {
            title = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        }
        
        if description == nil && trimmed.lowercased().hasPrefix("description:") {
            description = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
        }
        
        if trimmed.lowercased().hasPrefix("tags:") {
            let tagsString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            tags = tagsString.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
    }
    
    return URLMetadata(title: title, description: description, tags: tags)
}

// MARK: - LLM Interface

protocol LLMProvider {
    func generate(prompt: String) async throws -> String
}

// MARK: - OpenAI API Provider

class OpenAIProvider: LLMProvider {
    private let apiKey: String
    private let model: String
    
    init(apiKey: String, model: String = "gpt-4o-mini") {
        self.apiKey = apiKey
        self.model = model
    }
    
    func generate(prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that extracts metadata from URLs. Always respond with valid JSON."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 500
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "OpenAIError", code: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "OpenAIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Anthropic API Provider

class AnthropicProvider: LLMProvider {
    private let apiKey: String
    private let model: String
    
    init(apiKey: String, model: String = "claude-3-haiku-20240307") {
        self.apiKey = apiKey
        self.model = model
    }
    
    func generate(prompt: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 500,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "system": "You are a helpful assistant that extracts metadata from URLs. Always respond with valid JSON."
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "AnthropicError", code: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw NSError(domain: "AnthropicError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Ollama Local LLM Provider

class OllamaProvider: LLMProvider {
    private let model: String
    private let baseURL: String
    
    init(model: String = "llama3.2", baseURL: String = "http://localhost:11434") {
        self.model = model
        self.baseURL = baseURL
    }
    
    func generate(prompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.3,
                "num_predict": 500
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "OllamaError", code: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw NSError(domain: "OllamaError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Mock LLM Provider (for testing structure)

class MockLLMProvider: LLMProvider {
    func generate(prompt: String) async throws -> String {
        // Return mock JSON for testing
        return """
        {
          "title": "Test Project",
          "description": "A test project for demonstration. Why it is useful: It helps test the extraction system.",
          "tags": ["test", "example", "demo"]
        }
        """
    }
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
        
        let titleMatch = metadata.title?.lowercased().contains(expected.title.lowercased()) ?? false
        output += "Title: \(titleMatch ? "✅" : "❌")\n"
        output += "  Expected: \(expected.title)\n"
        output += "  Actual:   \(metadata.title ?? "N/A")\n\n"
        
        let descMatch = metadata.description?.lowercased().contains(expected.description.lowercased().prefix(50)) ?? false
        output += "Description: \(descMatch ? "✅" : "❌")\n"
        output += "  Expected: \(expected.description)\n"
        output += "  Actual:   \(metadata.description ?? "N/A")\n\n"
        
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

// MARK: - Main Test Function

func runTests(llmProvider: LLMProvider) async {
    print("🚀 Starting URL Extraction Tests")
    print("Reading URLs from TODO.md...\n")
    
    let scriptPath = URL(fileURLWithPath: #file).deletingLastPathComponent()
    let todoPath = scriptPath.appendingPathComponent("TODO.md")
    
    guard let todoContent = try? String(contentsOf: todoPath, encoding: .utf8) else {
        print("❌ Error: Could not read TODO.md at \(todoPath.path)")
        return
    }
    
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
            
            if let number = Int(numberString),
               let urlString = String(trimmed[urlRange]).trimmingCharacters(in: .whitespaces),
               let url = URL(string: urlString) {
                urls.append((number, url))
            }
        }
    }
    
    print("Found \(urls.count) URLs to test\n")
    
    var results: [(Int, URL, URLMetadata, ExpectedResult?)] = []
    
    for (index, (number, url)) in urls.enumerated() {
        print("📋 Testing \(index + 1)/\(urls.count): \(url.absoluteString)")
        
        do {
            // Extract content
            print("   ⏳ Extracting content...")
            let (content, metadata) = try await extractBasicContent(from: url)
            print("   ✅ Content extracted (\(content.count) characters)")
            
            // Build prompt
            let prompt = buildExtractionPrompt(url: url, content: content, metadata: metadata)
            
            // Call LLM
            print("   ⏳ Calling LLM...")
            let response = try await llmProvider.generate(prompt: prompt)
            print("   ✅ LLM response received")
            
            // Parse response
            let extractedMetadata = parseJSONResponse(response) ?? parseTextResponse(response)
            
            // Store result
            let expected = expectedResults[number]
            results.append((number, url, extractedMetadata, expected))
            
            // Print result
            print(formatResult(number: number, url: url, metadata: extractedMetadata, expected: expected))
            
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
            results.append((number, url, URLMetadata(), expectedResults[number]))
        }
        
        if index < urls.count - 1 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
    
    // Summary
    print("\n\(String(repeating: "=", count: 80))")
    print("📊 TEST SUMMARY")
    print(String(repeating: "=", count: 80))
    
    var titleMatches = 0, descMatches = 0, tagMatches = 0
    
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
    
    let total = results.count
    print("\nResults: \(total) URLs tested")
    print("Title matches: \(titleMatches)/\(total) (\(Int(Double(titleMatches)/Double(total)*100))%)")
    print("Description matches: \(descMatches)/\(total) (\(Int(Double(descMatches)/Double(total)*100))%)")
    print("Tag matches: \(tagMatches)/\(total) (\(Int(Double(tagMatches)/Double(total)*100))%)")
    print("\n✅ Tests completed!")
}

// MARK: - LLM Provider Factory

func createLLMProvider() -> LLMProvider {
    // Check for API keys in environment variables
    if let openaiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !openaiKey.isEmpty {
        let model = ProcessInfo.processInfo.environment["OPENAI_MODEL"] ?? "gpt-4o-mini"
        print("✅ Using OpenAI API (model: \(model))")
        return OpenAIProvider(apiKey: openaiKey, model: model)
    }
    
    if let anthropicKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !anthropicKey.isEmpty {
        let model = ProcessInfo.processInfo.environment["ANTHROPIC_MODEL"] ?? "claude-3-haiku-20240307"
        print("✅ Using Anthropic API (model: \(model))")
        return AnthropicProvider(apiKey: anthropicKey, model: model)
    }
    
    // Check if Ollama is available (try to connect)
    let ollamaModel = ProcessInfo.processInfo.environment["OLLAMA_MODEL"] ?? "llama3.2"
    let ollamaURL = ProcessInfo.processInfo.environment["OLLAMA_URL"] ?? "http://localhost:11434"
    
    // Try to use Ollama (will fail gracefully if not available)
    print("⚠️  No API keys found. Attempting to use Ollama at \(ollamaURL)...")
    print("   Set OPENAI_API_KEY or ANTHROPIC_API_KEY environment variables to use cloud APIs")
    print("   Or ensure Ollama is running locally\n")
    return OllamaProvider(model: ollamaModel, baseURL: ollamaURL)
}

// MARK: - Entry Point

if #available(macOS 10.15, *) {
    Task {
        let llmProvider = createLLMProvider()
        
        do {
            await runTests(llmProvider: llmProvider)
        } catch {
            print("\n❌ Error running tests: \(error.localizedDescription)")
            print("\n💡 Tips:")
            print("   - For OpenAI: export OPENAI_API_KEY='your-key'")
            print("   - For Anthropic: export ANTHROPIC_API_KEY='your-key'")
            print("   - For Ollama: Ensure Ollama is running (brew install ollama && ollama serve)")
            print("   - Or use MockLLMProvider for testing structure")
            exit(1)
        }
        
        exit(0)
    }
    RunLoop.main.run()
} else {
    print("❌ Requires macOS 10.15+")
    exit(1)
}




