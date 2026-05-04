import SwiftUI

struct RecipesListView: View {
    @StateObject private var viewModel = RecipesViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                // Горизонтальный скролл категорий
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryButton(title: "Все", isSelected: viewModel.selectedCategory == nil) {
                            viewModel.filterByCategory(nil)
                        }
                        ForEach(viewModel.categories, id: \.self) { cat in
                            CategoryButton(title: cat.capitalized, isSelected: viewModel.selectedCategory == cat) {
                                viewModel.filterByCategory(cat)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    Text(error).foregroundColor(.red)
                    Spacer()
                } else {
                    List(viewModel.recipes) { recipe in
                        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.name)
                                    .font(.headline)
                                if let desc = recipe.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                if let cat = recipe.category {
                                    Text("Категория: \(cat)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Рецепты")
            .onAppear {
                viewModel.loadRecipes()
            }
        }
    }
}

// Вспомогательная кнопка категории
struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
