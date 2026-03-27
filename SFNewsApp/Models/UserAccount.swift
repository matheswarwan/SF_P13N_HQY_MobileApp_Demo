import Foundation

/// A local user account stored on-device (demo only — plain-text password).
struct UserAccount: Codable, Identifiable, Equatable {
    let id: UUID
    var email: String
    var password: String
    var firstName: String
    var lastName: String
    var phone: String
    var zipCode: String
    var gender: String

    // MARK: - Preferences

    var marketingEmailOptIn: Bool
    var marketingPushOptIn: Bool
    var marketingSmsOptIn: Bool
    var weeklyDigestOptIn: Bool
    var benefitAlertsOptIn: Bool

    /// Returns the display name, or falls back to email if names are empty.
    var displayName: String {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? email : name
    }

    /// Initials for avatar display (e.g., "MK" for "Mathes Kanagarajan").
    var initials: String {
        let parts = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if parts.isEmpty { return String(email.prefix(1)).uppercased() }
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }
}
