import Foundation

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
    let created_by_user_id: Int?
}
