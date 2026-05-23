import SwiftUI
import Combine

struct RecipeDetailView: View {
    let recipe: Recipe
    @StateObject private var viewModel = RecipeDetailViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(recipe.name)
                    .font(.largeTitle).bold()

                if let description = recipe.description, !description.isEmpty {
                    Text(description).font(.body)
                }
                if let category = recipe.category {
                    Text("Категория: \(category)").font(.subheadline).foregroundColor(.blue)
                }
                if let instructions = recipe.instructions, !instructions.isEmpty {
                    Text("Инструкция:").font(.headline)
                    Text(instructions).font(.body)
                }
                if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                    Text("Ингредиенты:").font(.headline)
                    ForEach(ingredients) { item in
                        HStack {
                            Text(item.ingredient.name)
                            Spacer()
                            Text("\(item.quantity, specifier: "%.1f") \(item.ingredient.unit ?? "")")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Блок действий
                VStack(spacing: 12) {
                    // Кнопка "Приготовить" — главное действие
                    Button(action: { viewModel.cookRecipe(recipeId: recipe.id) }) {
                        Label("Приготовить", systemImage: "flame")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    // Кнопка "Запланировать" — добавить недостающее в список покупок
                    Button(action: { viewModel.planRecipe(recipeId: recipe.id) }) {
                        Label("Запланировать", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    // Кнопка "В избранное"
                    Button(action: { viewModel.toggleFavorite(recipeId: recipe.id) }) {
                        Label(viewModel.isFavorite ? "В избранном" : "В избранное",
                              systemImage: viewModel.isFavorite ? "star.fill" : "star")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    // Кнопка "Редактировать" (только для автора)
                    if let currentUserId = APIService.shared.currentUserId,
                       let authorId = recipe.created_by_user_id,
                       currentUserId == authorId {
                        NavigationLink(destination: RecipeFormView(recipeToEdit: recipe)) {
                            Label("Редактировать", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top)

                if let message = viewModel.statusMessage {
                    Text(message)
                        .foregroundColor(viewModel.isError ? .red : .green)
                        .padding(.top, 4)
                }
                if APIService.shared.currentUserId == recipe.created_by_user_id {
                    NavigationLink(destination: RecipeFormView(recipeToEdit: recipe)) {
                        Label("Редактировать", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.recipe = recipe
            viewModel.checkIfFavorite(recipeId: recipe.id)
        }
    }
}
