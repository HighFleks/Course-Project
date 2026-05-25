import Foundation
import SwiftUI
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var memberSince: String?
    @Published var stats: UserStats?

    @Published var isLoading = false
    @Published var loadError: String?

    @Published var oldPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var passwordError: String?
    @Published var passwordSuccess: String?
    @Published var isChangingPassword = false

    private let service = APIService.shared

    func load() {
        Task {
            isLoading = true
            loadError = nil
            defer { isLoading = false }
            do {
                async let userTask = service.getCurrentUser()
                async let statsTask = service.getUserStats()
                let user = try await userTask
                let stats = try await statsTask
                self.email = user.email
                self.memberSince = Self.formatDate(user.created_at)
                self.stats = stats
            } catch {
                loadError = "Не удалось загрузить профиль: \(error.localizedDescription)"
            }
        }
    }

    func changePassword() {
        passwordError = nil
        passwordSuccess = nil

        let oldTrim = oldPassword
        let newTrim = newPassword
        let confirmTrim = confirmPassword

        guard !oldTrim.isEmpty else {
            passwordError = "Введите текущий пароль"
            return
        }
        guard newTrim.count >= 6 else {
            passwordError = "Новый пароль должен быть не короче 6 символов"
            return
        }
        guard newTrim == confirmTrim else {
            passwordError = "Пароли не совпадают"
            return
        }

        Task {
            isChangingPassword = true
            defer { isChangingPassword = false }
            do {
                try await service.changePassword(old: oldTrim, new: newTrim)
                passwordSuccess = "Пароль обновлён"
                oldPassword = ""
                newPassword = ""
                confirmPassword = ""
            } catch {
                passwordError = error.localizedDescription
            }
        }
    }

    func logout() {
        service.logout()
    }

    private static func formatDate(_ raw: String?) -> String? {
        guard let raw = raw else { return nil }
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoSimple = ISO8601DateFormatter()
        isoSimple.formatOptions = [.withInternetDateTime]

        let date = isoFractional.date(from: raw) ?? isoSimple.date(from: raw)
        guard let date = date else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}
