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

    // MARK: - Identity Tracking

    /// Tracks email identity — sets email as profileId and sends a contact point email event.
    func trackEmailIdentity(email: String) {
        guard isSDKReady else {
            print("[PersonalizationService] ⚠️ SDK not ready — skipping EmailIdentity event")
            return
        }

        print("[PersonalizationService] --- EMAIL IDENTITY EVENT ---")
        print("[PersonalizationService]   Setting profileId = \(email)")
        print("[PersonalizationService]   Setting attribute: email = \(email)")

        SFMCSdk.identity.edit { modifier in
            modifier.profileId = email
            modifier.addAttribute(key: "email", value: email)
            return modifier
        }
        print("[PersonalizationService]   ✓ Identity profile updated via SFMCSdk.identity.edit")

        let attributes: [String: Any] = [
            "contactPointEmail": email,
            "source": "email_signup_footer"
        ]
        let event = IdentityEvent(attributes: attributes)
        SFMCSdk.track(event: event)
        print("[PersonalizationService]   ✓ IdentityEvent tracked with attributes: \(attributes)")
        print("[PersonalizationService] --- END EMAIL IDENTITY ---")
    }

    /// Tracks phone identity — adds phone attribute and sends a contact point phone event.
    func trackPhoneIdentity(phone: String) {
        guard isSDKReady else {
            print("[PersonalizationService] ⚠️ SDK not ready — skipping PhoneIdentity event")
            return
        }

        print("[PersonalizationService] --- PHONE IDENTITY EVENT ---")
        print("[PersonalizationService]   Setting attribute: phone = \(phone)")

        SFMCSdk.identity.edit { modifier in
            modifier.addAttribute(key: "phone", value: phone)
            return modifier
        }
        print("[PersonalizationService]   ✓ Identity profile updated via SFMCSdk.identity.edit")

        let attributes: [String: Any] = [
            "contactPointPhone": phone,
            "source": "sms_signup_sheet"
        ]
        let event = IdentityEvent(attributes: attributes)
        SFMCSdk.track(event: event)
        print("[PersonalizationService]   ✓ IdentityEvent tracked with attributes: \(attributes)")
        print("[PersonalizationService] --- END PHONE IDENTITY ---")
    }

    /// Tracks full profile identity — sets all profile attributes and sends a party identification event.
    func trackFullProfileIdentity(email: String, phone: String, firstName: String, lastName: String, zipCode: String) {
        guard isSDKReady else {
            print("[PersonalizationService] ⚠️ SDK not ready — skipping FullProfileIdentity event")
            return
        }

        print("[PersonalizationService] --- FULL PROFILE IDENTITY EVENT ---")
        print("[PersonalizationService]   Setting profileId = \(email)")
        print("[PersonalizationService]   Setting attribute: email     = \(email)")
        print("[PersonalizationService]   Setting attribute: phone     = \(phone)")
        print("[PersonalizationService]   Setting attribute: firstName = \(firstName)")
        print("[PersonalizationService]   Setting attribute: lastName  = \(lastName)")
        print("[PersonalizationService]   Setting attribute: zipCode   = \(zipCode)")

        SFMCSdk.identity.edit { modifier in
            modifier.profileId = email
            modifier.addAttribute(key: "email", value: email)
            modifier.addAttribute(key: "phone", value: phone)
            modifier.addAttribute(key: "firstName", value: firstName)
            modifier.addAttribute(key: "lastName", value: lastName)
            modifier.addAttribute(key: "zipCode", value: zipCode)
            return modifier
        }
        print("[PersonalizationService]   ✓ Identity profile updated via SFMCSdk.identity.edit")

        let attributes: [String: Any] = [
            "contactPointEmail": email,
            "contactPointPhone": phone,
            "firstName": firstName,
            "lastName": lastName,
            "zipCode": zipCode,
            "source": "profile_signup_sheet"
        ]
        let event = IdentityEvent(attributes: attributes)
        SFMCSdk.track(event: event)
        print("[PersonalizationService]   ✓ IdentityEvent tracked with attributes: \(attributes)")
        print("[PersonalizationService] --- END FULL PROFILE IDENTITY ---")
    }
}
