# Prompt Template: Add Salesforce Einstein Personalization to an Existing iOS SwiftUI App

> **How to use**: Copy this entire document and paste it as a prompt to Claude Code (or any AI coding assistant in Xcode). Replace the `<PLACEHOLDER>` values with your actual Salesforce credentials and app-specific details. The assistant will create all necessary files and wire them into your existing app.

---

## Prompt starts here

I have an existing SwiftUI iOS app and I want to integrate **Salesforce Einstein Personalization SDK** to:

1. **Fetch personalized content decisions** from Salesforce and display them in a home screen hero banner (and optionally a "For You" feed)
2. **Track behavioral events** (page views, impressions, clicks, article detail views) to Salesforce Data Cloud
3. **Capture identity events** (email, phone, full profile) via UI forms to create known profiles in Data Cloud
4. **Set implicit consent** so events flow immediately (demo/dev mode)
5. **Local multi-user authentication** — users can create accounts, log in/out, and switch users; each login sends identity to Data Cloud
6. **Profile editing** — editable profile screen with personal info, gender, and marketing preference toggles
7. **Consent event tracking** — marketing preferences sent as `consentLog` events using Salesforce's consent schema (purpose / status / provider)

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

In your `@main` App struct, add the delegate adaptor. The root view conditionally shows `LoginView` or `HomeView` based on auth state. On user switch, content reloads automatically:

```swift
import SwiftUI

@main
struct YourApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isLoggedIn {
                    HomeView()
                        .environmentObject(homeViewModel)
                        .environmentObject(authViewModel)
                        .task(id: authViewModel.currentUser?.id) {
                            await homeViewModel.loadContent()
                        }
                } else {
                    LoginView()
                        .environmentObject(authViewModel)
                }
            }
        }
    }
}
```

