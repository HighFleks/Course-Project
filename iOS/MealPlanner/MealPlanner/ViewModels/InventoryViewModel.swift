import Foundation
import SwiftUI
import Combine

@MainActor
class InventoryViewModel: ObservableObject {
    @Published var items: [InventoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = APIService.shared

    func loadInventory() {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                let data = try await service.get(path: "/api/inventory/")
                let decoder = JSONDecoder()
                items = try decoder.decode([InventoryItem].self, from: data)
            } catch {
                errorMessage = "Ошибка загрузки инвентаря: \(error.localizedDescription)"
            }
        }
    }

    func addItem(ingredientID: Int, quantity: Double) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            let body = InventoryItemRequest(ingredient_id: ingredientID, quantity: quantity)
            do {
                let data = try await service.request(method: "POST", path: "/api/inventory/", body: body)
                let newItem = try JSONDecoder().decode(InventoryItem.self, from: data)
                // Обновим локальный список
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

    func updateItem(ingredientID: Int, newQuantity: Double) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            let body = InventoryUpdateRequest(quantity: newQuantity)
            do {
                let data = try await service.request(method: "PUT", path: "/api/inventory/\(ingredientID)", body: body)
                let updatedItem = try JSONDecoder().decode(InventoryItem.self, from: data)
                if let index = items.firstIndex(where: { $0.ingredient_id == ingredientID }) {
                    items[index] = updatedItem
                }
            } catch {
                errorMessage = "Ошибка обновления: \(error.localizedDescription)"
            }
        }
    }

    func deleteItem(ingredientID: Int) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                _ = try await service.request(method: "DELETE", path: "/api/inventory/\(ingredientID)")
                items.removeAll { $0.ingredient_id == ingredientID }
            } catch {
                errorMessage = "Ошибка удаления: \(error.localizedDescription)"
            }
        }
    }
}
