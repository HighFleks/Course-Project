import Foundation

struct PlannedRecipe: Codable, Identifiable {
    var id: Int { recipe.id }
    let recipe: Recipe
    let addedDate: Date
}