> **Key pattern**: `.task(id: authViewModel.currentUser?.id)` re-triggers whenever the user changes (login, logout, or switch account), so the home screen always reloads with the new identity's personalized content.

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

    // MARK: - Auth Identity Management

    /// Sets the Salesforce identity profile for a logged-in local user.
    /// Called on login, signup, and profile update.
    ///
    /// IMPORTANT SCHEMA KEY MAPPING:
    /// - Phone must be "phoneNumber" (NOT "phone")
    /// - Zip code must be "postalCode" (NOT "zipCode")
    /// - Gender uses "Gender" (capital G — custom field, must be added to your data stream schema)
    func setUserIdentity(user: UserAccount) {
        guard isSDKReady else { return }
        print("[PersonalizationService] --- SET USER IDENTITY ---")
        SFMCSdk.identity.edit { modifier in
            modifier.profileId = user.email
            modifier.addAttribute(key: "email", value: user.email)
            if !user.firstName.isEmpty { modifier.addAttribute(key: "firstName", value: user.firstName) }
            if !user.lastName.isEmpty  { modifier.addAttribute(key: "lastName",  value: user.lastName) }
            if !user.phone.isEmpty     { modifier.addAttribute(key: "phoneNumber", value: user.phone) }
            if !user.zipCode.isEmpty   { modifier.addAttribute(key: "postalCode",  value: user.zipCode) }
            if !user.gender.isEmpty    { modifier.addAttribute(key: "Gender",      value: user.gender) }
            return modifier
        }
        var attrs: [String: Any] = ["contactPointEmail": user.email, "source": "local_auth_login"]
        if !user.phone.isEmpty   { attrs["phoneNumber"] = user.phone }
        if !user.zipCode.isEmpty { attrs["postalCode"]  = user.zipCode }
        if !user.gender.isEmpty  { attrs["Gender"]      = user.gender }
        SFMCSdk.track(event: IdentityEvent(attributes: attrs))
        print("[PersonalizationService] --- END SET USER IDENTITY ---")
    }

    /// Clears the current identity, reverting to anonymous. Called on logout.
    /// IMPORTANT: Use CdpModule.shared — NOT SFMCSdk.cdp (which has no setProfileToAnonymous).
    func clearIdentity() {
        guard isSDKReady else { return }
        CdpModule.shared.setProfileToAnonymous()
        print("[PersonalizationService] ✓ CDP profile set to anonymous (logout)")
    }

    // MARK: - Identity Event Tracking (UI Forms)

    func trackEmailIdentity(email: String) {
        guard isSDKReady else { return }
        SFMCSdk.identity.edit { modifier in
            modifier.profileId = email
            modifier.addAttribute(key: "email", value: email)
            return modifier
        }
        SFMCSdk.track(event: IdentityEvent(attributes: [
            "contactPointEmail": email, "source": "email_signup"
        ]))
    }

    func trackPhoneIdentity(phone: String) {
        guard isSDKReady else { return }
        SFMCSdk.identity.edit { modifier in
            modifier.addAttribute(key: "phoneNumber", value: phone)  // NOT "phone"
            return modifier
        }
        SFMCSdk.track(event: IdentityEvent(attributes: [
            "phoneNumber": phone, "source": "sms_signup"  // NOT "contactPointPhone"
        ]))
    }

    func trackFullProfileIdentity(email: String, phone: String, firstName: String,
                                   lastName: String, zipCode: String) {
        guard isSDKReady else { return }
        SFMCSdk.identity.edit { modifier in
            modifier.profileId = email
            modifier.addAttribute(key: "email", value: email)
            modifier.addAttribute(key: "phoneNumber", value: phone)   // NOT "phone"
            modifier.addAttribute(key: "firstName", value: firstName)
            modifier.addAttribute(key: "lastName", value: lastName)
            modifier.addAttribute(key: "postalCode", value: zipCode)  // NOT "zipCode"
            return modifier
        }
        SFMCSdk.track(event: IdentityEvent(attributes: [
            "contactPointEmail": email, "phoneNumber": phone,
            "firstName": firstName, "lastName": lastName,
            "postalCode": zipCode, "source": "profile_signup"
        ]))
    }

    // MARK: - Consent / Preference Tracking

    /// Sends consent events for each marketing preference using Salesforce's consentLog schema.
    /// Each preference maps to: purpose (what), status ("Opt In" / "Opt Out"), provider (app name).
    ///
    /// This follows the official consent schema:
    /// https://developer.salesforce.com/docs/data/data-cloud-engagement-mobile-sdk/guide/c360a-api-engagement-mobile-sdk-consent-schema.html
    func trackPreferenceUpdate(user: UserAccount) {
        guard isSDKReady else { return }
        let preferences: [(purpose: String, optedIn: Bool)] = [
            ("Marketing Email",    user.marketingEmailOptIn),
            ("Push Notifications", user.marketingPushOptIn),
            ("SMS Marketing",      user.marketingSmsOptIn),
            ("Weekly Digest",      user.weeklyDigestOptIn),
            ("Benefit Alerts",     user.benefitAlertsOptIn),
        ]
        for pref in preferences {
            let status = pref.optedIn ? "Opt In" : "Opt Out"
            if let event = CustomEvent(name: "consentLog", attributes: [
                "purpose": pref.purpose,
                "status": status,
                "provider": "HealthEquity Mobile App"
            ]) {
                SFMCSdk.track(event: event)
            }
        }
    }
}
```

> **Schema key mapping** — these must match the Data Cloud engagement data stream schema exactly:
>
> | App concept | Correct SDK key | Wrong (will NOT map) |
> |---|---|---|
> | Phone number | `phoneNumber` | `phone`, `contactPointPhone` |
> | Postal / Zip code | `postalCode` | `zipCode` |
> | Gender | `Gender` (custom — add to schema) | `gender` |
> | Email | `email` / `contactPointEmail` | ✓ (both work) |
>
> **Imports required**: `import Cdp` is needed for `CdpModule.shared.setProfileToAnonymous()`. Without it, you'll get a compile error — `SFMCSdk.cdp` does NOT expose this method.

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
        resetContent()               // Clear stale content (important on user switch)
        isLoading = true
        showMockFallback()           // Show defaults immediately
        service.trackHomePageView()  // Track page view

        let decisions = await service.fetchHomeDecisions()
        apply(decisions)             // Replace with personalized content if available

        isLoading = false
    }

    /// Resets all content state. Called at the top of loadContent() so that switching
    /// users starts with a clean slate instead of showing the previous user's content.
    func resetContent() {
        featuredArticle = nil
        forYouArticles = []
        hasPersonalizedContent = false
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
- [ ] Add `.refreshable { await viewModel.loadContent() }` for pull-to-refresh
- [ ] Add `@EnvironmentObject var authViewModel: AuthViewModel`
- [ ] Add toolbar `Menu` with current user display name, "View Profile" action, and "Sign Out" action
- [ ] Add `.sheet(isPresented: $viewModel.showProfileView)` for ProfileView (NOT old ProfileSignupSheet)
- [ ] Add `SMSAlertBannerView()` in scroll content
- [ ] Add `EmailSignupView()` at bottom of scroll content
- [ ] Add `.sheet(isPresented: $viewModel.showPhoneSignupSheet) { PhoneSignupSheet() }`

**Toolbar Menu pattern** — replaces the old single toolbar button:
```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Menu {
            if let user = authViewModel.currentUser {
                Text(user.displayName)
            }
            Button("View Profile") { viewModel.showProfileView = true }
            Divider()
            Button("Sign Out", role: .destructive) { authViewModel.logout() }
        } label: {
            Image(systemName: "person.crop.circle")
                .foregroundStyle(AppTheme.primaryColor)
        }
    }
}
```
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
| `Value of type 'CDP' has no member 'setProfileToAnonymous'` | Wrong API | Use `CdpModule.shared.setProfileToAnonymous()` with `import Cdp` — NOT `SFMCSdk.cdp` |
| `Value of optional type 'CustomEvent?' must be unwrapped` | `CustomEvent` init returns optional | Use `if let event = CustomEvent(...) { SFMCSdk.track(event: event) }` |
| Identity data not mapping in Data Cloud | Wrong attribute key names | Use `phoneNumber` (not `phone`), `postalCode` (not `zipCode`), `phoneNumber` in IdentityEvent (not `contactPointPhone`) |
| `Button` inside `Form` with `listRowBackground` silently swallows taps | SwiftUI Form bug | Move action buttons to `.toolbar { ToolbarItem(placement: .confirmationAction) }` instead |
| Preferences not appearing in Data Cloud | Sent as custom identity attributes | Use `consentLog` events with `purpose`/`status`/`provider` keys (see Salesforce consent schema docs) |

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

--- Login / Signup ---
[PersonalizationService] --- SET USER IDENTITY ---
[PersonalizationService]   profileId  = user@example.com
[PersonalizationService]   firstName  = John
[PersonalizationService]   lastName   = Smith
[PersonalizationService]   phoneNumber = 555-1234
[PersonalizationService]   postalCode  = 84095
[PersonalizationService]   Gender     = Male
[PersonalizationService]   ✓ identity.edit complete
[PersonalizationService]   ✓ IdentityEvent tracked: ["contactPointEmail": "user@example.com", ...]
[PersonalizationService] --- END SET USER IDENTITY ---

--- Personalized Content ---
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

--- Profile Update with Consent ---
[PersonalizationService] --- SET USER IDENTITY ---
...
[PersonalizationService] --- CONSENT PREFERENCE EVENTS ---
[PersonalizationService]   ✓ consentLog: purpose="Marketing Email" status="Opt In"
[PersonalizationService]   ✓ consentLog: purpose="Push Notifications" status="Opt Out"
[PersonalizationService]   ✓ consentLog: purpose="SMS Marketing" status="Opt In"
[PersonalizationService]   ✓ consentLog: purpose="Weekly Digest" status="Opt In"
[PersonalizationService]   ✓ consentLog: purpose="Benefit Alerts" status="Opt Out"
[PersonalizationService] --- END CONSENT PREFERENCE EVENTS ---

--- Logout ---
[PersonalizationService] ✓ CDP profile set to anonymous (logout)
```

