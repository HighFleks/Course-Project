import Foundation

// Позиция в инвентаре (ответ от сервера)
struct InventoryItem: Codable, Identifiable {
    let id: Int
    let ingredient_id: Int
    let quantity: Double
    let ingredient: Ingredient   // использует Ingredient из Recipe.swift
}

// Запрос на добавление/обновление
struct InventoryItemRequest: Codable {
    let ingredient_id: Int
    let quantity: Double
}

// Запрос на обновление количества (PUT)
struct InventoryUpdateRequest: Codable {
    let quantity: Double
}
