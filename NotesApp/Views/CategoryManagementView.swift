import SwiftUI

struct CategoryManagementView: View {
    @StateObject private var viewModel = CategoryManagementViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if viewModel.customCategories.isEmpty {
                        Text("No custom categories yet")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(viewModel.customCategories, id: \.self) { category in
                            CategoryRowView(category: category, viewModel: viewModel)
                        }
                    }
                } header: {
                    Text("Custom Categories")
                } footer: {
                    Text("Default categories cannot be edited or deleted. Only custom categories you create can be managed here.")
                }
                
                Section {
                    Button {
                        viewModel.showAddCategorySheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Category")
                        }
                    }
                }
            }
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddCategorySheet) {
                AddCategoryView(viewModel: viewModel)
            }
            .alert("Delete Category", isPresented: $viewModel.showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let category = viewModel.categoryToDelete {
                        Task {
                            await viewModel.deleteCategory(category)
                        }
                    }
                }
            } message: {
                if let category = viewModel.categoryToDelete {
                    Text("Are you sure you want to delete \"\(category)\"? Notes using this category will keep it, but you won't be able to assign it to new notes.")
                }
            }
            .task {
                await viewModel.loadCategories()
            }
        }
    }
}

struct CategoryRowView: View {
    let category: String
    @ObservedObject var viewModel: CategoryManagementViewModel
    @State private var showEditSheet = false
    
    var body: some View {
        HStack {
            Text(category)
            Spacer()
            Button {
                showEditSheet = true
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            
            Button(role: .destructive) {
                viewModel.categoryToDelete = category
                viewModel.showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .sheet(isPresented: $showEditSheet) {
            EditCategoryView(category: category, viewModel: viewModel)
        }
    }
}

struct AddCategoryView: View {
    @ObservedObject var viewModel: CategoryManagementViewModel
    @Environment(\.dismiss) var dismiss
    @State private var categoryName = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $categoryName)
                        .focused($isFocused)
                        .autocapitalization(.words)
                } header: {
                    Text("New Category")
                } footer: {
                    Text("Enter a name for your custom category")
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await viewModel.addCategory(categoryName)
                            if !viewModel.errorMessage.isEmpty {
                                dismiss()
                            }
                        }
                    }
                    .disabled(categoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
            .alert("Error", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
                Button("OK") {
                    viewModel.errorMessage = ""
                }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

struct EditCategoryView: View {
    let category: String
    @ObservedObject var viewModel: CategoryManagementViewModel
    @Environment(\.dismiss) var dismiss
    @State private var categoryName: String
    @FocusState private var isFocused: Bool
    
    init(category: String, viewModel: CategoryManagementViewModel) {
        self.category = category
        self.viewModel = viewModel
        self._categoryName = State(initialValue: category)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $categoryName)
                        .focused($isFocused)
                        .autocapitalization(.words)
                } header: {
                    Text("Edit Category")
                }
            }
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.renameCategory(category, to: categoryName)
                            if !viewModel.errorMessage.isEmpty {
                                dismiss()
                            }
                        }
                    }
                    .disabled(categoryName.trimmingCharacters(in: .whitespaces).isEmpty || categoryName == category)
                }
            }
            .onAppear {
                isFocused = true
            }
            .alert("Error", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
                Button("OK") {
                    viewModel.errorMessage = ""
                }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

@MainActor
class CategoryManagementViewModel: ObservableObject {
    @Published var customCategories: [String] = []
    @Published var showAddCategorySheet = false
    @Published var showDeleteAlert = false
    @Published var categoryToDelete: String?
    @Published var errorMessage = ""
    
    private let categoryManager = CategoryManager.shared
    
    func loadCategories() async {
        customCategories = await categoryManager.getCustomCategories()
    }
    
    func addCategory(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Category name cannot be empty"
            return
        }
        
        let allCategories = await categoryManager.getAllCategories()
        if allCategories.contains(trimmed) {
            errorMessage = "Category \"\(trimmed)\" already exists"
            return
        }
        
        await categoryManager.addCategory(trimmed)
        await loadCategories()
        errorMessage = ""
    }
    
    func deleteCategory(_ category: String) async {
        await categoryManager.removeCategory(category)
        await loadCategories()
        categoryToDelete = nil
        showDeleteAlert = false
    }
    
    func renameCategory(_ oldName: String, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Category name cannot be empty"
            return
        }
        
        let allCategories = await categoryManager.getAllCategories()
        if allCategories.contains(trimmed) && trimmed != oldName {
            errorMessage = "Category \"\(trimmed)\" already exists"
            return
        }
        
        await categoryManager.renameCategory(oldName, to: trimmed)
        await loadCategories()
        errorMessage = ""
    }
}

