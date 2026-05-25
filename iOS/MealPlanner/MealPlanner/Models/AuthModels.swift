import Foundation

// MARK: - Запросы
struct RegisterRequest: Codable {
    let email: String
    let password: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct ChangePasswordRequest: Codable {
    let old_password: String
    let new_password: String
}

struct UserResponse: Codable, Identifiable {
    let id: Int
    let email: String
    let created_at: String?
}

struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
}

struct UserStats: Codable {
    let recipes_created: Int
    let favorites_count: Int
    let inventory_items: Int
    let shopping_items: Int
}
