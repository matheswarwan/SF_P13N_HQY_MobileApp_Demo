import SwiftUI

/// Full profile editing screen with personal details and marketing/notification preferences.
/// Changes are saved locally and synced to Salesforce Data Cloud via identity + preference events.
struct ProfileView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Editable Fields

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var zipCode = ""
    @State private var gender = ""

    private let genderOptions = ["", "Male", "Female", "Non-binary", "Prefer not to say"]

    // MARK: - Preferences

    @State private var marketingEmailOptIn = false
    @State private var marketingPushOptIn = false
    @State private var marketingSmsOptIn = false
    @State private var weeklyDigestOptIn = false
    @State private var benefitAlertsOptIn = false

    var body: some View {
        NavigationStack {
            Form {
                // Avatar + name header
                profileHeader

                Section("Personal Information") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                    Picker("Gender", selection: $gender) {
                        ForEach(genderOptions, id: \.self) { option in
                            Text(option.isEmpty ? "Select" : option).tag(option)
                        }
                    }
                }

                Section("Contact Information") {
                    if let user = authViewModel.currentUser {
                        HStack {
                            Text("Email")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(user.email)
                                .foregroundStyle(.primary)
                        }
                    }
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField("Zip Code", text: $zipCode)
                        .keyboardType(.numberPad)
                        .textContentType(.postalCode)
                }

                Section {
                    Toggle("Marketing Emails", isOn: $marketingEmailOptIn)
                    Toggle("Push Notifications", isOn: $marketingPushOptIn)
                    Toggle("SMS Offers", isOn: $marketingSmsOptIn)
                } header: {
                    Text("Marketing Preferences")
                } footer: {
                    Text("Choose how you'd like to hear about offers, promotions, and product updates.")
                }

                Section {
                    Toggle("Weekly Benefits Digest", isOn: $weeklyDigestOptIn)
                    Toggle("Benefit Alerts", isOn: $benefitAlertsOptIn)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get notified about HSA/FSA deadlines, contribution limits, and investment opportunities.")
                }

            }
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadCurrentValues)
        }
    }

    // MARK: - Profile Header

    @ViewBuilder
    private var profileHeader: some View {
        if let user = authViewModel.currentUser {
            Section {
                HStack(spacing: 16) {
                    // Avatar circle with initials
                    ZStack {
                        Circle()
                            .fill(HETheme.primaryGreen)
                            .frame(width: 64, height: 64)
                        Text(user.initials)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.title3.bold())
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Actions

    private func loadCurrentValues() {
        print("[ProfileView] loadCurrentValues called")
        guard let user = authViewModel.currentUser else {
            print("[ProfileView] ⚠️ No current user on load — fields will be empty")
            return
        }
        print("[ProfileView] Loading values for \(user.email)")
        firstName = user.firstName
        lastName = user.lastName
        phone = user.phone
        zipCode = user.zipCode
        gender = user.gender
        marketingEmailOptIn = user.marketingEmailOptIn
        marketingPushOptIn = user.marketingPushOptIn
        marketingSmsOptIn = user.marketingSmsOptIn
        weeklyDigestOptIn = user.weeklyDigestOptIn
        benefitAlertsOptIn = user.benefitAlertsOptIn
    }

    private func saveProfile() {
        print("[ProfileView] Save Changes tapped")
        guard var user = authViewModel.currentUser else {
            print("[ProfileView] ⚠️ No current user — cannot save")
            return
        }
        print("[ProfileView] Saving profile for \(user.email)")
        user.firstName = firstName.trimmingCharacters(in: .whitespaces)
        user.lastName = lastName.trimmingCharacters(in: .whitespaces)
        user.phone = phone.trimmingCharacters(in: .whitespaces)
        user.zipCode = zipCode.trimmingCharacters(in: .whitespaces)
        user.gender = gender
        user.marketingEmailOptIn = marketingEmailOptIn
        user.marketingPushOptIn = marketingPushOptIn
        user.marketingSmsOptIn = marketingSmsOptIn
        user.weeklyDigestOptIn = weeklyDigestOptIn
        user.benefitAlertsOptIn = benefitAlertsOptIn

        authViewModel.updateProfile(user)
        dismiss()
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
