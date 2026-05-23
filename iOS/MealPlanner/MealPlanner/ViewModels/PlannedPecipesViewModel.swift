import Foundation
import SwiftUI
import Combine

@MainActor
class PlannedRecipesViewModel: ObservableObject {
    static let shared = PlannedRecipesViewModel()

    @Published var plannedRecipes: [PlannedRecipe] = []
    private let storageKey = "plannedRecipes"

    init() {
        load()
    }

    func add(recipe: Recipe) {
        guard !plannedRecipes.contains(where: { $0.recipe.id == recipe.id }) else { return }
        let newPlan = PlannedRecipe(recipe: recipe, addedDate: Date())
        plannedRecipes.append(newPlan)
        save()
    }

    func remove(recipe: Recipe) {
        plannedRecipes.removeAll { $0.recipe.id == recipe.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(plannedRecipes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([PlannedRecipe].self, from: data)
        else { return }
        plannedRecipes = saved
    }
}
