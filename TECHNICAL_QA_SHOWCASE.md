# SF Einstein Personalization — Technical Q&A for Mobile Dev Team

> Reference document for the team showcase. Covers SDK libraries, functions, data flow, schema, architecture, and common pitfalls.

---

## 1. SDK Libraries & Dependencies

**Q: What SDK packages are needed?**

| Package | Repo | Version | Purpose |
|---|---|---|---|
| **SFMCSDK** | `https://github.com/nickmcphee-sf/mobile-sdk-cdp-ios` | 3.0.1+ | Core SDK — event tracking, identity, consent |
| **Cdp** | (included in SFMCSDK repo) | 3.0.1+ | CDP module — `CdpModule.shared` for anonymous profile reset |
| **Personalization** | `https://github.com/nickmcphee-sf/Personalization-IOS` | 1.0.0+ | Fetching personalized content decisions |

All added via **File > Add Package Dependencies** in Xcode (SPM).

**Q: What imports are needed in each file?**

| Import | When you need it |
|---|---|
| `import SFMCSDK` | Any file calling `SFMCSdk.track()`, `SFMCSdk.identity.edit`, `SFMCSdk.cdp.setConsent` |
| `import Personalization` | Files using `PersonalizationModule.fetchDecisions()`, `CustomEvent`, `CatalogObject`, `IdentityEvent`, `ViewCatalogObjectEvent`, `ViewCatalogObjectDetailEvent` |
| `import Cdp` | Only where you call `CdpModule.shared.setProfileToAnonymous()` (logout) |

**Q: Why is `Cdp` a separate import from `SFMCSDK`?**

`SFMCSdk.cdp` returns a `CDP` protocol wrapper that does NOT expose `setProfileToAnonymous()`. The actual implementation lives on `CdpModule.shared` which requires `import Cdp`. This is a known SDK design quirk.

**Q: Are these the official Salesforce repos?**

These are internal/preview repos (`nickmcphee-sf`). The official public SDK is at `https://github.com/salesforce-marketingcloud/MarketingCloudSDK-iOS` — but the Personalization module is distributed separately through the repos above.

---

## 2. SDK Initialization

**Q: Where does SDK init happen?**

`AppDelegate.swift` — in `application(_:didFinishLaunchingWithOptions:)`, before any SwiftUI view renders.

**Q: What's the init order?**

1. Build `PersonalizationConfigBuilder().build()`
2. Build `CdpConfigBuilder(appId:endpoint:).trackScreens(true).trackLifecycle(true).sessionTimeout(600).build()`
3. Call `SFMCSdk.initializeSdk()` with both configs
4. In the completion callback: check module status, call `markSDKReady()`, set consent

**Q: Where do the credentials come from?**

`SDKConfig.swift` holds `dataCloudAppId` and `dataCloudEndpoint`. These come from **Data Cloud Setup > Websites & Mobile Apps > Your Mobile App Connector > Integration Guide** in Salesforce.

**Q: What does `trackScreens(true)` and `trackLifecycle(true)` do?**

The CDP module automatically tracks screen transitions and app lifecycle events (foreground, background, terminate) without any extra code. These are sent as engagement events to Data Cloud.

**Q: What's the session timeout?**

600 seconds (10 minutes). If the user is inactive for 10 minutes, the SDK starts a new session.

---

## 3. Architecture & Code Organization

**Q: What's the overall architecture?**

```
Views (SwiftUI)
    ↓ call
ViewModels (ObservableObject)
    ↓ call
Services (PersonalizationService, AuthService)
    ↓ call
SDK (SFMCSdk.track, PersonalizationModule.fetchDecisions, SFMCSdk.identity.edit)
    ↓ HTTP
Salesforce Data Cloud / Einstein Personalization
```

**Q: Which service has what code?**

| File | Responsibility |
|---|---|
| `Services/PersonalizationService.swift` | ALL Salesforce SDK interactions — fetch decisions, track events, identity, consent |
| `Services/AuthService.swift` | Local account CRUD — JSON file storage, login, signup, update |
| `ViewModels/AuthViewModel.swift` | Login/logout state, bridges auth actions to PersonalizationService |
| `ViewModels/HomeViewModel.swift` | Home screen state, content loading, event tracking pass-throughs |

**Q: Why is everything routed through `PersonalizationService`?**

Single point of contact with the SDK. All `SFMCSdk.track()`, `SFMCSdk.identity.edit`, and `PersonalizationModule.fetchDecisions()` calls go through this one `@MainActor` singleton. This makes it easy to add logging, guard on SDK readiness, and swap implementations for testing.

