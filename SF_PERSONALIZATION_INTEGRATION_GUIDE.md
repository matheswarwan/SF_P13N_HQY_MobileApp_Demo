# Prompt: Integrate Salesforce Einstein Personalization into an Existing iOS Mobile App

Use this prompt with Claude Code (or any AI coding assistant inside Xcode) to add Salesforce Einstein Personalization SDK to an existing SwiftUI iOS app. This covers the full integration: SDK setup, fetching personalized content decisions, behavioral event tracking (page views, impressions, clicks), and identity event capture (email, phone, full profile).

---

## Context for the AI Assistant

You are integrating the **Salesforce Einstein Personalization SDK** into an existing SwiftUI iOS app. The SDK is distributed as 3 Swift Packages:

- `SFMCSDK` (v3.0.1+) — Core Salesforce Mobile SDK
- `Cdp` (v3.0.1+) — Data Cloud module for event tracking and consent
- `Personalization` (v1.0.0+) — Einstein Personalization module for fetching decisions

The correct Swift class for personalization is `PersonalizationModule` (NOT `SFPersonalization`). The `fetchDecisions` API is `async throws`. Events are sent via `SFMCSdk.track(event:)`. Identity is managed via `SFMCSdk.identity.edit { modifier in ... }`.

---

## Step-by-Step Instructions

### Step 1: Add Swift Package Dependencies

Add these 3 SPM packages to the Xcode project:

| Package | URL | Version |
|---------|-----|---------|
| SFMCSDK | `https://github.com/salesforce-marketingcloud/sfmc-sdk-ios` | 3.0.1+ |
| Cdp | `https://github.com/nickmcphee-sf/mobile-sdk-cdp-ios` | 3.0.1+ |
| Personalization | `https://github.com/nickmcphee-sf/Personalization-IOS` | 1.0.0+ |

In Xcode: **File > Add Package Dependencies** and add each URL.

---

### Step 2: Create SDK Configuration

Create a config file (e.g., `Config/SDKConfig.swift`) with your Salesforce credentials:

```swift
import Foundation

enum SDKConfig {
    // From: Data Cloud Setup > Websites & Mobile Apps > Your Mobile App Connector > Integration Guide
    static let dataCloudAppId: String = "<YOUR-APP-ID>"
    static let dataCloudEndpoint: String = "<YOUR-DATA-CLOUD-ENDPOINT>"

    // Must match exactly what is configured in SF Einstein Personalization UI
    static let featuredStoryPoint = "<YOUR-PERSONALIZATION-POINT-NAME>"
    static let forYouFeedPoint    = "<YOUR-SECOND-POINT-NAME>"

    static let fetchTimeoutSeconds: Double = 5.0
    static let consentOptIn = true  // For demo; use real consent UI in production
}
```

**Important:** The endpoint URL must be a valid `https://` URL ending in `.salesforce.com`. A common mistake is duplicating the domain suffix (`.salesforce.com.salesforce.com`).

---

### Step 3: Initialize the SDK in AppDelegate

You need a `UIApplicationDelegate` because the SDK must initialize before any SwiftUI view body runs. Use `@UIApplicationDelegateAdaptor` in your `@main` App struct.

```swift
import UIKit
import SFMCSDK
import Cdp
import Personalization

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        initializeSDK()
        return true
    }

    private func initializeSDK() {
        #if DEBUG
        SFMCSdk.setLogger(logLevel: .debug, logOutputter: LogOutputter())
        #endif

        let personalizationConfig = PersonalizationConfigBuilder().build()

        let cdpConfig = CdpConfigBuilder(
            appId: SDKConfig.dataCloudAppId,
            endpoint: SDKConfig.dataCloudEndpoint
        )
        .trackScreens(true)
        .trackLifecycle(true)
        .sessionTimeout(600)
        .build()

        SFMCSdk.initializeSdk(
            ConfigBuilder()
                .setCdp(config: cdpConfig)
                .setPersonalization(config: personalizationConfig)
                .build()
        ) { moduleStatuses in
            for status in moduleStatuses {
                print("[App] Module '\(status.moduleName)' init status: \(status.initStatus)")
                if status.initStatus == .success {
                    Task { @MainActor in
                        PersonalizationService.shared.markSDKReady()
                    }
                }
            }
            // Set implicit consent so events flow to Data Cloud
            if SDKConfig.consentOptIn {
                SFMCSdk.cdp.setConsent(consent: .optIn)
                print("[App] CDP consent set to optIn")
            }
        }
    }
}
```

