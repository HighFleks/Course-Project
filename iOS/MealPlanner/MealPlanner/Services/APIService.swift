import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case unauthorized
    case serverError(String)
}

class APIService {
    static let shared = APIService()
    // Замени на свой адрес, если сервер запущен не на localhost
    #if targetEnvironment(simulator)
    private let baseURL = "http://127.0.0.1:8000"
    #else
    private let baseURL = "http://172.20.10.4:8000"
    #endif
    private var authToken: String?

    private init() {}

    // MARK: - Установка токена после логина
    func setToken(_ token: String) {
        self.authToken = token
    }

    // MARK: - Авторизация
    func register(email: String, password: String) async throws -> UserResponse {
        let body = RegisterRequest(email: email, password: password)
        let data = try await request(method: "POST", path: "/api/auth/register", body: body)
        return try JSONDecoder().decode(UserResponse.self, from: data)
    }

    func login(email: String, password: String) async throws -> TokenResponse {
        let body = LoginRequest(email: email, password: password)
        let data = try await request(method: "POST", path: "/api/auth/login", body: body)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    // MARK: - Защищённый запрос (получение текущего пользователя)
    func getCurrentUser() async throws -> UserResponse {
        let data = try await request(method: "GET", path: "/api/auth/me")
        return try JSONDecoder().decode(UserResponse.self, from: data)
    }

    // MARK: - Внутренний метод для HTTP-запросов
    func request(method: String, path: String, body: Codable? = nil) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            urlRequest.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        if httpResponse.statusCode >= 400 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError.serverError(errorMessage)
        }
        return data
    }
    
    // Новый метод для GET с queryItems
    func get(path: String, queryItems: [URLQueryItem]? = nil) async throws -> Data {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if httpResponse.statusCode == 401 { throw APIError.unauthorized }
        if httpResponse.statusCode >= 400 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError.serverError(errorMessage)
        }
        return data
    }
}
