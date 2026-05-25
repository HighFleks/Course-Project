import SwiftUI

struct PlannedRecipesView: View {
    @ObservedObject private var viewModel = PlannedRecipesViewModel.shared

    var body: some View {
        Group {
            if viewModel.plannedRecipes.isEmpty {
                Text("Пока ничего не запланировано")
                    .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(viewModel.plannedRecipes) { plan in
                        NavigationLink(destination: RecipeDetailView(recipe: plan.recipe)) {
                            VStack(alignment: .leading) {
                                Text(plan.recipe.name).font(.headline)
                                if let cat = plan.recipe.category {
                                    Text(cat).font(.caption).foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.remove(recipe: viewModel.plannedRecipes[index].recipe)
                        }
                    }
                }
            }
        }
        .navigationTitle("План приготовления")
    }
}
