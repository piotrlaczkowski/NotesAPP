import Foundation

/// Manages custom categories that users can create, edit, and delete
actor CategoryManager {
    static let shared = CategoryManager()
    
    private let defaults = UserDefaults.standard
    private let categoriesKey = "customCategories"
    
    private var defaultCategories = [
        "Research Paper",
        "Code Repository",
        "Tutorial",
        "Article",
        "Documentation",
        "News",
        "Video",
        "Podcast",
        "Book",
        "General"
    ]
    
    private init() {}
    
    /// Get all available categories (default + custom)
    func getAllCategories() -> [String] {
        let customCategories = getCustomCategories()
        let allCategories = defaultCategories + customCategories
        // Remove duplicates and sort
        return Array(Set(allCategories)).sorted()
    }
    
    /// Get only custom categories
    func getCustomCategories() -> [String] {
        return defaults.stringArray(forKey: categoriesKey) ?? []
    }
    
    /// Add a custom category
    func addCategory(_ category: String) {
        var categories = getCustomCategories()
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty,
              !defaultCategories.contains(trimmed),
              !categories.contains(trimmed) else {
            return
        }
        
        categories.append(trimmed)
        defaults.set(categories, forKey: categoriesKey)
    }
    
    /// Remove a custom category (cannot remove default categories)
    func removeCategory(_ category: String) {
        guard !defaultCategories.contains(category) else {
            return // Cannot remove default categories
        }
        
        var categories = getCustomCategories()
        categories.removeAll { $0 == category }
        defaults.set(categories, forKey: categoriesKey)
    }
    
    /// Rename a custom category
    func renameCategory(_ oldName: String, to newName: String) {
        guard !defaultCategories.contains(oldName) else {
            return // Cannot rename default categories
        }
        
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var categories = getCustomCategories()
        guard let index = categories.firstIndex(of: oldName) else { return }
        
        categories[index] = trimmed
        defaults.set(categories, forKey: categoriesKey)
    }
    
    /// Check if a category is custom (not a default)
    func isCustomCategory(_ category: String) -> Bool {
        return !defaultCategories.contains(category)
    }
}

