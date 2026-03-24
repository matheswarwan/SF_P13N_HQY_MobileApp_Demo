import Foundation

/// Core data model representing a news article displayed in the app.
/// Used by both mock data and personalized content mapped from the SF p13n SDK response.
struct Article: Identifiable, Hashable {
    let id: String
    let headline: String
    let summary: String
    let body: String
    let category: String
    let imageURL: URL?
    let publishedDate: Date
    let readTimeMinutes: Int
    let isFeatured: Bool
}
