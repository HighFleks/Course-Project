import Foundation
import SwiftUI
import Combine

struct RecipeIngredientDraft: Identifiable {
    let id = UUID()
    var ingredient: Ingredient
    var quantity: Double = 0
}

@MainActor
class RecipeFormViewModel: ObservableObject {
    @Published var name = ""
    @Published var description = ""
    @Published var instructions = ""
    @Published var category = "завтрак"
    @Published var isPublic = true
    @Published var ingredients: [RecipeIngredientDraft] = []
    @Published var searchResults: [Ingredient] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    let categories = ["завтрак", "обед", "ужин", "десерт", "салат", "суп", "выпечка", "закуска", "напиток"]
    private let service = APIService.shared

    // MARK: - Загрузка данных для редактирования
    func loadRecipe(_ recipe: Recipe) {
        name = recipe.name
        description = recipe.description ?? ""
        instructions = recipe.instructions ?? ""
        category = recipe.category ?? "завтрак"
        isPublic = recipe.is_public ?? true
        if let ings = recipe.ingredients {
            ingredients = ings.map { RecipeIngredientDraft(ingredient: $0.ingredient, quantity: $0.quantity) }
        }
    }

    func addIngredient(_ ingredient: Ingredient, quantity: Double) {
        ingredients.append(RecipeIngredientDraft(ingredient: ingredient, quantity: quantity))
    }

    func removeIngredient(_ draft: RecipeIngredientDraft) {
        ingredients.removeAll { $0.id == draft.id }
    }

    func search(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { searchResults = []; return }
        Task {
            do {
                let data = try await service.get(path: "/api/ingredients/search", queryItems: [URLQueryItem(name: "q", value: trimmed)])
                searchResults = try JSONDecoder().decode([Ingredient].self, from: data)
            } catch { searchResults = [] }
        }
    }

    // MARK: - Сохранение (создание / обновление)
    func save(existingRecipeId: Int? = nil) {
            Task {
                isLoading = true
                errorMessage = nil
                successMessage = nil
                defer { isLoading = false }

                guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                    errorMessage = "Введите название"
                    return
                }
                guard !ingredients.isEmpty else {
                    errorMessage = "Добавьте хотя бы один ингредиент"
                    return
                }

                let body = CreateRecipeRequest(
                    name: name,
                    description: description,
                    instructions: instructions,
                    category: category,
                    is_public: isPublic,
                    ingredients: ingredients.map {
                        CreateRecipeIngredient(ingredient_id: $0.ingredient.id, quantity: $0.quantity)
                    }
                )

                do {
                    if let id = existingRecipeId {
                        _ = try await service.request(method: "PUT", path: "/api/recipes/\(id)", body: body)
                    } else {
                        _ = try await service.request(method: "POST", path: "/api/recipes/", body: body)
                    }
                    successMessage = existingRecipeId == nil ? "Рецепт создан!" : "Рецепт обновлён!"
                } catch {
                    errorMessage = "Ошибка сохранения: \(error.localizedDescription)"
                }
            }
        }
}

struct CreateRecipeRequest: Codable {
    let name: String; let description: String?; let instructions: String?; let category: String?; let is_public: Bool; let ingredients: [CreateRecipeIngredient]
}
struct CreateRecipeIngredient: Codable {
    let ingredient_id: Int; let quantity: Double
}
