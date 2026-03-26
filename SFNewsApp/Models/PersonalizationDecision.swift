import Foundation
import Personalization

// MARK: - Personalized article from a single decision slot

/// A typed representation of a single personalized article returned by the SF p13n SDK.
/// Maps from the raw `Personalization` object's `attributes` dictionary and `data` array.
struct PersonalizedArticle: Identifiable {
    let id: String
    let headline: String
    let summary: String
    let body: String
    let category: String
    let imageURL: URL?
    let readTimeMinutes: Int
}

// MARK: - Full decision set for the home screen

/// Holds all personalized decisions fetched for the home screen in a single call.
struct PersonalizationDecisionSet {
    let featuredArticle: PersonalizedArticle?
    let forYouArticles: [PersonalizedArticle]

    /// Empty state — returned when SDK is unavailable or returns no content.
    static let empty = PersonalizationDecisionSet(featuredArticle: nil, forYouArticles: [])
}

// MARK: - Response parser

/// Translates the SDK `DecisionsResponse` object into typed Swift models.
enum PersonalizationDecisionParser {

    /// Parse a `DecisionsResponse` from the SDK.
    /// - Parameter response: The `DecisionsResponse` returned by `PersonalizationModule.fetchDecisions`.
    /// - Returns: A typed `PersonalizationDecisionSet`.
    static func parse(response: DecisionsResponse) -> PersonalizationDecisionSet {
        let byName = response.personalizationsByName

        let featured = byName[SDKConfig.featuredStoryPoint].flatMap { parseSingleItem(from: $0) }
        let feed = byName[SDKConfig.forYouFeedPoint].map { parseMultiItem(from: $0) } ?? []

        return PersonalizationDecisionSet(featuredArticle: featured, forYouArticles: feed)
    }

    // MARK: - Private

    /// Parse a single-item personalization (featured story hero).
    /// The SDK returns the item data in the `attributes` dictionary.
    /// Accepts both "imageUrl" and "imageURL" key variants.
    private static func parseSingleItem(from personalization: DecisionsResponsePersonalization) -> PersonalizedArticle? {
        let attrs = personalization.attributes

        // Accept both key variants for image URL
        let imageURLString = attrs["imageUrl"] as? String
            ?? attrs["imageURL"] as? String
            ?? (attrs["imageURL"] as? URL)?.absoluteString

        // headline is preferred but not strictly required — use fallback for image-only experiments
        let headline = attrs["headline"] as? String ?? attrs["title"] as? String ?? ""

        // If we have neither headline nor image, there's nothing to show
        guard !headline.isEmpty || imageURLString != nil else {
            print("[PersonalizationParser] Skipping item — no headline or imageURL found in attributes: \(Array(attrs.keys))")
            return nil
        }

        let article = PersonalizedArticle(
            id: personalization.personalizationId,
            headline: headline.isEmpty ? "Featured" : headline,
            summary: attrs["summary"] as? String ?? attrs["description"] as? String ?? "",
            body: attrs["body"] as? String ?? "",
            category: attrs["category"] as? String ?? "Featured",
            imageURL: imageURLString.flatMap(URL.init),
            readTimeMinutes: attrs["readTimeMinutes"] as? Int ?? 3
        )
        print("[PersonalizationParser] Parsed featured article: headline=\"\(article.headline)\", imageURL=\(article.imageURL?.absoluteString ?? "nil")")
        return article
    }

    /// Parse a multi-item personalization (for-you feed).
    /// The SDK returns items in the `data` array as `DecisionsResponseContentObject` instances.
    private static func parseMultiItem(from personalization: DecisionsResponsePersonalization) -> [PersonalizedArticle] {
        let dataArray = personalization.data
        guard !dataArray.isEmpty else {
            // Fallback: some SDK versions put items in attributes for single-slot decisions
            return parseSingleItem(from: personalization).map { [$0] } ?? []
        }

        return dataArray.compactMap { item in
            guard let headline = item["headline"] as? String else { return nil }
            return PersonalizedArticle(
                id: item["articleId"] as? String ?? UUID().uuidString,
                headline: headline,
                summary: item["summary"] as? String ?? "",
                body: item["body"] as? String ?? "",
                category: item["category"] as? String ?? "News",
                imageURL: (item["imageUrl"] as? String).flatMap(URL.init),
                readTimeMinutes: item["readTimeMinutes"] as? Int ?? 3
            )
        }
    }
}
