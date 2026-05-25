import Foundation
import SwiftUI
import Combine

@MainActor
class RecipesViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var selectedCategory: String? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = APIService.shared

    func loadRecipes(category: String? = nil) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            let queryItems: [URLQueryItem]?
            if let category = category, !category.isEmpty {
                queryItems = [URLQueryItem(name: "category", value: category)]
            } else {
                queryItems = nil
            }

            do {
                let data = try await service.get(path: "/api/recipes/", queryItems: queryItems)
                let recipes = try JSONDecoder().decode([Recipe].self, from: data)
                self.recipes = recipes
            } catch {
                errorMessage = "Ошибка загрузки рецептов: \(error.localizedDescription)"
            }
        }
    }

    // Категории берём из общего справочника
    let categories = RecipeCategory.all

    func filterByCategory(_ category: String?) {
        selectedCategory = category
        loadRecipes(category: category)
    }
}
