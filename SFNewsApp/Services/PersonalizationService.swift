import Foundation
import Personalization
import SFMCSDK

/// Wraps the Salesforce Einstein Personalization SDK's `fetchDecisions` API.
///
/// All methods are `@MainActor`-isolated so ViewModels can call them directly
/// without manual thread-hopping.
///
/// ## SDK Activation
/// `markSDKReady()` must be called from `AppDelegate` once `SFMCSdk.initializeSdk()`
/// completes successfully. Until then, all fetch calls return `.empty` and mock data is shown.
@MainActor
final class PersonalizationService {

    // MARK: - Singleton

    static let shared = PersonalizationService()
    private init() {}

    // MARK: - SDK Readiness

    private(set) var isSDKReady = false

    /// Called by AppDelegate after the SDK initializes successfully.
    func markSDKReady() {
        isSDKReady = true
        print("[PersonalizationService] SDK is ready.")
    }

    // MARK: - Fetch Decisions

    /// Fetches personalized decisions for the home screen from the SF p13n backend.
    ///
    /// Returns a `PersonalizationDecisionSet` on success, or `.empty` if the SDK is
    /// not ready, the call times out, or no content is returned — mock data shows in all fallback cases.
    func fetchHomeDecisions() async -> PersonalizationDecisionSet {
        guard isSDKReady else {
            print("[PersonalizationService] SDK not ready — returning mock data.")
            return .empty
        }

        do {
            let response = try await PersonalizationModule.fetchDecisions(
                personalizationPointNames: [
                    SDKConfig.featuredStoryPoint,
                    SDKConfig.forYouFeedPoint
                ],
                context: nil,
                timeoutSeconds: SDKConfig.fetchTimeoutSeconds
            )
            return PersonalizationDecisionParser.parse(response: response)
        } catch {
            print("[PersonalizationService] fetchDecisions error: \(error)")
            return .empty
        }
    }

    // MARK: - Event Tracking

    /// Tracks a home screen page view as a custom event.
    func trackHomePageView() {
        guard isSDKReady else { return }
        guard let event = CustomEvent(
            name: "HomePageView",
            attributes: ["screen": "home"]
        ) else { return }
        SFMCSdk.track(event: event)
        print("[PersonalizationService] Tracked HomePageView event")
    }

    /// Tracks an impression when an article becomes visible on screen.
    func trackImpression(for article: Article) {
        guard isSDKReady else { return }
        let catalogObject = CatalogObject(
            type: "Article",
            id: article.id,
            attributes: [
                "headline": article.headline,
                "category": article.category
            ]
        )
        SFMCSdk.track(event: ViewCatalogObjectEvent(catalogObject: catalogObject))
        print("[PersonalizationService] Tracked impression for article: \(article.id)")
    }

    /// Tracks a tap / detail view when a user clicks on an article.
    func trackClick(for article: Article) {
        guard isSDKReady else { return }
        let catalogObject = CatalogObject(
            type: "Article",
            id: article.id,
            attributes: [
                "headline": article.headline,
                "category": article.category
            ]
        )
        SFMCSdk.track(event: ViewCatalogObjectDetailEvent(catalogObject: catalogObject))
        print("[PersonalizationService] Tracked click for article: \(article.id)")
    }

    /// Tracks when a user views the full article detail page.
    func trackArticleDetailView(for article: Article) {
        guard isSDKReady else { return }
        guard let event = CustomEvent(
            name: "ArticleDetailView",
            attributes: [
                "articleId": article.id,
                "headline": article.headline,
                "category": article.category
            ]
        ) else { return }
        SFMCSdk.track(event: event)
        print("[PersonalizationService] Tracked ArticleDetailView for article: \(article.id)")
    }
}
