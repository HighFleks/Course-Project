import Foundation

struct RecipeIngredient: Codable, Identifiable {
    let id: Int
    let ingredient_id: Int
    let quantity: Double
    let ingredient: Ingredient   // вложенный объект ингредиента
}
