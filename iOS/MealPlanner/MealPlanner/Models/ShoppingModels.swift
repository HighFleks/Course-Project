import Foundation

// Элемент списка покупок (ответ сервера)
struct ShoppingListItem: Codable, Identifiable {
    let id: Int
    let ingredient_id: Int
    let quantity: Double
    let is_purchased: Bool
    let ingredient: Ingredient
}

// Запрос на ручное добавление
struct ShoppingItemCreateRequest: Codable {
    let ingredient_id: Int
    let quantity: Double
}

// Запрос на обновление элемента (PUT)
struct ShoppingItemUpdateRequest: Codable {
    let quantity: Double?
    let is_purchased: Bool?
}

// Запрос на генерацию списка покупок
struct GenerateShoppingListRequest: Codable {
    let recipe_ids: [Int]
}
