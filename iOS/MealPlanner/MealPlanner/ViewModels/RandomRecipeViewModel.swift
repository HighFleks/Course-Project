import Foundation
import SwiftUI
import Combine

@MainActor
class RandomRecipeViewModel: ObservableObject {
    @Published var recipe: Recipe?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = APIService.shared

    func loadRandom() {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                let data = try await service.get(path: "/api/recipes/random-suggestion")
                let decoder = JSONDecoder()
                recipe = try decoder.decode(Recipe.self, from: data)
            } catch {
                errorMessage = "Нет доступных рецептов"
            }
        }
    }
}
