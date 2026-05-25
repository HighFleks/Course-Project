import SwiftUI
import Combine

@MainActor
class RecipeDetailViewModel: ObservableObject {
    @Published var isFavorite = false
    @Published var statusMessage: String?
    @Published var isError = false
    @Published var didDelete = false

    private let service = APIService.shared
    var recipe: Recipe?
    private let plannedVM = PlannedRecipesViewModel.shared

    func deleteRecipe(recipeId: Int) {
        Task {
            do {
                _ = try await service.request(method: "DELETE", path: "/api/recipes/\(recipeId)")
                if let recipe = recipe {
                    plannedVM.remove(recipe: recipe)
                }
                statusMessage = "Рецепт удалён."
                isError = false
                didDelete = true
            } catch {
                statusMessage = "Не удалось удалить рецепт."
                isError = true
            }
        }
    }

    func checkIfFavorite(recipeId: Int) {
        Task {
            do {
                let data = try await service.get(path: "/api/favorites/")
                let ids = try JSONDecoder().decode([Int].self, from: data)
                isFavorite = ids.contains(recipeId)
            } catch {}
        }
    }

    func toggleFavorite(recipeId: Int) {
        Task {
            do {
                if isFavorite {
                    _ = try await service.request(method: "DELETE", path: "/api/favorites/\(recipeId)")
                    isFavorite = false
                } else {
                    struct AddFav: Codable { let recipe_id: Int }
                    _ = try await service.request(method: "POST", path: "/api/favorites/", body: AddFav(recipe_id: recipeId))
                    isFavorite = true
                }
            } catch {
                statusMessage = "Ошибка избранного"
                isError = true
            }
        }
    }

    func cookRecipe(recipeId: Int) {
        Task {
            do {
                _ = try await service.request(method: "POST", path: "/api/recipes/\(recipeId)/cook")
                // Если рецепт был в плане приготовления - убираем его оттуда
                if let recipe = recipe {
                    plannedVM.remove(recipe: recipe)
                }
                statusMessage = "Блюдо приготовлено! Ингредиенты списаны."
                isError = false
            } catch let error as APIError {
                if case .serverError(let detail) = error, detail.contains("Недостаточно ингредиентов") {
                    // Переносим недостающее в список покупок
                    do {
                        let body = GenerateShoppingListRequest(recipe_ids: [recipeId])
                        _ = try await service.request(method: "POST", path: "/api/shopping-list/generate", body: body)
                        statusMessage = "Недостающие ингредиенты добавлены в список покупок."
                    } catch {
                        statusMessage = "Ошибка при создании списка покупок."
                    }
                } else {
                    statusMessage = "Ошибка: \(error.localizedDescription)"
                }
                isError = true
            } catch {
                statusMessage = "Неизвестная ошибка"
                isError = true
            }
        }
    }
    
    func planRecipe(recipeId: Int) {
        Task {
            do {
                let body = GenerateShoppingListRequest(recipe_ids: [recipeId])
                _ = try await service.request(method: "POST", path: "/api/shopping-list/generate", body: body)
                // Добавляем в запланированные
                if let recipe = recipe {
                    plannedVM.add(recipe: recipe)
                }
                statusMessage = "Рецепт запланирован! Недостающие ингредиенты добавлены в список покупок."
                isError = false
            } catch {
                statusMessage = "Ошибка планирования"
                isError = true
            }
        }
    }
}

