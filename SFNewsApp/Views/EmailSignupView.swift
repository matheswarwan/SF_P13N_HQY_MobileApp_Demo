import SwiftUI

/// Inline footer component for email signup.
/// Sends a contact point email identity event to Salesforce Data Cloud.
struct EmailSignupView: View {

    @EnvironmentObject var viewModel: HomeViewModel
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stay Informed")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Get the latest benefits updates delivered to your inbox.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("Enter your email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Button("Subscribe") {
                    guard !email.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    viewModel.submitEmail(email: email.trimmingCharacters(in: .whitespaces))
                    email = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(HETheme.primaryGreen)
                .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .background(HETheme.lightGreen)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

#Preview {
    EmailSignupView()
        .environmentObject(HomeViewModel())
}
