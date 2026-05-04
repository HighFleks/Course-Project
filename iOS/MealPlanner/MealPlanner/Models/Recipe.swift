import Foundation

// MARK: - Ингредиент в составе рецепта
struct RecipeIngredient: Codable, Identifiable {
    let id: Int
    let ingredient_id: Int
    let quantity: Double
    let ingredient: Ingredient   // вложенный объект ингредиента
}

// MARK: - Ингредиент из справочника
struct Ingredient: Codable, Identifiable {
    let id: Int
    let name: String
    let unit: String?
}

// MARK: - Рецепт
struct Recipe: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let instructions: String?
    let category: String?
    let image_url: String?
    let ingredients: [RecipeIngredient]?
    let is_public: Bool?
    let created_at: String?
    let updated_at: String?
}
