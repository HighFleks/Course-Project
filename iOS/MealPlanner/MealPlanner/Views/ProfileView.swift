import SwiftUI
import Combine

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showPasswordSection = false
    @State private var showLogoutConfirmation = false

    var body: some View {
        Form {
            // MARK: - Аккаунт
            Section("Аккаунт") {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Email").font(.caption).foregroundColor(.secondary)
                        Text(viewModel.email.isEmpty ? "—" : viewModel.email)
                            .font(.body)
                    }
                }
                if let since = viewModel.memberSince {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("С нами с").font(.caption).foregroundColor(.secondary)
                            Text(since).font(.body)
                        }
                    }
                }
            }

            // MARK: - Статистика
            Section("Статистика") {
                if let stats = viewModel.stats {
                    statRow(icon: "book.fill", color: .orange,
                            title: "Созданных рецептов", value: stats.recipes_created)
                    statRow(icon: "star.fill", color: .yellow,
                            title: "В избранном", value: stats.favorites_count)
                    statRow(icon: "basket.fill", color: .green,
                            title: "Продуктов в инвентаре", value: stats.inventory_items)
                    statRow(icon: "cart.fill", color: .pink,
                            title: "В списке покупок", value: stats.shopping_items)
                } else if viewModel.isLoading {
                    ProgressView()
                } else if let err = viewModel.loadError {
                    Text(err).foregroundColor(.red).font(.footnote)
                }
            }

            // MARK: - Безопасность
            Section("Безопасность") {
                DisclosureGroup("Сменить пароль", isExpanded: $showPasswordSection) {
                    SecureField("Текущий пароль", text: $viewModel.oldPassword)
                        .textContentType(.password)
                    SecureField("Новый пароль", text: $viewModel.newPassword)
                        .textContentType(.newPassword)
                    SecureField("Повторите новый пароль", text: $viewModel.confirmPassword)
                        .textContentType(.newPassword)

                    if let error = viewModel.passwordError {
                        Text(error).foregroundColor(.red).font(.footnote)
                    }
                    if let success = viewModel.passwordSuccess {
                        Text(success).foregroundColor(.green).font(.footnote)
                    }

                    Button {
                        viewModel.changePassword()
                    } label: {
                        if viewModel.isChangingPassword {
                            ProgressView()
                        } else {
                            Text("Обновить пароль")
                        }
                    }
                    .disabled(viewModel.isChangingPassword)
                }
            }

            // MARK: - Выход
            Section {
                Button(role: .destructive) {
                    showLogoutConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Выйти из аккаунта")
                    }
                }
            }
        }
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.load() }
        .refreshable { viewModel.load() }
        .alert("Выйти?", isPresented: $showLogoutConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Выйти", role: .destructive) {
                viewModel.logout()
            }
        } message: {
            Text("Вы вернётесь на экран входа. Сохранённый список «План приготовления» останется на устройстве.")
        }
    }

    private func statRow(icon: String, color: Color, title: String, value: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text("\(value)")
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
}
