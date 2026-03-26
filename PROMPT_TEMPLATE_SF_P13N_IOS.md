# Prompt Template: Add Salesforce Einstein Personalization to an Existing iOS SwiftUI App

> **How to use**: Copy this entire document and paste it as a prompt to Claude Code (or any AI coding assistant in Xcode). Replace the `<PLACEHOLDER>` values with your actual Salesforce credentials and app-specific details. The assistant will create all necessary files and wire them into your existing app.

---

## Prompt starts here

I have an existing SwiftUI iOS app and I want to integrate **Salesforce Einstein Personalization SDK** to:

1. **Fetch personalized content decisions** from Salesforce and display them in a home screen hero banner (and optionally a "For You" feed)
2. **Track behavioral events** (page views, impressions, clicks, article detail views) to Salesforce Data Cloud
3. **Capture identity events** (email, phone, full profile) via UI forms to create known profiles in Data Cloud
4. **Set implicit consent** so events flow immediately (demo/dev mode)

Below is the complete technical specification. Follow it exactly.

---

## PART 1: SDK PACKAGES

Add these 3 Swift Package Manager dependencies to the Xcode project:

| Package | URL | Version |
|---------|-----|---------|
| **SFMCSDK** | `https://github.com/nickmcphee-sf/mobile-sdk-cdp-ios` | 3.0.1+ |
| **Cdp** | (included in the above repo) | 3.0.1+ |
| **Personalization** | `https://github.com/nickmcphee-sf/Personalization-IOS` | 1.0.0+ |

Add via **File > Add Package Dependencies** in Xcode.

---

## PART 2: CONFIGURATION

### 2A. SDK Config (`Config/SDKConfig.swift`)

Create this file with the Salesforce credentials:

```swift
import Foundation

enum SDKConfig {
    // MARK: - Data Cloud / CDP Credentials
    // Find these in: Data Cloud Setup > Websites & Mobile Apps > Your Mobile App Connector > Integration Guide
    static let dataCloudAppId: String = "<YOUR-APP-ID>"
    static let dataCloudEndpoint: String = "<YOUR-ENDPOINT-URL>"
    // IMPORTANT: Endpoint must be a valid https:// URL ending in .salesforce.com
    // Common mistake: duplicating the domain suffix (.salesforce.com.salesforce.com)

    // MARK: - Personalization Point Names
    // Must match EXACTLY what is configured in the Salesforce Einstein Personalization UI
    static let featuredStoryPoint = "<YOUR-HERO-P13N-POINT-API-NAME>"
    // Optional: add more points as needed
    static let forYouFeedPoint    = "<YOUR-FEED-P13N-POINT-API-NAME>"

    // MARK: - Fetch Settings
    static let fetchTimeoutSeconds: Double = 5.0

    // MARK: - Consent
    // For demo only — in production, gate on a real consent UI
    static let consentOptIn = true
}
```

**Replace placeholders:**
- `<YOUR-APP-ID>` → from Data Cloud Mobile App Connector (e.g., `"ed3fedc0-d511-444b-9a17-5a748404871a"`)
- `<YOUR-ENDPOINT-URL>` → from Data Cloud Mobile App Connector (e.g., `"https://g-xxxxx.c360a.salesforce.com"`)
- `<YOUR-HERO-P13N-POINT-API-NAME>` → the API name of your personalization point (e.g., `"Home_Hero_Test"`)
- `<YOUR-FEED-P13N-POINT-API-NAME>` → second personalization point if you have one, otherwise remove

### 2B. Theme Config (`Config/Theme.swift`)

Create a brand color theme. Replace `<YOUR-HEX-COLOR>` with your brand's primary color:

```swift
import SwiftUI

enum AppTheme {
    static let primaryColor = Color(hex: "<YOUR-HEX-COLOR>")   // e.g., "00A651" for green
    static let lightColor = Color(hex: "<YOUR-HEX-COLOR>").opacity(0.15)
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let r, g, b: Double
        switch sanitized.count {
        case 6:
            (r, g, b) = (
                Double((int >> 16) & 0xFF) / 255.0,
                Double((int >> 8) & 0xFF) / 255.0,
                Double(int & 0xFF) / 255.0
            )
        case 8:
            (r, g, b) = (
                Double((int >> 16) & 0xFF) / 255.0,
                Double((int >> 8) & 0xFF) / 255.0,
                Double(int & 0xFF) / 255.0
            )
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(red: r, green: g, blue: b)
    }
}
```

---

## PART 3: SDK INITIALIZATION

### 3A. AppDelegate (`App/AppDelegate.swift`)

