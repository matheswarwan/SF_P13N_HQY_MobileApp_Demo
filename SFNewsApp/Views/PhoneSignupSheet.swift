import SwiftUI

/// Modal sheet for phone number collection.
/// Sends a contact point phone identity event to Salesforce Data Cloud.
struct PhoneSignupSheet: View {

    @EnvironmentObject var viewModel: HomeViewModel
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "message.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(HETheme.primaryGreen)
                    .padding(.top, 32)

                Text("Get SMS Updates")
                    .font(.title2.bold())

                Text("Receive timely benefit reminders and enrollment alerts via text message.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                TextField("Phone number", text: $phone)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding(.horizontal, 24)

                Button("Submit") {
                    guard !phone.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    viewModel.submitPhone(phone: phone.trimmingCharacters(in: .whitespaces))
                }
                .buttonStyle(.borderedProminent)
                .tint(HETheme.primaryGreen)
                .disabled(phone.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showPhoneSignupSheet = false
                    }
                }
            }
        }
    }
}

#Preview {
    PhoneSignupSheet()
        .environmentObject(HomeViewModel())
}
