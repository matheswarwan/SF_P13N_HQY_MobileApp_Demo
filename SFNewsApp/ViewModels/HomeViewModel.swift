import SwiftUI
import Combine

/// Drives all three home screen sections.
///
/// Loading strategy:
/// 1. Immediately populate views with mock data (optimistic placeholder).
/// 2. Fire a `fetchDecisions` call to the SF p13n SDK.
/// 3. Replace relevant sections with personalized content if returned.
/// 4. Sections with no p13n response retain the mock fallback.
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var featuredArticle: Article?
    @Published private(set) var forYouArticles: [Article] = []
    @Published private(set) var trendingArticles: [Article] = MockData.trendingArticles
    @Published private(set) var isLoading = false

    /// True when at least one section has live personalized content from the SDK.
    /// Used to show the "Personalized" badge in the UI.
    @Published private(set) var hasPersonalizedContent = false

    // MARK: - Identity UI State

    @Published var showPhoneSignupSheet = false
    @Published var showProfileSignupSheet = false
    @Published var identityConfirmationMessage: String? = nil

    // MARK: - Dependencies

    private let service: PersonalizationService

    init(service: PersonalizationService = .shared) {
        self.service = service
    }

    // MARK: - Load Content

    /// Fetches personalized decisions and updates the home screen.
    /// Safe to call on `.task {}` and `.refreshable {}`.
    func loadContent() async {
        isLoading = true
        resetContent()
        showMockFallback()

        service.trackHomePageView()

        let decisions = await service.fetchHomeDecisions()
        apply(decisions)

        isLoading = false
    }

    /// Tracks an impression when an article becomes visible on screen.
    func trackImpression(for article: Article) {
        service.trackImpression(for: article)
    }

    /// Tracks a tap on an article.
    func trackClick(for article: Article) {
        service.trackClick(for: article)
    }

    /// Tracks when a user opens the full article detail.
    func trackArticleDetailView(for article: Article) {
        service.trackArticleDetailView(for: article)
    }

    // MARK: - Identity Actions

    func submitEmail(email: String) {
        service.trackEmailIdentity(email: email)
        showConfirmation("Email registered!")
    }

    func submitPhone(phone: String) {
        service.trackPhoneIdentity(phone: phone)
        showPhoneSignupSheet = false
        showConfirmation("Phone number registered!")
    }

    func submitProfile(email: String, phone: String, firstName: String, lastName: String, zipCode: String) {
        service.trackFullProfileIdentity(email: email, phone: phone, firstName: firstName, lastName: lastName, zipCode: zipCode)
        showProfileSignupSheet = false
        showConfirmation("Profile created!")
    }

    // MARK: - Private

    /// Clears cached content so the next loadContent() starts fresh (e.g., on user switch).
    private func resetContent() {
        featuredArticle = nil
        forYouArticles = []
        hasPersonalizedContent = false
    }

    private func showConfirmation(_ message: String) {
        identityConfirmationMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            identityConfirmationMessage = nil
        }
    }

    private func showMockFallback() {
        if featuredArticle == nil {
            featuredArticle = MockData.featuredArticle
        }
        if forYouArticles.isEmpty {
            forYouArticles = MockData.forYouArticles
        }
    }

    private func apply(_ decisions: PersonalizationDecisionSet) {
        if let p = decisions.featuredArticle {
            featuredArticle = Article(
                id: p.id,
                headline: p.headline,
                summary: p.summary,
                body: p.body,
                category: p.category,
                imageURL: p.imageURL,
                publishedDate: Date(),
                readTimeMinutes: p.readTimeMinutes,
                isFeatured: true
            )
            hasPersonalizedContent = true
        }

        if !decisions.forYouArticles.isEmpty {
            forYouArticles = decisions.forYouArticles.map { p in
                Article(
                    id: p.id,
                    headline: p.headline,
                    summary: p.summary,
                    body: p.body,
                    category: p.category,
                    imageURL: p.imageURL,
                    publishedDate: Date(),
                    readTimeMinutes: p.readTimeMinutes,
                    isFeatured: false
                )
            }
            hasPersonalizedContent = true
        }
    }
}