Create an AppDelegate that initializes the SDK before any SwiftUI view renders:

```swift
import UIKit
import SFMCSDK
import Cdp
import Personalization

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
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
            if SDKConfig.consentOptIn {
                SFMCSdk.cdp.setConsent(consent: .optIn)
                print("[App] CDP consent set to optIn")
            }
        }
    }
}
```

### 3B. App Entry Point

In your `@main` App struct, add the delegate adaptor and inject the ViewModel:

```swift
import SwiftUI

@main
struct YourApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var homeViewModel = HomeViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(homeViewModel)
        }
    }
}
```

---

## PART 4: DATA MODELS

### 4A. Content Model (`Models/Article.swift`)

Adapt this to match your app's content type. The key requirement is `Identifiable` + `Hashable` for `NavigationLink(value:)`:

```swift
import Foundation

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
```

### 4B. SDK Response Parser (`Models/PersonalizationDecision.swift`)

This translates the SDK's `DecisionsResponse` into your typed models:

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

    // IMPORTANT: The attribute key names here must match what you configure in your
    // Salesforce Personalization experiment content. The SDK returns them in an
    // `attributes: [String: Any]` dictionary.
    //
    // Common gotcha: Salesforce may use "imageURL" (capital URL) while you expect "imageUrl".
    // This parser handles both variants.

    private static func parseSingleItem(from personalization: DecisionsResponsePersonalization) -> PersonalizedArticle? {
        let attrs = personalization.attributes

        // Accept both key variants for image URL
        let imageURLString = attrs["imageUrl"] as? String
            ?? attrs["imageURL"] as? String
            ?? (attrs["imageURL"] as? URL)?.absoluteString

        // headline is preferred but not required — falls back for image-only experiments
        let headline = attrs["headline"] as? String ?? attrs["title"] as? String ?? ""

        guard !headline.isEmpty || imageURLString != nil else {
            print("[PersonalizationParser] Skipping — no headline or imageURL in: \(Array(attrs.keys))")
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
        print("[PersonalizationParser] Parsed: headline=\"\(article.headline)\", imageURL=\(article.imageURL?.absoluteString ?? "nil")")
        return article
    }

    private static func parseMultiItem(from personalization: DecisionsResponsePersonalization) -> [PersonalizedArticle] {
        let dataArray = personalization.data
        guard !dataArray.isEmpty else {
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
                imageURL: (item["imageUrl"] as? String ?? item["imageURL"] as? String).flatMap(URL.init),
                readTimeMinutes: item["readTimeMinutes"] as? Int ?? 3
            )
        }
    }
}
```

**Attribute mapping** — your Salesforce experiment content attributes must use these keys (or the parser must be updated to match):

| Parser expects | Alternate accepted | Type | Required? |
|---|---|---|---|
| `headline` | `title` | String | No (falls back to "Featured") |
| `summary` | `description` | String | No |
| `body` | — | String | No |
| `category` | — | String | No (defaults to "Featured") |
| `imageUrl` | `imageURL` | String (URL) | No |
| `readTimeMinutes` | — | Int | No (defaults to 3) |

---

## PART 5: PERSONALIZATION SERVICE

Create `Services/PersonalizationService.swift` — the central SDK wrapper. All methods are `@MainActor` so ViewModels can call them directly.

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

    // MARK: - Fetch Decisions

    func fetchHomeDecisions() async -> PersonalizationDecisionSet {
        guard isSDKReady else {
            print("[PersonalizationService] SDK not ready — returning empty.")
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

            // Debug: log raw response
            print("[PersonalizationService]   Points returned: \(Array(response.personalizationsByName.keys))")
            for (pointName, p) in response.personalizationsByName {
                print("[PersonalizationService]   Point: \(pointName)")
                print("[PersonalizationService]     personalizationId: \(p.personalizationId)")
                print("[PersonalizationService]     attributes: \(p.attributes)")
                print("[PersonalizationService]     data count: \(p.data.count)")
                for (i, item) in p.data.enumerated() {
                    print("[PersonalizationService]     data[\(i)]: \(item)")
                }
            }
            print("[PersonalizationService] --- END FETCH DECISIONS ---")

            return PersonalizationDecisionParser.parse(response: response)
        } catch {
            print("[PersonalizationService] fetchDecisions error: \(error)")
            return .empty
        }
    }

    // MARK: - Behavioral Event Tracking

    func trackHomePageView() {
        guard isSDKReady else { return }
        guard let event = CustomEvent(name: "HomePageView", attributes: ["screen": "home"]) else { return }
        SFMCSdk.track(event: event)
        print("[PersonalizationService] Tracked HomePageView")
    }

    func trackImpression(for article: Article) {
        guard isSDKReady else { return }
        let obj = CatalogObject(type: "Article", id: article.id, attributes: [
            "headline": article.headline, "category": article.category
        ])
        SFMCSdk.track(event: ViewCatalogObjectEvent(catalogObject: obj))
        print("[PersonalizationService] Tracked impression: \(article.id)")
    }

    func trackClick(for article: Article) {
        guard isSDKReady else { return }
        let obj = CatalogObject(type: "Article", id: article.id, attributes: [
            "headline": article.headline, "category": article.category
        ])
        SFMCSdk.track(event: ViewCatalogObjectDetailEvent(catalogObject: obj))
        print("[PersonalizationService] Tracked click: \(article.id)")
    }

    func trackArticleDetailView(for article: Article) {
        guard isSDKReady else { return }
        guard let event = CustomEvent(name: "ArticleDetailView", attributes: [
            "articleId": article.id, "headline": article.headline, "category": article.category
        ]) else { return }
        SFMCSdk.track(event: event)
        print("[PersonalizationService] Tracked ArticleDetailView: \(article.id)")
    }

    // MARK: - Identity Event Tracking

    func trackEmailIdentity(email: String) {
        guard isSDKReady else { return }
        print("[PersonalizationService] --- EMAIL IDENTITY ---")
        print("[PersonalizationService]   profileId = \(email)")
        SFMCSdk.identity.edit { modifier in
            modifier.profileId = email
            modifier.addAttribute(key: "email", value: email)
            return modifier
        }
        let attrs: [String: Any] = ["contactPointEmail": email, "source": "email_signup"]
        SFMCSdk.track(event: IdentityEvent(attributes: attrs))
        print("[PersonalizationService]   IdentityEvent sent: \(attrs)")
        print("[PersonalizationService] --- END EMAIL IDENTITY ---")
    }

    func trackPhoneIdentity(phone: String) {
        guard isSDKReady else { return }
        print("[PersonalizationService] --- PHONE IDENTITY ---")
        print("[PersonalizationService]   phone = \(phone)")
        SFMCSdk.identity.edit { modifier in
            modifier.addAttribute(key: "phone", value: phone)
            return modifier
        }
        let attrs: [String: Any] = ["contactPointPhone": phone, "source": "sms_signup"]
        SFMCSdk.track(event: IdentityEvent(attributes: attrs))
        print("[PersonalizationService]   IdentityEvent sent: \(attrs)")
        print("[PersonalizationService] --- END PHONE IDENTITY ---")
    }

    func trackFullProfileIdentity(email: String, phone: String, firstName: String, lastName: String, zipCode: String) {
        guard isSDKReady else { return }
        print("[PersonalizationService] --- FULL PROFILE IDENTITY ---")
        print("[PersonalizationService]   profileId = \(email)")
        print("[PersonalizationService]   firstName=\(firstName), lastName=\(lastName), phone=\(phone), zip=\(zipCode)")
        SFMCSdk.identity.edit { modifier in
            modifier.profileId = email
            modifier.addAttribute(key: "email", value: email)
            modifier.addAttribute(key: "phone", value: phone)
            modifier.addAttribute(key: "firstName", value: firstName)
            modifier.addAttribute(key: "lastName", value: lastName)
            modifier.addAttribute(key: "zipCode", value: zipCode)
            return modifier
        }
        let attrs: [String: Any] = [
            "contactPointEmail": email, "contactPointPhone": phone,
            "firstName": firstName, "lastName": lastName, "zipCode": zipCode,
            "source": "profile_signup"
        ]
        SFMCSdk.track(event: IdentityEvent(attributes: attrs))
        print("[PersonalizationService]   IdentityEvent sent: \(attrs)")
        print("[PersonalizationService] --- END FULL PROFILE IDENTITY ---")
    }
}
```

