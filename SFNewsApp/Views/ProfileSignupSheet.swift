import SwiftUI

/// Modal sheet for full profile collection.
/// Sends party identification and contact point events to Salesforce Data Cloud.
struct ProfileSignupSheet: View {

    @EnvironmentObject var viewModel: HomeViewModel

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var zipCode = ""

    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }

                Section("Contact") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }

                Section("Location") {
                    TextField("Zip Code", text: $zipCode)
                        .keyboardType(.numberPad)
                        .textContentType(.postalCode)
                }

                Section {
                    Button("Create Profile") {
                        viewModel.submitProfile(
                            email: email.trimmingCharacters(in: .whitespaces),
                            phone: phone.trimmingCharacters(in: .whitespaces),
                            firstName: firstName.trimmingCharacters(in: .whitespaces),
                            lastName: lastName.trimmingCharacters(in: .whitespaces),
                            zipCode: zipCode.trimmingCharacters(in: .whitespaces)
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .listRowBackground(isFormValid ? HETheme.primaryGreen : Color.gray)
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showProfileSignupSheet = false
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileSignupSheet()
        .environmentObject(HomeViewModel())
}