---

Now add the new parts for local authentication, login/signup, and profile editing.

---

## PART 11: LOCAL AUTHENTICATION SYSTEM

This adds a local multi-user auth system. Accounts are stored as JSON in the app's Documents directory (plain-text passwords — this is a demo app, not production).

### 11A. User Account Model (`Models/UserAccount.swift`)

```swift
import Foundation

struct UserAccount: Codable, Identifiable, Equatable {
    let id: UUID
    var email: String
    var password: String
    var firstName: String
    var lastName: String
    var phone: String
    var zipCode: String
    var gender: String

    // Marketing preferences
    var marketingEmailOptIn: Bool
    var marketingPushOptIn: Bool
    var marketingSmsOptIn: Bool
    var weeklyDigestOptIn: Bool
    var benefitAlertsOptIn: Bool

    var displayName: String {
        let name = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? email : name
    }

    var initials: String {
        let parts = [firstName, lastName].filter { !$0.isEmpty }
        if parts.isEmpty { return String(email.prefix(1)).uppercased() }
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    init(id: UUID = UUID(), email: String, password: String,
         firstName: String = "", lastName: String = "",
         phone: String = "", zipCode: String = "", gender: String = "",
         marketingEmailOptIn: Bool = false, marketingPushOptIn: Bool = false,
         marketingSmsOptIn: Bool = false, weeklyDigestOptIn: Bool = false,
         benefitAlertsOptIn: Bool = false) {
        self.id = id
        self.email = email
        self.password = password
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.zipCode = zipCode
        self.gender = gender
        self.marketingEmailOptIn = marketingEmailOptIn
        self.marketingPushOptIn = marketingPushOptIn
        self.marketingSmsOptIn = marketingSmsOptIn
        self.weeklyDigestOptIn = weeklyDigestOptIn
        self.benefitAlertsOptIn = benefitAlertsOptIn
    }
}
```

