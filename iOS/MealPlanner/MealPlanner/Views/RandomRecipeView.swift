import SwiftUI

struct RandomRecipeView: View {
    @StateObject private var viewModel = RandomRecipeViewModel()

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let recipe = viewModel.recipe {
                RecipeDetailView(recipe: recipe)
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            } else {
                Button("Предложить рецепт") {
                    viewModel.loadRandom()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Что приготовить?")
        .onAppear {
            viewModel.loadRandom()
        }
    }
}
