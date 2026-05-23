import SwiftUI
import Combine

struct RandomRecipeView: View {
    @StateObject private var viewModel = AvailableRecipesViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            } else {
                List(viewModel.recipes) { recipe in
                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                        VStack(alignment: .leading) {
                            Text(recipe.name).font(.headline)
                            if let desc = recipe.description { Text(desc).font(.subheadline).foregroundColor(.secondary) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Что приготовить?")
        .onAppear { viewModel.loadAvailableRecipes() }
    }
}

@MainActor
class AvailableRecipesViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadAvailableRecipes() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let data = try await APIService.shared.get(path: "/api/recipes/available")
                recipes = try JSONDecoder().decode([Recipe].self, from: data)
            } catch {
                errorMessage = "Нет доступных рецептов. Добавьте больше продуктов в инвентарь."
            }
        }
    }
}
