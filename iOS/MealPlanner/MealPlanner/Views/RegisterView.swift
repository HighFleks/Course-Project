import SwiftUI

struct RegisterView: View {
    @StateObject private var authVM = AuthViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Регистрация")
                .font(.title)

            TextField("Email", text: $authVM.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(.roundedBorder)

            SecureField("Пароль", text: $authVM.password)
                .textFieldStyle(.roundedBorder)

            if let error = authVM.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            Button("Зарегистрироваться") {
                authVM.register()
            }
            .buttonStyle(.borderedProminent)
            .disabled(authVM.isLoading)
        }
        .padding()
    }
}