### 11B. Auth Service (`Services/AuthService.swift`)

```swift
import Foundation

final class AuthService {
    static let shared = AuthService()

    private var accounts: [UserAccount] = []
    private let fileURL: URL

    enum AuthError: LocalizedError {
        case emailAlreadyExists, invalidCredentials, emptyEmail, emptyPassword
        var errorDescription: String? {
            switch self {
            case .emailAlreadyExists: return "An account with this email already exists."
            case .invalidCredentials: return "Invalid email or password."
            case .emptyEmail:         return "Please enter an email address."
            case .emptyPassword:      return "Please enter a password."
            }
        }
    }

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("user_accounts.json")
        loadAccounts()
    }

    func signup(email: String, password: String,
                firstName: String = "", lastName: String = "",
                gender: String = "") throws -> UserAccount {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedEmail.isEmpty else { throw AuthError.emptyEmail }
        guard !password.isEmpty else { throw AuthError.emptyPassword }
        guard !accounts.contains(where: { $0.email == trimmedEmail }) else {
            throw AuthError.emailAlreadyExists
        }
        let account = UserAccount(email: trimmedEmail, password: password,
                                   firstName: firstName, lastName: lastName,
                                   gender: gender)
        accounts.append(account)
        saveAccounts()
        return account
    }

    func login(email: String, password: String) throws -> UserAccount {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedEmail.isEmpty else { throw AuthError.emptyEmail }
        guard !password.isEmpty else { throw AuthError.emptyPassword }
        guard let account = accounts.first(where: {
            $0.email == trimmedEmail && $0.password == password
        }) else { throw AuthError.invalidCredentials }
        return account
    }

    func account(forEmail email: String) -> UserAccount? {
        accounts.first { $0.email == email.lowercased() }
    }

    func updateAccount(_ updated: UserAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == updated.id }) else { return }
        accounts[index] = updated
        saveAccounts()
    }

    private func loadAccounts() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([UserAccount].self, from: data)
        else { return }
        accounts = decoded
    }

    private func saveAccounts() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        try? data.write(to: fileURL)
    }
}
```

### 11C. Auth ViewModel (`ViewModels/AuthViewModel.swift`)