**Q: Why `@MainActor` on `PersonalizationService`?**

So ViewModels (which are also `@MainActor`) can call its methods directly without `await` or thread-hopping. The SDK calls themselves are thread-safe internally.

**Q: What's the full file list in the project?**

| # | File | Purpose |
|---|---|---|
| 1 | `Config/SDKConfig.swift` | Salesforce credentials & personalization point names |
| 2 | `Config/Theme.swift` | Brand colors (hex-based) |
| 3 | `App/AppDelegate.swift` | SDK initialization + consent |
| 4 | `App/SFNewsAppApp.swift` | App entry point — conditional auth gate |
| 5 | `Models/Article.swift` | Content data model |
| 6 | `Models/PersonalizationDecision.swift` | SDK response parser |
| 7 | `Models/UserAccount.swift` | Local user account model with preferences |
| 8 | `Services/PersonalizationService.swift` | SDK wrapper (fetch + events + identity + consent) |
| 9 | `Services/AuthService.swift` | Local JSON-based account storage |
| 10 | `ViewModels/HomeViewModel.swift` | Home screen state + event pass-throughs |
| 11 | `ViewModels/AuthViewModel.swift` | Login/logout/signup state + identity lifecycle |
| 12 | `Views/HomeView.swift` | Main screen — NavigationStack, toolbar menu, sheets |
| 13 | `Views/LoginView.swift` | Login screen |
| 14 | `Views/SignupView.swift` | Account creation with gender picker |
| 15 | `Views/ProfileView.swift` | Profile editor with gender + 5 marketing preference toggles |
| 16 | `Views/FeaturedStoryView.swift` | Hero banner with AsyncImage + impression tracking |
| 17 | `Views/ArticleDetailView.swift` | Detail page with tracking on appear |
| 18 | `Views/ArticleCardView.swift` | Article card component |
| 19 | `Views/ArticleFeedView.swift` | Article feed list |
| 20 | `Views/TrendingView.swift` | Trending articles section |
| 21 | `Views/EmailSignupView.swift` | Email capture footer |
| 22 | `Views/SMSAlertBannerView.swift` | SMS opt-in banner |
| 23 | `Views/PhoneSignupSheet.swift` | Phone capture modal |
| 24 | `Views/ProfileSignupSheet.swift` | Full profile capture modal |
| 25 | `Mocks/MockData.swift` | Fallback/default content |

---

## 4. Event Types & What Data Is Sent

**Q: What event types does the app send?**

| Event | SDK Class | When Fired | Data Cloud Stream |
|---|---|---|---|
| Page view | `CustomEvent(name: "HomePageView")` | Home screen loads | `customInteractionLog` |
| Impression | `ViewCatalogObjectEvent` | Article card appears on screen | `catalogObjectViewLog` |
| Click / detail view | `ViewCatalogObjectDetailEvent` | User taps article | `catalogObjectDetailViewLog` |
| Article detail | `CustomEvent(name: "ArticleDetailView")` | Detail page appears | `customInteractionLog` |
| Identity (login/signup) | `IdentityEvent` | User logs in or creates account | `identityLog` |
| Identity (email capture) | `IdentityEvent` | Email signup footer | `identityLog` |
| Identity (phone capture) | `IdentityEvent` | Phone signup sheet | `identityLog` |
| Identity (full profile) | `IdentityEvent` | Profile signup sheet | `identityLog` |
| Consent preferences | `CustomEvent(name: "consentLog")` | Profile save (5 events, one per preference) | `consentLog` |
| Screen auto-track | (automatic) | Any screen transition | Built-in CDP stream |
| Lifecycle auto-track | (automatic) | App foreground/background | Built-in CDP stream |

**Q: What attributes are sent with each event?**

**CustomEvent (page view):**
```json
{ "screen": "home" }
```

**ViewCatalogObjectEvent / ViewCatalogObjectDetailEvent (impression/click):**
```json
{ "type": "Article", "id": "<article-id>", "headline": "...", "category": "..." }
```

**IdentityEvent (login/signup):**
```json
{
  "contactPointEmail": "user@example.com",
  "phoneNumber": "555-1234",
  "firstName": "John",
  "lastName": "Smith",
  "postalCode": "84095",
  "Gender": "Male",
  "source": "local_auth_login"
}
```

**CustomEvent — consentLog (one per preference):**
```json
{ "purpose": "Marketing Email", "status": "Opt In", "provider": "HealthEquity Mobile App" }
```

**Q: What's the difference between `SFMCSdk.identity.edit` and `IdentityEvent`?**

