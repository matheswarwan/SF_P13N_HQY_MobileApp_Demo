import Foundation
import Personalization
import SFMCSDK
import Cdp

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
            let pointNames = [SDKConfig.featuredStoryPoint, SDKConfig.forYouFeedPoint]
            print("[PersonalizationService] --- FETCH DECISIONS ---")
            print("[PersonalizationService]   Requesting points: \(pointNames)")

            let response = try await PersonalizationModule.fetchDecisions(
                personalizationPointNames: pointNames,
                context: nil,
                timeoutSeconds: SDKConfig.fetchTimeoutSeconds
            )

            // Log raw response for debugging
            print("[PersonalizationService]   Response received. Personalization points returned: \(Array(response.personalizationsByName.keys))")
            for (pointName, personalization) in response.personalizationsByName {
                print("[PersonalizationService]   --- Point: \(pointName) ---")
                print("[PersonalizationService]     personalizationId: \(personalization.personalizationId)")
                print("[PersonalizationService]     attributes: \(personalization.attributes)")
                print("[PersonalizationService]     data count: \(personalization.data.count)")
                for (index, item) in personalization.data.enumerated() {
                    print("[PersonalizationService]     data[\(index)]: \(item)")
                }
            }
            print("[PersonalizationService] --- END FETCH DECISIONS ---")

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

    // MARK: - Auth Identity Management

    /// Sets the Salesforce identity profile for a logged-in local user.
    func setUserIdentity(user: UserAccount) {
        guard isSDKReady else {
            print("[PersonalizationService] SDK not ready — skipping setUserIdentity")
            return
        }

        print("[PersonalizationService] --- SET USER IDENTITY ---")
        print("[PersonalizationService]   profileId  = \(user.email)")
        print("[PersonalizationService]   firstName  = \(user.firstName)")
        print("[PersonalizationService]   lastName   = \(user.lastName)")
        print("[PersonalizationService]   phoneNumber = \(user.phone)")
        print("[PersonalizationService]   postalCode  = \(user.zipCode)")
        print("[PersonalizationService]   Gender     = \(user.gender)")

        SFMCSdk.identity.edit { modifier in
            modifier.profileId = user.email
            modifier.addAttribute(key: "email", value: user.email)
            if !user.firstName.isEmpty {
                modifier.addAttribute(key: "firstName", value: user.firstName)
            }
            if !user.lastName.isEmpty {
                modifier.addAttribute(key: "lastName", value: user.lastName)
            }
            if !user.phone.isEmpty {
                modifier.addAttribute(key: "phoneNumber", value: user.phone)
            }
            if !user.zipCode.isEmpty {
                modifier.addAttribute(key: "postalCode", value: user.zipCode)
            }
            if !user.gender.isEmpty {
                modifier.addAttribute(key: "Gender", value: user.gender)
            }
            return modifier
        }
        print("[PersonalizationService]   ✓ identity.edit complete")

        var attributes: [String: Any] = ["contactPointEmail": user.email, "source": "local_auth_login"]
        if !user.firstName.isEmpty { attributes["firstName"] = user.firstName }
        if !user.lastName.isEmpty  { attributes["lastName"]  = user.lastName  }
        if !user.phone.isEmpty     { attributes["phoneNumber"] = user.phone }
        if !user.zipCode.isEmpty   { attributes["postalCode"] = user.zipCode  }
        if !user.gender.isEmpty    { attributes["Gender"]    = user.gender    }
        let event = IdentityEvent(attributes: attributes)
        SFMCSdk.track(event: event)
        print("[PersonalizationService]   ✓ IdentityEvent tracked: \(attributes)")
        print("[PersonalizationService] --- END SET USER IDENTITY ---")
    }

    /// Clears the current identity, reverting to anonymous. Called on logout.
    func clearIdentity() {
        guard isSDKReady else { return }
        CdpModule.shared.setProfileToAnonymous()
        print("[PersonalizationService] ✓ CDP profile set to anonymous (logout)")
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
        print("[PersonalizationService]   Setting attribute: phoneNumber = \(phone)")

        SFMCSdk.identity.edit { modifier in
            modifier.addAttribute(key: "phoneNumber", value: phone)
            return modifier
        }
        print("[PersonalizationService]   ✓ Identity profile updated via SFMCSdk.identity.edit")

        let attributes: [String: Any] = [
            "phoneNumber": phone,
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
        print("[PersonalizationService]   Setting attribute: phoneNumber = \(phone)")
        print("[PersonalizationService]   Setting attribute: firstName   = \(firstName)")
        print("[PersonalizationService]   Setting attribute: lastName    = \(lastName)")
        print("[PersonalizationService]   Setting attribute: postalCode  = \(zipCode)")

        SFMCSdk.identity.edit { modifier in
            modifier.profileId = email
            modifier.addAttribute(key: "email", value: email)
            modifier.addAttribute(key: "phoneNumber", value: phone)
            modifier.addAttribute(key: "firstName", value: firstName)
            modifier.addAttribute(key: "lastName", value: lastName)
            modifier.addAttribute(key: "postalCode", value: zipCode)
            return modifier
        }
        print("[PersonalizationService]   ✓ Identity profile updated via SFMCSdk.identity.edit")

        let attributes: [String: Any] = [
            "contactPointEmail": email,
            "phoneNumber": phone,
            "firstName": firstName,
            "lastName": lastName,
            "postalCode": zipCode,
            "source": "profile_signup_sheet"
        ]
        let event = IdentityEvent(attributes: attributes)
        SFMCSdk.track(event: event)
        print("[PersonalizationService]   ✓ IdentityEvent tracked with attributes: \(attributes)")
        print("[PersonalizationService] --- END FULL PROFILE IDENTITY ---")
    }

    // MARK: - Preference / Consent Tracking

    /// Sends consent events for each marketing preference using the consentLog schema.
    /// Each preference maps to: purpose (what), status (Opt In / Opt Out), provider (app name).
    func trackPreferenceUpdate(user: UserAccount) {
        guard isSDKReady else {
            print("[PersonalizationService] ⚠️ SDK not ready — skipping PreferenceUpdate event")
            return
        }

        print("[PersonalizationService] --- CONSENT PREFERENCE EVENTS ---")

        let preferences: [(purpose: String, optedIn: Bool)] = [
            ("Marketing Email",    user.marketingEmailOptIn),
            ("Push Notifications", user.marketingPushOptIn),
            ("SMS Marketing",      user.marketingSmsOptIn),
            ("Weekly Digest",      user.weeklyDigestOptIn),
            ("Benefit Alerts",     user.benefitAlertsOptIn),
        ]

        for pref in preferences {
            let status = pref.optedIn ? "Opt In" : "Opt Out"
            let attributes: [String: Any] = [
                "purpose": pref.purpose,
                "status": status,
                "provider": "HealthEquity Mobile App"
            ]
            if let event = CustomEvent(name: "consentLog", attributes: attributes) {
                SFMCSdk.track(event: event)
                print("[PersonalizationService]   ✓ consentLog: purpose=\"\(pref.purpose)\" status=\"\(status)\"")
            }
        }

        print("[PersonalizationService] --- END CONSENT PREFERENCE EVENTS ---")
    }
}
