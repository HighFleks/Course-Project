import SwiftUI

@main
struct MealPlannerApp: App {
    @State private var isLoggedIn = false
    @State private var checkedSession = false

    var body: some Scene {
        WindowGroup {
            Group {
                if checkedSession {
                    if isLoggedIn {
                        HomeView()
                            .id("home")
                    } else {
                        LoginView()
                            .id("login")
                    }
                } else {
                    ProgressView("Восстановление сессии...")
                        .onAppear {
                            validateSession()
                        }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .sessionDidExpire)) { _ in
                // Сервер вернул 401 (или пользователь нажал «Выйти») -
                // принудительно возвращаем на экран входа.
                isLoggedIn = false
                checkedSession = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .userDidLogin)) { _ in
                // Успешный вход или регистрация - переходим на главный экран.
                isLoggedIn = true
                checkedSession = true
            }
        }
    }

    private func validateSession() {
        if APIService.shared.restoreSession() {
            // Токен есть, но проверим его валидность через запрос к /api/auth/me
            Task {
                do {
                    let _ = try await APIService.shared.getCurrentUser()
                    // Успешно - сессия действительна
                    isLoggedIn = true
                } catch {
                    // Ошибка - токен невалиден, сбрасываем сессию
                        APIService.shared.clearSession()
                    isLoggedIn = false
                }
                checkedSession = true
            }
        } else {
            // Токена нет - сразу на вход
            checkedSession = true
            isLoggedIn = false
        }
    }
}
