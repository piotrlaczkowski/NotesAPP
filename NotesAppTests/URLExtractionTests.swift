import XCTest
@testable import NotesApp
import Foundation

@MainActor
class URLExtractionTests: XCTestCase {
    
    // Expected results
    let expectedResults: [Int: (title: String, description: String, tags: [String])] = [
        1: ("NeuralForecast", "A comprehensive collection of neural forecasting models focusing on performance, usability, and scalability. Includes popular architectures such as RNNs, LSTMs, Transformers, and TimeLLM for time-series forecasting.", ["time-series", "forecasting", "deep-learning", "transformers", "neural-networks", "python"]),
        2: ("Tiny Recursive Models (TRM)", "A lightweight implementation of the TRM (Tiny Recursive Model) architecture based on the research paper \"Tiny Recursive Models\" (arXiv:2510.04871v1).", ["machine-learning", "deep-learning", "transformers", "research", "recursive-models"]),
        3: ("Granite Docling 258M WebGPU", "A Hugging Face Space by IBM Granite that converts document images into HTML using 🤗 Transformers.js. Runs directly in the browser with WebGPU acceleration.", ["document-processing", "transformers", "webgpu", "ocr", "html", "huggingface"]),
        4: ("Enterprise Deep Research", "A Salesforce AI Research project focused on building deep research assistants that can reason over enterprise data. Combines LLMs, retrieval systems, and structured reasoning.", ["enterprise-ai", "llm", "retrieval-augmented-generation", "deep-research", "salesforce"]),
        5: ("Open Agent Builder", "An open-source framework to design, compose, and deploy AI agents powered by Firecrawl. Allows building autonomous or semi-autonomous systems using modular blocks.", ["ai-agents", "open-source", "automation", "firecrawl", "llm"]),
        6: ("Efficient Memory in Long Context Transformers", "A research paper exploring methods for improving memory and efficiency in handling long sequences with transformer architectures.", ["transformers", "memory", "long-context", "ai-research", "nlp"]),
        7: ("Adaptive Fine-Tuning Strategies for Large Language Models", "Recent research published on Hugging Face Papers discussing methods to fine-tune LLMs efficiently across diverse tasks and data domains.", ["fine-tuning", "large-language-models", "huggingface", "optimization", "ai-research"]),
        8: ("LEANN (Lightweight Efficient Attention Neural Network)", "A GitHub project introducing LEANN — a lightweight attention-based neural network designed for efficiency in edge and resource-constrained environments.", ["attention-models", "lightweight-ai", "edge-ai", "neural-networks", "efficiency"])
    ]
    
    func testURLExtraction() async throws {
        // Read URLs from TODO.md
        let testBundle = Bundle(for: type(of: self))
        guard let projectRoot = testBundle.bundlePath.components(separatedBy: "/").dropLast(3).joined(separator: "/").isEmpty ? nil : URL(fileURLWithPath: "/" + testBundle.bundlePath.components(separatedBy: "/").dropLast(3).joined(separator: "/")) else {
            XCTFail("Could not find project root")
            return
        }
        
        let todoPath = projectRoot.appendingPathComponent("TODO.md")
        guard let todoContent = try? String(contentsOf: todoPath, encoding: .utf8) else {
            XCTFail("Could not read TODO.md")
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
        
        XCTAssertFalse(urls.isEmpty, "No URLs found in TODO.md")
        
        // Check if LLM is loaded
        let llmManager = LLMManager.shared
        guard llmManager.isModelLoaded else {
            XCTFail("LLM model is not loaded. Please load a model in the app first.")
            return
        }
        
        // Test each URL
        for (number, url) in urls {
            print("\n📋 Testing \(number): \(url.absoluteString)")
            
            // Extract content
            let contentExtractor = URLContentExtractor.shared
            let result = try await contentExtractor.extractContentWithMetadata(from: url)
            let content = result.content
            let metadata = result.metadata
            
            // Build prompt
            let prompt = buildExtractionPrompt(url: url, content: content, metadata: metadata.contextString())
            
            // Call LLM
            let response = try await llmManager.generateChatResponse(prompt: prompt, context: nil)
            
            // Parse response
            let extractedMetadata = parseJSONResponse(response) ?? parseTextResponse(response)
            
            // Compare with expected
            if let expected = expectedResults[number] {
                print("   Expected Title: \(expected.title)")
                print("   Actual Title: \(extractedMetadata.title ?? "N/A")")
                print("   Expected Tags: \(expected.tags.joined(separator: ", "))")
                print("   Actual Tags: \(extractedMetadata.tags.joined(separator: ", "))")
                
                // Check title match
                if let actualTitle = extractedMetadata.title {
                    XCTAssertTrue(actualTitle.lowercased().contains(expected.title.lowercased()) || expected.title.lowercased().contains(actualTitle.lowercased()),
                                "Title mismatch for URL \(number)")
                }
                
                // Check tags (at least 3 should match)
                let expectedTagsSet = Set(expected.tags.map { $0.lowercased() })
                let actualTagsSet = Set(extractedMetadata.tags.map { $0.lowercased() })
                let commonTags = expectedTagsSet.intersection(actualTagsSet)
                XCTAssertGreaterThanOrEqual(commonTags.count, 3, "Not enough tag matches for URL \(number)")
            }
        }
    }
    
    private func buildExtractionPrompt(url: URL, content: String, metadata: String?) -> String {
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
        
        let maxContentLength = 3000
        let contentToInclude: String
        if content.count > maxContentLength {
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
    
    private func parseJSONResponse(_ response: String) -> (title: String?, description: String?, tags: [String])? {
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let jsonStart = jsonString.range(of: "{"),
           let jsonEnd = jsonString.range(of: "}", options: .backwards) {
            let jsonRange = jsonStart.lowerBound..<jsonEnd.upperBound
            jsonString = String(jsonString[jsonRange])
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let title = json?["title"] as? String
            let description = json?["description"] as? String
            let tags = json?["tags"] as? [String] ?? []
            return (title, description, tags)
        } catch {
            return nil
        }
    }
    
    private func parseTextResponse(_ response: String) -> (title: String?, description: String?, tags: [String]) {
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
        
        return (title, description, tags)
    }
}

