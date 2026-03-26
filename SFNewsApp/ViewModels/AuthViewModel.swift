import SwiftUI
import Combine

/// Manages authentication state. Injected as @EnvironmentObject at the app root.
@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isLoggedIn: Bool = false
    @Published private(set) var currentUser: UserAccount? = nil
    @Published var errorMessage: String? = nil

    // MARK: - Dependencies

    private let authService: AuthService
    private let personalizationService: PersonalizationService

    private let loggedInEmailKey = "auth.loggedInEmail"

    // MARK: - Init

    init(authService: AuthService = .shared,
         personalizationService: PersonalizationService = .shared) {
        self.authService = authService
        self.personalizationService = personalizationService
        restoreSession()
    }

    // MARK: - Session Restore

    private func restoreSession() {
        guard let savedEmail = UserDefaults.standard.string(forKey: loggedInEmailKey),
              let account = authService.allAccounts().first(where: { $0.email == savedEmail })
        else { return }

        currentUser = account
        isLoggedIn = true
        personalizationService.setUserIdentity(user: account)
        print("[AuthViewModel] Restored session for \(savedEmail)")
    }

    // MARK: - Login

    func login(email: String, password: String) {
        errorMessage = nil
        do {
            let account = try authService.login(email: email, password: password)
            setCurrentUser(account)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Signup

    func signup(email: String, password: String, firstName: String, lastName: String) {
        errorMessage = nil
        do {
            let account = try authService.signup(
                email: email, password: password,
                firstName: firstName, lastName: lastName
            )
            setCurrentUser(account)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Logout

    func logout() {
        print("[AuthViewModel] Logging out \(currentUser?.email ?? "unknown")")
        personalizationService.clearIdentity()
        UserDefaults.standard.removeObject(forKey: loggedInEmailKey)
        currentUser = nil
        isLoggedIn = false
    }

    // MARK: - Private

    private func setCurrentUser(_ account: UserAccount) {
        currentUser = account
        isLoggedIn = true
        UserDefaults.standard.set(account.email, forKey: loggedInEmailKey)
        personalizationService.setUserIdentity(user: account)
        print("[AuthViewModel] Set current user: \(account.email)")
    }
}