- `identity.edit` — Updates the **local profile** on the device (sets `profileId`, adds attributes). This is the identity the SDK associates with all subsequent events.
- `IdentityEvent` — Sends an **event** to Data Cloud's identity stream so the server side can resolve/merge profiles.

You typically do both together: edit locally, then track the event.

**Q: What's the `source` field for?**

It's a custom attribute we add to identity events to indicate where the identity was captured from (e.g., `"local_auth_login"`, `"email_signup"`, `"sms_signup"`, `"profile_signup"`). Useful for analytics in Data Cloud to see which capture points are most effective.

---

## 5. Schema & Key Mapping

**Q: What schema keys must match exactly?**

| App Concept | Correct SDK Key | Common Mistake (will NOT map) |
|---|---|---|
| Phone number | `phoneNumber` | `phone`, `contactPointPhone` |
| Postal / Zip code | `postalCode` | `zipCode` |
| Gender | `Gender` (capital G) | `gender` |
| Email | `email` or `contactPointEmail` | Both work |
| First name | `firstName` | ✓ |
| Last name | `lastName` | ✓ |

**Q: Where is the consent schema documented?**

[Salesforce Consent Schema Docs](https://developer.salesforce.com/docs/data/data-cloud-engagement-mobile-sdk/guide/c360a-api-engagement-mobile-sdk-consent-schema.html)

Consent uses: `purpose` (what), `status` ("Opt In" / "Opt Out"), `provider` (app name).

**Q: Is Gender in the default schema?**

No. `Gender` is a **custom field** that must be manually added to the identity data stream schema in Data Cloud. This is documented in `SCHEMA_GAPS.md`.

**Q: Why are preferences sent as consentLog events instead of identity attributes?**

Salesforce Data Cloud has a dedicated `consentLog` stream with purpose/status/provider fields. Sending preferences as identity attributes (e.g., `marketingEmailOptIn: true`) would not map to anything in the consent data model. Each preference toggle generates a separate consentLog event.

**Q: What are the 5 consent purposes we track?**

| Purpose | Toggle in ProfileView |
|---|---|
| `"Marketing Email"` | Marketing Emails |
| `"Push Notifications"` | Push Notifications |
| `"SMS Marketing"` | SMS Marketing |
| `"Weekly Digest"` | Weekly Digest |
| `"Benefit Alerts"` | Benefit Alerts |

---

## 6. Personalization Decisions (Content Fetching)

**Q: How does personalized content get fetched?**

```swift
let response = try await PersonalizationModule.fetchDecisions(
    personalizationPointNames: ["Home_Hero_Test", "ios.news.home.for_you_feed"],
    context: nil,
    timeoutSeconds: 5.0
)
```

**Q: What's a "personalization point"?**

A named slot configured in the Salesforce Einstein Personalization UI. Each point returns content from an active experiment. The API name must match exactly (e.g., `"Home_Hero_Test"`).

**Q: What does the response look like?**

`DecisionsResponse` has a `personalizationsByName: [String: DecisionsResponsePersonalization]` dictionary. Each personalization has:
- `personalizationId` — the experiment ID
- `attributes: [String: Any]` — content key-value pairs (headline, imageURL, summary, etc.)
- `data: [[String: Any]]` — array for multi-item responses

**Q: What content attributes does the parser expect?**

| Parser Key | Alternate Accepted | Type | Required? |
|---|---|---|---|
| `headline` | `title` | String | No (falls back to "Featured") |
| `summary` | `description` | String | No |
| `body` | — | String | No |
| `category` | — | String | No (defaults to "Featured") |
| `imageUrl` | `imageURL` | String (URL) | No |
| `readTimeMinutes` | — | Int | No (defaults to 3) |

**Q: What if the SDK isn't ready or the fetch fails?**

Falls back to mock/default content from `MockData.swift`. The app always shows something immediately, then replaces it if personalized content arrives.

**Q: What's the timeout?**

5 seconds (configurable in `SDKConfig.fetchTimeoutSeconds`). If no response in 5s, mock content stays.

**Q: What Salesforce-side configuration is needed for decisions to work?**

1. **Data Cloud Setup > Websites & Mobile Apps** — Create a Mobile App Connector
2. **Einstein Personalization > Personalization Points** — Create points with API names matching `SDKConfig`
3. **Einstein Personalization > Experiments** — Create experiment, connect to point, configure content attributes
4. **Activate the experiment** — Set it to Running

---

## 7. Identity & User Lifecycle

**Q: What happens on login?**

1. `AuthService.login()` — validates credentials against local JSON
2. `AuthViewModel.setCurrentUser()` — sets state, persists email to UserDefaults
3. `PersonalizationService.setUserIdentity()` — calls `identity.edit` + tracks `IdentityEvent`
4. Home screen reloads via `.task(id: authViewModel.currentUser?.id)`

**Q: What happens on signup?**

Same as login, except `AuthService.signup()` creates the account first (with optional firstName, lastName, gender).

**Q: What happens on logout?**

1. `PersonalizationService.clearIdentity()` — calls `CdpModule.shared.setProfileToAnonymous()`
2. Auth state cleared, UserDefaults cleared
3. App shows LoginView

**Q: What happens on profile update (save)?**

1. `AuthService.updateAccount()` — persists updated fields to JSON
2. `PersonalizationService.setUserIdentity()` — re-sends full identity with all current fields
3. `PersonalizationService.trackPreferenceUpdate()` — sends 5 consentLog events (one per preference)
4. Modal auto-dismisses

**Q: How is the session restored on app relaunch?**

`AuthViewModel.init()` calls `restoreSession()` which checks UserDefaults for a saved email, looks it up in AuthService, and auto-logs in without re-sending identity (SDK handles session continuity).

**Q: Where are user accounts stored?**

JSON file at `Documents/user_accounts.json`. Plain-text passwords — this is a demo app, not production.

**Q: Can multiple users share the same device?**

Yes. Each user creates a separate account. On login, the SDK identity switches to that user's profile. On logout, the SDK reverts to anonymous via `setProfileToAnonymous()`.

---

## 8. Consent

**Q: How is consent handled?**

Two levels:

1. **SDK-level consent** — `SFMCSdk.cdp.setConsent(consent: .optIn)` in AppDelegate. Without this, NO events leave the device. Currently hard-coded to opt-in for demo purposes.

2. **User preference consent** — Marketing toggles in ProfileView, sent as `consentLog` events to Data Cloud's consent stream.

**Q: What if SDK consent isn't set?**

Events are silently queued but never sent. `fetchDecisions` (Personalization module) still works — only CDP event tracking is blocked. This is the **#1 cause** of "decisions work but events don't flow."

**Q: How would production consent differ from this demo?**

In production you would:
- Show a consent prompt on first launch
- Persist the user's choice
- Only call `SFMCSdk.cdp.setConsent(consent: .optIn)` if they agree
- Call `.optOut` if they decline
- Provide a settings toggle to change later

---

## 9. Data Flow: End-to-End Diagram

```
┌─────────────┐     ┌──────────────────┐     ┌───────────────────────┐
│  SwiftUI    │     │  PersonalizationService │     │  Salesforce           │
│  Views      │     │  (singleton)      │     │                       │
├─────────────┤     ├──────────────────┤     ├───────────────────────┤
│ User taps   │────>│ SFMCSdk.track()  │────>│ Data Cloud            │
│ article     │     │ (CustomEvent /   │     │ Engagement Streams    │
│             │     │  CatalogEvent)   │     │                       │
├─────────────┤     ├──────────────────┤     ├───────────────────────┤
│ User logs   │────>│ identity.edit +  │────>│ Data Cloud            │
│ in          │     │ IdentityEvent    │     │ Identity Resolution   │
├─────────────┤     ├──────────────────┤     ├───────────────────────┤
│ User saves  │────>│ CustomEvent      │────>│ Data Cloud            │
│ preferences │     │ (consentLog x5)  │     │ Consent Stream        │
├─────────────┤     ├──────────────────┤     ├───────────────────────┤
│ Home screen │────>│ fetchDecisions() │<────│ Einstein              │
│ loads       │<────│ (async/await)    │     │ Personalization       │
└─────────────┘     └──────────────────┘     └───────────────────────┘
```

**Endpoint**: All events are sent to the Data Cloud endpoint configured in `SDKConfig.dataCloudEndpoint` (e.g., `https://g-xxxxx.c360a.salesforce.com`). The CDP module batches and sends them via HTTP POST internally.

---

## 10. Common Pitfalls & Known Issues

| Issue | Cause | Fix |
|---|---|---|
| `CustomEvent` init returns nil | Name is empty or attributes invalid | Always `if let` unwrap |
| `SFMCSdk.cdp.setProfileToAnonymous()` doesn't compile | `CDP` protocol doesn't expose it | Use `CdpModule.shared.setProfileToAnonymous()` with `import Cdp` |
| Events not flowing but decisions work | Consent not set, or CDP module failed init | Check for `[DC Events sent]` in console |
| Identity data not mapping in Data Cloud | Wrong attribute key names | Use `phoneNumber`, `postalCode`, not `phone`, `zipCode` |
| `Button` in `Form` doesn't respond to taps | SwiftUI Form bug with `listRowBackground` | Use `.toolbar` buttons instead |
| Duplicate `.salesforce.com` in endpoint URL | Copy-paste error | Check endpoint doesn't end in `.salesforce.com.salesforce.com` |
| `PersonalizationModule` not found | Wrong class name | Not `SFPersonalization` — use `PersonalizationModule` |
| `ObservableObject` conformance error | Missing import | Add `import Combine` to ViewModel files |
| `.onTapGesture` blocks `NavigationLink` | SwiftUI gesture conflict | Use `.simultaneousGesture(TapGesture().onEnded { })` |
| Preferences not appearing in Data Cloud | Sent as custom identity attributes | Use `consentLog` events with `purpose`/`status`/`provider` keys |
| Personalized content not showing | Attribute key mismatch in experiment | Log `personalization.attributes` and check key names (e.g., `imageURL` vs `imageUrl`) |
| SDK not ready on first render | Async init hasn't completed | Always show mock/fallback content first, replace when SDK responds |

---

## 11. Debugging & Verification

**Q: How do I verify events are actually being sent?**

Filter Xcode console by:
- `[DC Events sent]` — confirms events left the device (SDK internal log)
- `[PersonalizationService]` — app-level tracking log showing what was tracked
- `[DC Error]` — any SDK-level errors

**Q: What console output should I see on a successful flow?**

```
[SFNewsApp] Module 'cdp' init status: success
[SFNewsApp] CDP consent set to optIn
[PersonalizationService] SDK is ready.
[PersonalizationService] --- SET USER IDENTITY ---
[PersonalizationService]   profileId  = user@example.com
[PersonalizationService] --- END SET USER IDENTITY ---
[PersonalizationService] --- FETCH DECISIONS ---
[PersonalizationService]   Points returned: ["Home_Hero_Test"]
[PersonalizationService] --- END FETCH DECISIONS ---
[PersonalizationService] Tracked HomePageView event
[PersonalizationService] Tracked impression for article: abc123
[PersonalizationService] --- CONSENT PREFERENCE EVENTS ---
[PersonalizationService]   ✓ consentLog: purpose="Marketing Email" status="Opt In"
[PersonalizationService]   ✓ consentLog: purpose="Push Notifications" status="Opt Out"
[PersonalizationService] --- END CONSENT PREFERENCE EVENTS ---
```

**Q: How do I verify data arrived in Data Cloud?**

In Salesforce: **Data Cloud > Data Explorer** — query the engagement data streams (e.g., `MobileApp_Engagement_*`) and look for your app's events by timestamp or profile ID.

---

## 12. Repo Documentation Files

| File | Purpose |
|---|---|
| `PROMPT_TEMPLATE_SF_P13N_IOS.md` | Complete implementation template (Parts 1–13) for replicating this in another iOS app |
| `EVENT_TRACKING_GUIDE.md` | How behavioral events flow to Data Cloud, troubleshooting checklist |
| `SCHEMA_GAPS.md` | Schema fields that need manual addition in Data Cloud (currently just Gender) |
| `TECHNICAL_QA_SHOWCASE.md` | This document — Q&A reference for the team showcase |

---

## 13. Quick Reference: SDK Functions Used

| Function | Where Called | Purpose |
|---|---|---|
| `SFMCSdk.initializeSdk(_:completion:)` | AppDelegate | Initialize SDK with CDP + Personalization configs |
| `SFMCSdk.cdp.setConsent(consent:)` | AppDelegate | Enable event sending (opt-in) |
| `SFMCSdk.setLogger(logLevel:logOutputter:)` | AppDelegate | Enable debug logging |
| `SFMCSdk.track(event:)` | PersonalizationService | Send any event to Data Cloud |
| `SFMCSdk.identity.edit(_:)` | PersonalizationService | Update local identity profile |
| `PersonalizationModule.fetchDecisions(personalizationPointNames:context:timeoutSeconds:)` | PersonalizationService | Fetch personalized content |
| `CdpModule.shared.setProfileToAnonymous()` | PersonalizationService | Reset to anonymous on logout |
| `CustomEvent(name:attributes:)` | PersonalizationService | Create custom/consent events (returns Optional) |
| `IdentityEvent(attributes:)` | PersonalizationService | Create identity events |
| `ViewCatalogObjectEvent(catalogObject:)` | PersonalizationService | Create impression events |
| `ViewCatalogObjectDetailEvent(catalogObject:)` | PersonalizationService | Create detail view events |
| `CatalogObject(type:id:attributes:)` | PersonalizationService | Describe a catalog item for tracking |