In your `@main` App struct:
```swift
@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
```

---

### Step 4: Create the Personalization Service

This singleton wraps all SDK interactions. Mark it `@MainActor` so SwiftUI ViewModels can call it directly.

```swift
import Foundation
import Personalization
import SFMCSDK

@MainActor
final class PersonalizationService {
    static let shared = PersonalizationService()
    private init() {}

    private(set) var isSDKReady = false

    func markSDKReady() {
        isSDKReady = true
        print("[PersonalizationService] SDK is ready.")
    }
}
```

---

### Step 5: Add Personalized Content Fetching

Add this method to `PersonalizationService`:

```swift
func fetchHomeDecisions() async -> PersonalizationDecisionSet {
    guard isSDKReady else {
        print("[PersonalizationService] SDK not ready — returning empty.")
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
```

Create the response parser. The SDK returns `DecisionsResponse` with `personalizationsByName` dictionary. Each personalization has `attributes` (for single-item) and `data` array (for multi-item):

```swift
import Foundation
import Personalization

struct PersonalizedArticle: Identifiable {
    let id: String
    let headline: String
    let summary: String
    let body: String
    let category: String
    let imageURL: URL?
    let readTimeMinutes: Int
}

struct PersonalizationDecisionSet {
    let featuredArticle: PersonalizedArticle?
    let forYouArticles: [PersonalizedArticle]
    static let empty = PersonalizationDecisionSet(featuredArticle: nil, forYouArticles: [])
}

enum PersonalizationDecisionParser {
    static func parse(response: DecisionsResponse) -> PersonalizationDecisionSet {
        let byName = response.personalizationsByName
        let featured = byName[SDKConfig.featuredStoryPoint].flatMap { parseSingleItem(from: $0) }
        let feed = byName[SDKConfig.forYouFeedPoint].map { parseMultiItem(from: $0) } ?? []
        return PersonalizationDecisionSet(featuredArticle: featured, forYouArticles: feed)
    }

    private static func parseSingleItem(from p: DecisionsResponsePersonalization) -> PersonalizedArticle? {
        let attrs = p.attributes
        guard let headline = attrs["headline"] as? String else { return nil }
        return PersonalizedArticle(
            id: p.personalizationId,
            headline: headline,
            summary: attrs["summary"] as? String ?? "",
            body: attrs["body"] as? String ?? "",
            category: attrs["category"] as? String ?? "News",
            imageURL: (attrs["imageUrl"] as? String).flatMap(URL.init),
            readTimeMinutes: attrs["readTimeMinutes"] as? Int ?? 3
        )
    }

    private static func parseMultiItem(from p: DecisionsResponsePersonalization) -> [PersonalizedArticle] {
        return p.data.compactMap { item in
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
```

**Key:** The JSON field names (`headline`, `summary`, `body`, `category`, `imageUrl`, `readTimeMinutes`) must match what you configure in your Salesforce Personalization catalog.

---

### Step 6: Add Behavioral Event Tracking

Add these methods to `PersonalizationService`:

