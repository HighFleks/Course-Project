import Foundation

struct Ingredient: Codable, Identifiable {
    let id: Int
    let name: String
    let unit: String?
}
