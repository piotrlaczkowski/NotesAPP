import XCTest
@testable import NotesApp

final class LLMManagerTests: XCTestCase {
    
    func testGeminiConfiguration() {
        // Given
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "useGemini")
        defaults.set("test-api-key", forKey: "geminiApiKey")
        
        // When
        let manager = LLMManager.shared
        manager.refreshGeminiConfig()
        
        // Then
        XCTAssertNotNil(manager.geminiService, "Gemini service should be initialized when enabled and key is present")
        XCTAssertTrue(manager.isModelLoaded, "Model should be considered loaded when Gemini is configured")
    }
    
    func testGeminiConfigurationDisabled() {
        // Given
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "useGemini")
        defaults.set("test-api-key", forKey: "geminiApiKey")
        
        // When
        let manager = LLMManager.shared
        manager.refreshGeminiConfig()
        
        // Then
        XCTAssertNil(manager.geminiService, "Gemini service should be nil when disabled")
    }
    
    func testGeminiConfigurationNoKey() {
        // Given
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "useGemini")
        defaults.set("", forKey: "geminiApiKey")
        
        // When
        let manager = LLMManager.shared
        manager.refreshGeminiConfig()
        
        // Then
        XCTAssertNil(manager.geminiService, "Gemini service should be nil when key is empty")
    }
}
