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

    func signup(email: String, password: String, firstName: String, lastName: String, gender: String = "") {
        errorMessage = nil
        do {
            let account = try authService.signup(
                email: email, password: password,
                firstName: firstName, lastName: lastName,
                gender: gender
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

    // MARK: - Profile Update

    func updateProfile(_ updated: UserAccount) {
        authService.updateAccount(updated)
        currentUser = updated
        UserDefaults.standard.set(updated.email, forKey: loggedInEmailKey)
        personalizationService.setUserIdentity(user: updated)
        personalizationService.trackPreferenceUpdate(user: updated)
        print("[AuthViewModel] Updated profile for \(updated.email)")
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
