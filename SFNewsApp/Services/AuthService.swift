import Foundation

/// Manages local user accounts persisted as JSON in the app's Documents directory.
/// Demo only — passwords stored in plain text.
final class AuthService {

    // MARK: - Singleton

    static let shared = AuthService()
    private init() { loadAccounts() }

    // MARK: - Storage

    private var accounts: [UserAccount] = []

    private var storageURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("local_accounts.json")
    }

    private func loadAccounts() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([UserAccount].self, from: data)
        else { return }
        accounts = decoded
    }

    private func saveAccounts() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case emailAlreadyExists
        case invalidCredentials
        case emptyEmail
        case emptyPassword

        var errorDescription: String? {
            switch self {
            case .emailAlreadyExists:  return "An account with this email already exists."
            case .invalidCredentials:  return "Incorrect email or password."
            case .emptyEmail:          return "Please enter an email address."
            case .emptyPassword:       return "Please enter a password."
            }
        }
    }

    // MARK: - Public API

    @discardableResult
    func signup(email: String, password: String,
                firstName: String = "", lastName: String = "",
                gender: String = "") throws -> UserAccount {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedPassword = password.trimmingCharacters(in: .whitespaces)

        guard !trimmedEmail.isEmpty else { throw AuthError.emptyEmail }
        guard !trimmedPassword.isEmpty else { throw AuthError.emptyPassword }
        guard !accounts.contains(where: { $0.email == trimmedEmail }) else {
            throw AuthError.emailAlreadyExists
        }

        let account = UserAccount(
            id: UUID(),
            email: trimmedEmail,
            password: trimmedPassword,
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            phone: "",
            zipCode: "",
            gender: gender,
            marketingEmailOptIn: false,
            marketingPushOptIn: false,
            marketingSmsOptIn: false,
            weeklyDigestOptIn: false,
            benefitAlertsOptIn: false
        )
        accounts.append(account)
        saveAccounts()
        print("[AuthService] Created account for \(trimmedEmail)")
        return account
    }

    func login(email: String, password: String) throws -> UserAccount {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedPassword = password.trimmingCharacters(in: .whitespaces)

        guard !trimmedEmail.isEmpty else { throw AuthError.emptyEmail }
        guard !trimmedPassword.isEmpty else { throw AuthError.emptyPassword }

        guard let account = accounts.first(where: {
            $0.email == trimmedEmail && $0.password == trimmedPassword
        }) else {
            throw AuthError.invalidCredentials
        }
        print("[AuthService] Logged in: \(trimmedEmail)")
        return account
    }

    /// Updates an existing account in-place and persists.
    func updateAccount(_ updated: UserAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == updated.id }) else { return }
        accounts[index] = updated
        saveAccounts()
        print("[AuthService] Updated account for \(updated.email)")
    }

    func allAccounts() -> [UserAccount] { accounts }
}
