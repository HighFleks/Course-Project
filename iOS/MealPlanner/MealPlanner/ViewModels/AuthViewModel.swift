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
            do {
                let user = try await APIService.shared.register(email: email, password: password)
                // После регистрации сразу логинимся
                let token = try await APIService.shared.login(email: email, password: password)
                APIService.shared.setToken(token.access_token)
                isLoggedIn = true
            } catch {
                errorMessage = "Ошибка регистрации: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    func login() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let token = try await APIService.shared.login(email: email, password: password)
                APIService.shared.setToken(token.access_token)
                isLoggedIn = true
            } catch {
                errorMessage = "Ошибка входа: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