---

## PART 6: VIEWMODEL

Create `ViewModels/HomeViewModel.swift`:

```swift
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Content State
    @Published private(set) var featuredArticle: Article?
    @Published private(set) var forYouArticles: [Article] = []
    @Published private(set) var trendingArticles: [Article] = [] // populate with your static content
    @Published private(set) var isLoading = false
    @Published private(set) var hasPersonalizedContent = false

    // MARK: - Identity UI State
    @Published var showPhoneSignupSheet = false
    @Published var showProfileSignupSheet = false
    @Published var identityConfirmationMessage: String? = nil

    private let service: PersonalizationService

    init(service: PersonalizationService = .shared) {
        self.service = service
        // Pre-populate with your mock/default content here
        // self.trendingArticles = YourMockData.trending
    }

    // MARK: - Load Content

    func loadContent() async {
        isLoading = true
        showMockFallback()           // Show defaults immediately
        service.trackHomePageView()  // Track page view

        let decisions = await service.fetchHomeDecisions()
        apply(decisions)             // Replace with personalized content if available

        isLoading = false
    }

    // MARK: - Event Tracking Pass-throughs

    func trackImpression(for article: Article) { service.trackImpression(for: article) }
    func trackClick(for article: Article) { service.trackClick(for: article) }
    func trackArticleDetailView(for article: Article) { service.trackArticleDetailView(for: article) }

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

    private func showConfirmation(_ message: String) {
        identityConfirmationMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            identityConfirmationMessage = nil
        }
    }

    private func showMockFallback() {
        // Replace with your default/mock content
        // if featuredArticle == nil { featuredArticle = YourMockData.featured }
        // if forYouArticles.isEmpty { forYouArticles = YourMockData.forYou }
    }

    private func apply(_ decisions: PersonalizationDecisionSet) {
        if let p = decisions.featuredArticle {
            featuredArticle = Article(
                id: p.id, headline: p.headline, summary: p.summary, body: p.body,
                category: p.category, imageURL: p.imageURL, publishedDate: Date(),
                readTimeMinutes: p.readTimeMinutes, isFeatured: true
            )
            hasPersonalizedContent = true
        }
        if !decisions.forYouArticles.isEmpty {
            forYouArticles = decisions.forYouArticles.map { p in
                Article(
                    id: p.id, headline: p.headline, summary: p.summary, body: p.body,
                    category: p.category, imageURL: p.imageURL, publishedDate: Date(),
                    readTimeMinutes: p.readTimeMinutes, isFeatured: false
                )
            }
            hasPersonalizedContent = true
        }
    }
}
```

