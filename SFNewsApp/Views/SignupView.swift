import SwiftUI

/// Account creation form presented as a sheet from LoginView.
struct SignupView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: email) { authViewModel.errorMessage = nil }

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .onChange(of: password) { authViewModel.errorMessage = nil }
                }

                Section("Profile (Optional)") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }

                if let error = authViewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button("Create Account") {
                        authViewModel.signup(
                            email: email,
                            password: password,
                            firstName: firstName,
                            lastName: lastName
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .listRowBackground(isFormValid ? HETheme.primaryGreen : Color.gray)
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        authViewModel.errorMessage = nil
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SignupView()
        .environmentObject(AuthViewModel())
}
