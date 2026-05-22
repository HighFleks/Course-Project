import Foundation
import SwiftUI
import Combine

@MainActor
class FavoritesViewModel: ObservableObject {
    @Published var favoriteRecipes: [Recipe] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = APIService.shared

    func loadFavorites() {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                let idsData = try await service.get(path: "/api/favorites/")
                let favoriteIds = try JSONDecoder().decode([Int].self, from: idsData)

                var loadedRecipes: [Recipe] = []
                for id in favoriteIds {
                    if let recipeData = try? await service.get(path: "/api/recipes/\(id)"),
                       let recipe = try? JSONDecoder().decode(Recipe.self, from: recipeData) {
                        loadedRecipes.append(recipe)
                    }
                }
                self.favoriteRecipes = loadedRecipes
            } catch {
                errorMessage = "Ошибка загрузки избранного: \(error.localizedDescription)"
            }
        }
    }

    func removeFromFavorites(recipeId: Int) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                _ = try await service.request(method: "DELETE", path: "/api/favorites/\(recipeId)")
                favoriteRecipes.removeAll { $0.id == recipeId }
            } catch {
                errorMessage = "Ошибка удаления из избранного: \(error.localizedDescription)"
            }
        }
    }
}