---

## PART 7: VIEW WIRING

### Key SwiftUI patterns used:

**Event tracking alongside NavigationLink:**
```swift
// WRONG — .onTapGesture blocks NavigationLink
NavigationLink(value: article) { ArticleCard(article: article) }
    .onTapGesture { trackClick(article) }  // ❌ Blocks navigation

// CORRECT — .simultaneousGesture fires alongside NavigationLink
NavigationLink(value: article) { ArticleCard(article: article) }
    .buttonStyle(.plain)
    .simultaneousGesture(TapGesture().onEnded { trackClick(article) })  // ✅
```

**Impression tracking:**
```swift
.onAppear { viewModel.trackImpression(for: article) }
```

**Navigation destination (centralized in root HomeView):**
```swift
NavigationStack {
    ScrollView { /* content */ }
    .navigationDestination(for: Article.self) { article in
        ArticleDetailView(article: article)
    }
}
```

### HomeView wiring checklist:
- [ ] Wrap content in `NavigationStack`
- [ ] Add `.navigationDestination(for: Article.self)` for detail page routing
- [ ] Add `.task { await viewModel.loadContent() }` for initial data load
- [ ] Add `.refreshable { await viewModel.loadContent() }` for pull-to-refresh
- [ ] Add toolbar button for profile sheet: `Image(systemName: "person.crop.circle")`
- [ ] Add `SMSAlertBannerView()` in scroll content
- [ ] Add `EmailSignupView()` at bottom of scroll content
- [ ] Add `.sheet(isPresented: $viewModel.showPhoneSignupSheet) { PhoneSignupSheet() }`
- [ ] Add `.sheet(isPresented: $viewModel.showProfileSignupSheet) { ProfileSignupSheet() }`
- [ ] Add confirmation toast overlay:
```swift
.overlay(alignment: .bottom) {
    if let message = viewModel.identityConfirmationMessage {
        Text(message)
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.primaryColor)
            .clipShape(Capsule())
            .shadow(radius: 4)
            .padding(.bottom, 32)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut, value: viewModel.identityConfirmationMessage)
    }
}
```

### Identity capture views to create:

1. **EmailSignupView** — inline footer at bottom of scroll, email TextField + Subscribe button
2. **SMSAlertBannerView** — tappable banner (bell icon + text), opens PhoneSignupSheet on tap
3. **PhoneSignupSheet** — modal sheet with phone TextField + Submit button
4. **ProfileSignupSheet** — modal sheet with Form (firstName, lastName, email, phone, zipCode) + Create Profile button

All identity views use `@EnvironmentObject var viewModel: HomeViewModel` and call the corresponding `viewModel.submitEmail/submitPhone/submitProfile` methods.

---