```swift
import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: UserAccount?
    @Published var errorMessage: String?

    private let authService = AuthService.shared
    private let personalizationService = PersonalizationService.shared
    private let loggedInEmailKey = "loggedInUserEmail"

    init() { restoreSession() }

    func login(email: String, password: String) {
        do {
            let account = try authService.login(email: email, password: password)
            setCurrentUser(account)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signup(email: String, password: String,
                firstName: String, lastName: String, gender: String = "") {
        do {
            let account = try authService.signup(email: email, password: password,
                                                  firstName: firstName, lastName: lastName,
                                                  gender: gender)
            setCurrentUser(account)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        personalizationService.clearIdentity()
        currentUser = nil
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: loggedInEmailKey)
    }

    func updateProfile(_ updated: UserAccount) {
        authService.updateAccount(updated)
        currentUser = updated
        UserDefaults.standard.set(updated.email, forKey: loggedInEmailKey)
        personalizationService.setUserIdentity(user: updated)
        personalizationService.trackPreferenceUpdate(user: updated)
    }

    private func setCurrentUser(_ account: UserAccount) {
        currentUser = account
        isLoggedIn = true
        errorMessage = nil
        UserDefaults.standard.set(account.email, forKey: loggedInEmailKey)
        personalizationService.setUserIdentity(user: account)
    }

    private func restoreSession() {
        guard let email = UserDefaults.standard.string(forKey: loggedInEmailKey),
              let account = authService.account(forEmail: email) else { return }
        currentUser = account
        isLoggedIn = true
    }
}
```

---

## PART 12: LOGIN & SIGNUP VIEWS

### 12A. Login View (`Views/LoginView.swift`)

```swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showSignup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                // Brand header
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(AppTheme.primaryColor)
                    Text("<YOUR-APP-NAME>")
                        .font(.title.bold())
                    Text("Your benefits companion")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Login form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)

                if let error = authViewModel.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }

                Button {
                    authViewModel.login(email: email, password: password)
                } label: {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                Button("Don't have an account? Create one") { showSignup = true }
                    .font(.subheadline)

                Spacer()
            }
            .sheet(isPresented: $showSignup) {
                SignupView().environmentObject(authViewModel)
            }
        }
    }
}
```

### 12B. Signup View (`Views/SignupView.swift`)

```swift
import SwiftUI

struct SignupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var gender = ""

    private let genderOptions = ["", "Male", "Female", "Non-binary", "Prefer not to say"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Account (Required)") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("Password", text: $password)
                }
                Section("Profile (Optional)") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    Picker("Gender", selection: $gender) {
                        ForEach(genderOptions, id: \.self) { option in
                            Text(option.isEmpty ? "Select" : option).tag(option)
                        }
                    }
                }
                if let error = authViewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
                Section {
                    Button("Create Account") {
                        authViewModel.signup(email: email, password: password,
                                             firstName: firstName, lastName: lastName,
                                             gender: gender)
                        if authViewModel.isLoggedIn { dismiss() }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .listRowBackground(AppTheme.primaryColor)
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
```

---

## PART 13: PROFILE EDITING & CONSENT PREFERENCES

### ProfileView (`Views/ProfileView.swift`)

Full-screen profile editor with personal info, gender, and marketing preference toggles. On save, it calls `authViewModel.updateProfile()` which sends both identity + consent events.

