import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(recipe.name)
                    .font(.largeTitle)
                    .bold()

                if let description = recipe.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                }

                if let category = recipe.category {
                    Text("Категория: \(category)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }

                if let instructions = recipe.instructions, !instructions.isEmpty {
                    Text("Инструкция:")
                        .font(.headline)
                    Text(instructions)
                        .font(.body)
                }

                if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                    Text("Ингредиенты:")
                        .font(.headline)
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

                Spacer()
            }
            .padding()
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