```swift
// MARK: - Behavioral Event Tracking

/// Page view event
func trackHomePageView() {
    guard isSDKReady else { return }
    guard let event = CustomEvent(name: "HomePageView", attributes: ["screen": "home"]) else { return }
    SFMCSdk.track(event: event)
    print("[PersonalizationService] Tracked HomePageView event")
}

/// Impression — article becomes visible on screen
func trackImpression(for article: Article) {
    guard isSDKReady else { return }
    let catalogObject = CatalogObject(type: "Article", id: article.id, attributes: [
        "headline": article.headline, "category": article.category
    ])
    SFMCSdk.track(event: ViewCatalogObjectEvent(catalogObject: catalogObject))
    print("[PersonalizationService] Tracked impression for article: \(article.id)")
}

/// Click — user taps an article
func trackClick(for article: Article) {
    guard isSDKReady else { return }
    let catalogObject = CatalogObject(type: "Article", id: article.id, attributes: [
        "headline": article.headline, "category": article.category
    ])
    SFMCSdk.track(event: ViewCatalogObjectDetailEvent(catalogObject: catalogObject))
    print("[PersonalizationService] Tracked click for article: \(article.id)")
}

/// Detail view — user opens the full article
func trackArticleDetailView(for article: Article) {
    guard isSDKReady else { return }
    guard let event = CustomEvent(name: "ArticleDetailView", attributes: [
        "articleId": article.id, "headline": article.headline, "category": article.category
    ]) else { return }
    SFMCSdk.track(event: event)
    print("[PersonalizationService] Tracked ArticleDetailView for article: \(article.id)")
}
```

**Where to call these in SwiftUI views:**
- `trackHomePageView()` — in `.task {}` or `.onAppear` of your home screen
- `trackImpression(for:)` — in `.onAppear` of each article card/row
- `trackClick(for:)` — use `.simultaneousGesture(TapGesture().onEnded { })` alongside `NavigationLink` (`.onTapGesture` blocks NavigationLink)
- `trackArticleDetailView(for:)` — in `.onAppear` of the detail page

---

### Step 7: Add Identity Event Tracking

Add these methods to `PersonalizationService` for capturing known user identity:

```swift
// MARK: - Identity Tracking

/// Email identity — sets email as profileId
func trackEmailIdentity(email: String) {
    guard isSDKReady else { return }
    SFMCSdk.identity.edit { modifier in
        modifier.profileId = email
        modifier.addAttribute(key: "email", value: email)
        return modifier
    }
    let event = IdentityEvent(attributes: [
        "contactPointEmail": email,
        "source": "email_signup"
    ])
    SFMCSdk.track(event: event)
    print("[PersonalizationService] Tracked EmailIdentity for: \(email)")
}

/// Phone identity
func trackPhoneIdentity(phone: String) {
    guard isSDKReady else { return }
    SFMCSdk.identity.edit { modifier in
        modifier.addAttribute(key: "phone", value: phone)
        return modifier
    }
    let event = IdentityEvent(attributes: [
        "contactPointPhone": phone,
        "source": "phone_signup"
    ])
    SFMCSdk.track(event: event)
    print("[PersonalizationService] Tracked PhoneIdentity for: \(phone)")
}

/// Full profile identity
func trackFullProfileIdentity(email: String, phone: String, firstName: String, lastName: String, zipCode: String) {
    guard isSDKReady else { return }
    SFMCSdk.identity.edit { modifier in
        modifier.profileId = email
        modifier.addAttribute(key: "email", value: email)
        modifier.addAttribute(key: "phone", value: phone)
        modifier.addAttribute(key: "firstName", value: firstName)
        modifier.addAttribute(key: "lastName", value: lastName)
        modifier.addAttribute(key: "zipCode", value: zipCode)
        return modifier
    }
    let event = IdentityEvent(attributes: [
        "contactPointEmail": email,
        "contactPointPhone": phone,
        "firstName": firstName,
        "lastName": lastName,
        "zipCode": zipCode,
        "source": "profile_signup"
    ])
    SFMCSdk.track(event: event)
    print("[PersonalizationService] Tracked FullProfileIdentity for: \(email)")
}
```

**Identity UI surfaces to create:**
1. **Email footer** — inline component at the bottom of a scrollable page with an email TextField + Subscribe button
2. **SMS banner** — tappable banner that opens a phone number sheet
3. **Profile sheet** — toolbar button that opens a full form (first name, last name, email, phone, zip code)

---

### Step 8: Wire into SwiftUI ViewModel

Create a ViewModel that:
- Calls `PersonalizationService.shared.fetchHomeDecisions()` on load
- Falls back to mock data if the SDK returns empty
- Exposes tracking pass-through methods for views to call
- Manages identity sheet state (`showPhoneSignupSheet`, `showProfileSignupSheet`)

