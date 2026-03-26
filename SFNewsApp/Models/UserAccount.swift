import Foundation

/// A local user account stored on-device (demo only — plain-text password).
struct UserAccount: Codable, Identifiable, Equatable {
    let id: UUID
    var email: String
    var password: String
    var firstName: String
    var lastName: String

    /// Returns the display name, or falls back to email if names are empty.
    var displayName: String {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? email : name
    }
}
