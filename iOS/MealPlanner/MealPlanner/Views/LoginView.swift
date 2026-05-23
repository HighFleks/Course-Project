import SwiftUI

struct LoginView: View {
    @StateObject private var authVM = AuthViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Meal Planner")
                    .font(.largeTitle)
                    .bold()

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

                Button("Войти") {
                    authVM.login()
                }
                .buttonStyle(.borderedProminent)
                .disabled(authVM.isLoading)

                NavigationLink("Зарегистрироваться") {
                    RegisterView(authVM: authVM)
                }
            }
            .padding()
            .fullScreenCover(isPresented: $authVM.isLoggedIn) {
                HomeView()
            }
        }
    }
}
