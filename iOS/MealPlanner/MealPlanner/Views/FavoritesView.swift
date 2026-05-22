import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red)
                } else if viewModel.favoriteRecipes.isEmpty {
                    Text("У вас пока нет избранных рецептов.")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(viewModel.favoriteRecipes) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                VStack(alignment: .leading) {
                                    Text(recipe.name).font(.headline)
                                    if let desc = recipe.description {
                                        Text(desc).font(.subheadline).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("Избранное")
            .onAppear {
                viewModel.loadFavorites()
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let recipe = viewModel.favoriteRecipes[index]
            viewModel.removeFromFavorites(recipeId: recipe.id)
        }
    }
}
