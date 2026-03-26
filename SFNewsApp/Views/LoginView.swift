import SwiftUI

/// Login screen shown as the app root when no user is authenticated.
struct LoginView: View {

    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showSignup = false

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Brand header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(HETheme.primaryGreen)
                    Text("HealthEquity")
                        .font(.largeTitle.bold())
                    Text("Your personalized benefits hub")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)

                // Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: email) { authViewModel.errorMessage = nil }

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .onChange(of: password) { authViewModel.errorMessage = nil }

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("Sign In") {
                        authViewModel.login(email: email, password: password)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HETheme.primaryGreen)
                    .frame(maxWidth: .infinity)
                    .disabled(!isFormValid)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Switch to signup
                Button("Don't have an account? Create one") {
                    authViewModel.errorMessage = nil
                    showSignup = true
                }
                .font(.subheadline)
                .foregroundStyle(HETheme.primaryGreen)
                .padding(.bottom, 32)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSignup) {
                SignupView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
