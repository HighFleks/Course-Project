import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case unauthorized
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный адрес сервера"
        case .requestFailed(let inner):
            return "Ошибка сети: \(inner.localizedDescription)"
        case .invalidResponse:
            return "Неверный ответ сервера"
        case .unauthorized:
            return "Сессия истекла. Войдите снова."
        case .serverError(let raw):
            // Сервер возвращает JSON вида {"detail": "..."} — попробуем достать читаемый текст.
            if let data = raw.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                return detail
            }
            return raw
        }
    }
}

extension Notification.Name {
    // Сессия инвалидирована (например, сервер вернул 401 или пользователь нажал «Выйти»).
    static let sessionDidExpire = Notification.Name("MealPlanner.sessionDidExpire")
    // Пользователь успешно вошёл/зарегистрировался — показать главный экран.
    static let userDidLogin = Notification.Name("MealPlanner.userDidLogin")
}

class APIService {
    static let shared = APIService()

    // Базовый URL сервера.
    // Для симулятора используется localhost,
    // для реального устройства — IP компьютера в локальной сети
    private static let simulatorHost = "127.0.0.1"
    private static let deviceHost = "172.20.10.4"
    private static let serverPort = 8000

    #if targetEnvironment(simulator)
    private let baseURL = "http://\(APIService.simulatorHost):\(APIService.serverPort)"
    #else
    private let baseURL = "http://\(APIService.deviceHost):\(APIService.serverPort)"
    #endif

    private var authToken: String?
    
    var currentUserId: Int?
    private let tokenKey = "authToken"
    private let userIdKey = "currentUserId"

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

    // MARK: - Профиль: статистика и смена пароля
    func getUserStats() async throws -> UserStats {
        let data = try await get(path: "/api/auth/me/stats")
        return try JSONDecoder().decode(UserStats.self, from: data)
    }

    func changePassword(old: String, new: String) async throws {
        let body = ChangePasswordRequest(old_password: old, new_password: new)
        _ = try await request(method: "PUT", path: "/api/auth/me/password", body: body)
    }

    // MARK: - Выход из аккаунта
    func logout() {
        clearSession()
        NotificationCenter.default.post(name: .sessionDidExpire, object: nil)
    }

    // Пути, для которых 401 — это нормальный ответ (ошибочные креды при логине),
    // поэтому авто-логаут не нужен.
    private static let authPaths: Set<String> = ["/api/auth/login", "/api/auth/register"]

    private func handleUnauthorized(path: String) {
        // Если это сам логин/регистрация — не дёргаем авто-логаут.
        guard !APIService.authPaths.contains(path) else { return }
        // Если токена не было — тоже нечего инвалидировать.
        guard authToken != nil else { return }
        clearSession()
        NotificationCenter.default.post(name: .sessionDidExpire, object: nil)
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
            await MainActor.run { self.handleUnauthorized(path: path) }
            throw APIError.unauthorized
        }
        if httpResponse.statusCode >= 400 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError.serverError(errorMessage)
        }
        return data
    }

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
        if httpResponse.statusCode == 401 {
            await MainActor.run { self.handleUnauthorized(path: path) }
            throw APIError.unauthorized
        }
        if httpResponse.statusCode >= 400 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError.serverError(errorMessage)
        }
        return data
    }
    
    func fetchAndSaveUserId() {
        Task {
            if let user = try? await getCurrentUser() {
                self.currentUserId = user.id
            }
        }
    }
    
    func saveSession(token: String, userId: Int?) {
        KeychainStore.save(token, key: tokenKey)
        if let userId = userId {
            UserDefaults.standard.set(userId, forKey: userIdKey)
        }
        authToken = token
        currentUserId = userId
    }

    func restoreSession() -> Bool {
        if let legacy = UserDefaults.standard.string(forKey: tokenKey) {
            KeychainStore.save(legacy, key: tokenKey)
            UserDefaults.standard.removeObject(forKey: tokenKey)
        }
        guard let token = KeychainStore.read(key: tokenKey) else { return false }
        authToken = token
        let storedId = UserDefaults.standard.integer(forKey: userIdKey)
        currentUserId = storedId == 0 ? nil : storedId
        return true
    }

    func clearSession() {
        KeychainStore.delete(key: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        authToken = nil
        currentUserId = nil
    }
}
