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

// MARK: - Ответы
struct UserResponse: Codable, Identifiable {
    let id: Int
    let email: String
}

struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
}