## PART 8: COMMON PITFALLS & FIXES

| Problem | Cause | Fix |
|---------|-------|-----|
| `Cannot find 'SFPersonalization' in scope` | Wrong class name | Use `PersonalizationModule` (Swift name), not `SFPersonalization` |
| `hostname could not be found` | Duplicate domain in endpoint | Check for `.salesforce.com.salesforce.com` — remove the duplicate |
| `ObservableObject` conformance error | Missing import | Add `import Combine` to ViewModel files |
| Events not flowing to Data Cloud | Missing consent | Add `SFMCSdk.cdp.setConsent(consent: .optIn)` in AppDelegate after SDK init |
| `.onTapGesture` blocks NavigationLink | SwiftUI gesture conflict | Use `.simultaneousGesture(TapGesture().onEnded { })` instead |
| Personalized content not showing | Attribute key mismatch | Log `personalization.attributes` and check key names (e.g., `imageURL` vs `imageUrl`) |
| SDK not ready on first render | Async init | Always show mock/fallback content first, replace when SDK responds |

---

## PART 9: SALESFORCE-SIDE CONFIGURATION

These steps must be done in the Salesforce UI (not in the app code):

1. **Data Cloud Setup > Websites & Mobile Apps** — Create a Mobile App Connector, note the App ID and Endpoint URL
2. **Einstein Personalization > Personalization Points** — Create points with API names matching `SDKConfig` (e.g., `Home_Hero_Test`)
3. **Einstein Personalization > Experiments** — Create an experiment, connect it to your personalization point, configure content attributes
4. **Content attributes** — Add at minimum `headline` (String) and `imageUrl` or `imageURL` (String/URL). Optional: `summary`, `body`, `category`, `readTimeMinutes`
5. **Activate the experiment** — Set it to Running so the SDK can fetch decisions

---

## PART 10: DEBUGGING

Filter the Xcode console by `PersonalizationService` to see all events:

```
[App] Module 'cdp' init status: success
[App] CDP consent set to optIn
[PersonalizationService] SDK is ready.
[PersonalizationService] --- FETCH DECISIONS ---
[PersonalizationService]   Requesting points: ["Home_Hero_Test"]
[PersonalizationService]   Points returned: ["Home_Hero_Test"]
[PersonalizationService]   Point: Home_Hero_Test
[PersonalizationService]     personalizationId: <experiment-id>
[PersonalizationService]     attributes: ["imageURL": <url>, "headline": "..."]
[PersonalizationService] --- END FETCH DECISIONS ---
[PersonalizationParser] Parsed: headline="...", imageURL=...
[PersonalizationService] Tracked HomePageView
[PersonalizationService] Tracked impression: <article-id>
[PersonalizationService] Tracked click: <article-id>
[PersonalizationService] --- EMAIL IDENTITY ---
[PersonalizationService]   profileId = user@example.com
[PersonalizationService]   IdentityEvent sent: ["contactPointEmail": "user@example.com", ...]
[PersonalizationService] --- END EMAIL IDENTITY ---
```

---

## SUMMARY: FILES TO CREATE/MODIFY

| # | File | Action | Purpose |
|---|------|--------|---------|
| 1 | `Config/SDKConfig.swift` | Create | Salesforce credentials & point names |
| 2 | `Config/Theme.swift` | Create | Brand colors |
| 3 | `App/AppDelegate.swift` | Create | SDK initialization + consent |
| 4 | `App/YourApp.swift` | Modify | Add `@UIApplicationDelegateAdaptor` + `@StateObject` |
| 5 | `Models/Article.swift` | Create/Modify | Content data model |
| 6 | `Models/PersonalizationDecision.swift` | Create | SDK response parser |
| 7 | `Services/PersonalizationService.swift` | Create | SDK wrapper (fetch + events + identity) |
| 8 | `ViewModels/HomeViewModel.swift` | Create/Modify | State management + event pass-throughs |
| 9 | `Views/HomeView.swift` | Modify | Wire NavigationStack, sheets, toolbar, toast |
| 10 | `Views/FeaturedStoryView.swift` | Create/Modify | Hero banner with AsyncImage + tracking |
| 11 | `Views/ArticleDetailView.swift` | Create | Detail page with tracking on appear |
| 12 | `Views/EmailSignupView.swift` | Create | Email capture footer |
| 13 | `Views/SMSAlertBannerView.swift` | Create | SMS opt-in banner |
| 14 | `Views/PhoneSignupSheet.swift` | Create | Phone capture sheet |
| 15 | `Views/ProfileSignupSheet.swift` | Create | Full profile capture sheet |