```swift
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var zipCode = ""
    @State private var gender = ""

    // Preferences
    @State private var marketingEmailOptIn = false
    @State private var marketingPushOptIn = false
    @State private var marketingSmsOptIn = false
    @State private var weeklyDigestOptIn = false
    @State private var benefitAlertsOptIn = false

    private let genderOptions = ["", "Male", "Female", "Non-binary", "Prefer not to say"]

    var body: some View {
        NavigationStack {
            Form {
                // Avatar header
                Section {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle().fill(AppTheme.primaryColor).frame(width: 80, height: 80)
                            Text(authViewModel.currentUser?.initials ?? "?")
                                .font(.title.bold()).foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section("Personal Information") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    Picker("Gender", selection: $gender) {
                        ForEach(genderOptions, id: \.self) { Text($0.isEmpty ? "Select" : $0).tag($0) }
                    }
                }
                Section("Contact Information") {
                    HStack { Text("Email"); Spacer()
                        Text(authViewModel.currentUser?.email ?? "").foregroundStyle(.secondary)
                    }
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Zip Code", text: $zipCode).keyboardType(.numberPad)
                }
                Section("Marketing Preferences") {
                    Toggle("Marketing Emails", isOn: $marketingEmailOptIn)
                    Toggle("Push Notifications", isOn: $marketingPushOptIn)
                    Toggle("SMS Marketing", isOn: $marketingSmsOptIn)
                    Toggle("Weekly Digest", isOn: $weeklyDigestOptIn)
                    Toggle("Benefit Alerts", isOn: $benefitAlertsOptIn)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProfile() }.fontWeight(.semibold)
                }
            }
            .onAppear { loadCurrentValues() }
        }
    }

    private func loadCurrentValues() {
        guard let user = authViewModel.currentUser else { return }
        firstName = user.firstName; lastName = user.lastName
        phone = user.phone; zipCode = user.zipCode; gender = user.gender
        marketingEmailOptIn = user.marketingEmailOptIn
        marketingPushOptIn = user.marketingPushOptIn
        marketingSmsOptIn = user.marketingSmsOptIn
        weeklyDigestOptIn = user.weeklyDigestOptIn
        benefitAlertsOptIn = user.benefitAlertsOptIn
    }

    private func saveProfile() {
        guard var user = authViewModel.currentUser else { return }
        user.firstName = firstName.trimmingCharacters(in: .whitespaces)
        user.lastName = lastName.trimmingCharacters(in: .whitespaces)
        user.phone = phone.trimmingCharacters(in: .whitespaces)
        user.zipCode = zipCode.trimmingCharacters(in: .whitespaces)
        user.gender = gender
        user.marketingEmailOptIn = marketingEmailOptIn
        user.marketingPushOptIn = marketingPushOptIn
        user.marketingSmsOptIn = marketingSmsOptIn
        user.weeklyDigestOptIn = weeklyDigestOptIn
        user.benefitAlertsOptIn = benefitAlertsOptIn
        authViewModel.updateProfile(user)
        dismiss()
    }
}
```

> **Important SwiftUI pattern**: The Save button is in `.toolbar` (not inline in the Form). A `Button` inside a `Form` `Section` with `listRowBackground` will silently swallow taps — this is a known SwiftUI bug. Always use toolbar buttons for Form save actions.

> **Data flow on save**: `saveProfile()` → `authViewModel.updateProfile(user)` → `personalizationService.setUserIdentity(user)` (identity event) + `personalizationService.trackPreferenceUpdate(user)` (5 consent events)

---

## SUMMARY: FILES TO CREATE/MODIFY

| # | File | Action | Purpose |
|---|------|--------|---------|
| 1 | `Config/SDKConfig.swift` | Create | Salesforce credentials & point names |
| 2 | `Config/Theme.swift` | Create | Brand colors |
| 3 | `App/AppDelegate.swift` | Create | SDK initialization + consent |
| 4 | `App/YourApp.swift` | Modify | Conditional root view (auth gate), inject `AuthViewModel` |
| 5 | `Models/Article.swift` | Create/Modify | Content data model |
| 6 | `Models/PersonalizationDecision.swift` | Create | SDK response parser |
| 7 | `Models/UserAccount.swift` | Create | Local user account model with preferences |
| 8 | `Services/PersonalizationService.swift` | Create | SDK wrapper (fetch + events + identity + consent) |
| 9 | `Services/AuthService.swift` | Create | Local JSON-based account storage |
| 10 | `ViewModels/HomeViewModel.swift` | Create/Modify | State management + event pass-throughs + `resetContent()` |
| 11 | `ViewModels/AuthViewModel.swift` | Create | Login/logout/signup state + identity lifecycle |
| 12 | `Views/HomeView.swift` | Modify | Wire NavigationStack, auth menu, sheets, toast |
| 13 | `Views/LoginView.swift` | Create | Login screen with email/password + Create Account link |
| 14 | `Views/SignupView.swift` | Create | Account creation form with gender picker |
| 15 | `Views/ProfileView.swift` | Create | Profile editor with gender + 5 marketing preference toggles |
| 16 | `Views/FeaturedStoryView.swift` | Create/Modify | Hero banner with AsyncImage + tracking |
| 17 | `Views/ArticleDetailView.swift` | Create | Detail page with tracking on appear |
| 18 | `Views/EmailSignupView.swift` | Create | Email capture footer |
| 19 | `Views/SMSAlertBannerView.swift` | Create | SMS opt-in banner |
| 20 | `Views/PhoneSignupSheet.swift` | Create | Phone capture sheet |
| 21 | `Views/ProfileSignupSheet.swift` | Create | Full profile capture sheet |
