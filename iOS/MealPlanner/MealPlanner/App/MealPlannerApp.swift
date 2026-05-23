import SwiftUI

@main
struct MealPlannerApp: App {
    @State private var isLoggedIn = false
    @State private var checkedSession = false

    var body: some Scene {
        WindowGroup {
            if checkedSession {
                if isLoggedIn {
                    HomeView()
                } else {
                    LoginView()
                }
            } else {
                // Пока проверяем сессию, можно показать пустой экран или лоадер
                ProgressView("Восстановление сессии...")
                    .onAppear {
                        validateSession()
                    }
            }
        }
    }

    private func validateSession() {
        if APIService.shared.restoreSession() {
            // Токен есть, но проверим его валидность через запрос к /api/auth/me
            Task {
                do {
                    let _ = try await APIService.shared.getCurrentUser()
                    // Успешно — сессия действительна
                    isLoggedIn = true
                } catch {
                    // Ошибка — токен невалиден, сбрасываем сессию
                    APIService.shared.clearSession()
                    isLoggedIn = false
                }
                checkedSession = true
            }
        } else {
            // Токена нет — сразу на вход
            checkedSession = true
            isLoggedIn = false
        }
    }
}
