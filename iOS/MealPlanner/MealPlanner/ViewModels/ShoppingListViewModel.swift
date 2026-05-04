import Foundation
import SwiftUI
import Combine

@MainActor
class ShoppingListViewModel: ObservableObject {
    @Published var items: [ShoppingListItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = APIService.shared

    // Загрузка текущего списка
    func loadShoppingList() {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                let data = try await service.get(path: "/api/shopping-list/")
                let decoder = JSONDecoder()
                items = try decoder.decode([ShoppingListItem].self, from: data)
            } catch {
                errorMessage = "Ошибка загрузки списка покупок: \(error.localizedDescription)"
            }
        }
    }

    // Генерация списка на основе рецептов
    func generateFromRecipes(recipeIDs: [Int]) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            let body = GenerateShoppingListRequest(recipe_ids: recipeIDs)
            do {
                let data = try await service.request(method: "POST", path: "/api/shopping-list/generate", body: body)
                let decoder = JSONDecoder()
                items = try decoder.decode([ShoppingListItem].self, from: data)
            } catch {
                errorMessage = "Ошибка генерации списка: \(error.localizedDescription)"
            }
        }
    }

    // Ручное добавление одного продукта
    func addItem(ingredientID: Int, quantity: Double) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            let body = ShoppingItemCreateRequest(ingredient_id: ingredientID, quantity: quantity)
            do {
                let data = try await service.request(method: "POST", path: "/api/shopping-list/items", body: body)
                let newItem = try JSONDecoder().decode(ShoppingListItem.self, from: data)
                if let index = items.firstIndex(where: { $0.ingredient_id == ingredientID }) {
                    items[index] = newItem
                } else {
                    items.append(newItem)
                }
            } catch {
                errorMessage = "Ошибка добавления: \(error.localizedDescription)"
            }
        }
    }

    // Обновить количество или отметить купленным
    func updateItem(ingredientID: Int, quantity: Double?, isPurchased: Bool?) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            let body = ShoppingItemUpdateRequest(quantity: quantity, is_purchased: isPurchased)
            do {
                let data = try await service.request(method: "PUT", path: "/api/shopping-list/items/\(ingredientID)", body: body)
                let updated = try JSONDecoder().decode(ShoppingListItem.self, from: data)
                if let index = items.firstIndex(where: { $0.ingredient_id == ingredientID }) {
                    items[index] = updated
                }
            } catch {
                errorMessage = "Ошибка обновления: \(error.localizedDescription)"
            }
        }
    }

    // Удалить позицию
    func deleteItem(ingredientID: Int) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                _ = try await service.request(method: "DELETE", path: "/api/shopping-list/items/\(ingredientID)")
                items.removeAll { $0.ingredient_id == ingredientID }
            } catch {
                errorMessage = "Ошибка удаления: \(error.localizedDescription)"
            }
        }
    }

    // Checkout — перенести купленное в инвентарь
    func checkout() {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                let data = try await service.request(method: "POST", path: "/api/shopping-list/checkout")
                let decoder = JSONDecoder()
                items = try decoder.decode([ShoppingListItem].self, from: data)
            } catch {
                errorMessage = "Ошибка переноса в инвентарь: \(error.localizedDescription)"
            }
        }
    }
}