```swift
@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var featuredArticle: Article?
    @Published private(set) var forYouArticles: [Article] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasPersonalizedContent = false

    // Identity UI state
    @Published var showPhoneSignupSheet = false
    @Published var showProfileSignupSheet = false
    @Published var identityConfirmationMessage: String? = nil

    private let service: PersonalizationService

    init(service: PersonalizationService = .shared) {
        self.service = service
    }

    func loadContent() async {
        isLoading = true
        // Show mock data immediately as placeholder
        if featuredArticle == nil { featuredArticle = MockData.featuredArticle }
        if forYouArticles.isEmpty { forYouArticles = MockData.forYouArticles }

        service.trackHomePageView()
        let decisions = await service.fetchHomeDecisions()

        // Replace with personalized content if available
        if let featured = decisions.featuredArticle {
            featuredArticle = Article(from: featured, isFeatured: true)
            hasPersonalizedContent = true
        }
        if !decisions.forYouArticles.isEmpty {
            forYouArticles = decisions.forYouArticles.map { Article(from: $0, isFeatured: false) }
            hasPersonalizedContent = true
        }
        isLoading = false
    }

    func trackImpression(for article: Article) { service.trackImpression(for: article) }
    func trackClick(for article: Article) { service.trackClick(for: article) }
    func trackArticleDetailView(for article: Article) { service.trackArticleDetailView(for: article) }

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

    private func showConfirmation(_ message: String) {
        identityConfirmationMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            identityConfirmationMessage = nil
        }
    }
}
```

---

## Common Pitfalls

1. **Wrong class name** — Use `PersonalizationModule` (Swift), NOT `SFPersonalization`
2. **Duplicate domain in endpoint** — `...salesforce.com.salesforce.com` won't resolve
3. **Missing `import Combine`** — Required for `ObservableObject` and `@Published` in ViewModels
4. **Missing consent** — Events won't flow without `SFMCSdk.cdp.setConsent(consent: .optIn)`
5. **`.onTapGesture` blocks NavigationLink** — Use `.simultaneousGesture(TapGesture().onEnded { })` for click tracking alongside navigation
6. **SDK not ready on first render** — Always show mock/fallback data first, then replace with personalized content when the SDK responds

---

## Event Reference

### Behavioral Events (via `SFMCSdk.track(event:)`)

| Event | SDK Class | Trigger |
|-------|-----------|---------|
| Page View | `CustomEvent("HomePageView")` | Screen loads |
| Impression | `ViewCatalogObjectEvent` | Article visible on screen |
| Click | `ViewCatalogObjectDetailEvent` | Article tapped |
| Detail View | `CustomEvent("ArticleDetailView")` | Detail page loads |

### Identity Events (via `SFMCSdk.identity.edit` + `SFMCSdk.track(event: IdentityEvent(...))`)

| Event | Data Sent |
|-------|-----------|
| Email Identity | `contactPointEmail`, `source` |
| Phone Identity | `contactPointPhone`, `source` |
| Full Profile | `contactPointEmail`, `contactPointPhone`, `firstName`, `lastName`, `zipCode`, `source` |

### Automatic Events (via CDP module config)

| Event | Config |
|-------|--------|
| Screen Views | `trackScreens(true)` |
| App Lifecycle | `trackLifecycle(true)` |

---

## Debugging

Filter the Xcode console by `PersonalizationService` to see all events. Enable SDK debug logging in AppDelegate:

```swift
#if DEBUG
SFMCSdk.setLogger(logLevel: .debug, logOutputter: LogOutputter())
#endif
```

---

## Salesforce-Side Configuration Required

1. **Data Cloud Setup** — Create a Mobile App Connector and note the App ID + Endpoint URL
2. **Einstein Personalization** — Create Personalization Points matching the names in `SDKConfig`
3. **Catalog** — Create catalog objects with fields matching the JSON keys the parser expects (`headline`, `summary`, `body`, `category`, `imageUrl`, `readTimeMinutes`)
4. **Decision Strategy** — Define audience rules and connect catalog items to personalization points
