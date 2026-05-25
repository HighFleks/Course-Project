import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoggedIn = false
    @Published var errorMessage: String?
    @Published var isLoading = false

    func register() {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            let user: UserResponse
            do {
                user = try await APIService.shared.register(email: email, password: password)
            } catch {
                errorMessage = "Ошибка регистрации: \(error.localizedDescription)"
                return
            }

            do {
                let token = try await APIService.shared.login(email: email, password: password)
                APIService.shared.setToken(token.access_token)
                APIService.shared.saveSession(token: token.access_token, userId: user.id)
                APIService.shared.currentUserId = user.id
                isLoggedIn = true
                NotificationCenter.default.post(name: .userDidLogin, object: nil)
            } catch {
                errorMessage = "Аккаунт создан, но войти не удалось. Попробуйте войти вручную."
            }
        }
    }

    func login() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let token = try await APIService.shared.login(email: email, password: password)
                APIService.shared.setToken(token.access_token)
                APIService.shared.saveSession(token: token.access_token, userId: nil)
                APIService.shared.fetchAndSaveUserId()
                isLoggedIn = true
                NotificationCenter.default.post(name: .userDidLogin, object: nil)
            } catch {
                errorMessage = "Ошибка входа: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
