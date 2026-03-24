# Prompts Used to Build This App

This document captures the sequence of prompts given to **Claude Code** (Anthropic's AI coding assistant running inside Xcode) to build the SF Personalization HealthEquity Mobile App Demo.

---

## 1. Fix SDK Compilation Error

> Fix `/Users/.../PersonalizationService.swift:45: error: Cannot find 'SFPersonalization' in scope`

**What it did:** Investigated the Salesforce Personalization SDK's actual Swift interface, discovered the correct class name is `PersonalizationModule` (not `SFPersonalization`), and updated the `fetchDecisions` call to use the SDK's native `async throws` API instead of a callback wrapper. Also updated the response parser to use typed SDK classes (`DecisionsResponse`, `DecisionsResponsePersonalization`) instead of `AnyObject` with KVC access.

---

## 2. Fix Build Failures

> Can you check the build failures?

**What it did:** Found that `HomeViewModel` was missing `import Combine` (required for `ObservableObject` conformance and `@Published` properties). Added the import to resolve all compilation errors.

---

## 3. Identify Personalized Components

> In this app, which component shall be personalized by Salesforce personalization?

**What it did:** Traced through the codebase and identified that 2 of 3 home screen sections are personalized via the SDK (Featured Story hero banner and For You feed), while Trending is always static.

---

## 4. Diagnose Missing Events

> Why aren't any salesforce personalization events being sent to salesforce data cloud?

**What it did:** Audited every file and discovered that zero engagement events were being sent — no impression tracking, no click tracking, no page view events. The app only fetched decisions but never reported user interactions back.

---

## 5. Add Event Tracking

> Can you go through the docs and add events for home page, clicks, impression tracking etc - follow the official doc below
> https://developer.salesforce.com/docs/marketing/einstein-personalization/guide/personalize-mobile-experiences-ios.html

**What it did:** Fetched the official Salesforce documentation, inspected the SDK's Swift interface for all available event classes, and implemented:
- `CustomEvent("HomePageView")` — page view on home screen load
- `ViewCatalogObjectEvent` — impression when articles appear on screen
- `ViewCatalogObjectDetailEvent` — click when articles are tapped
- Added tracking calls in `FeaturedStoryView`, `ArticleFeedView`, and `PersonalizationService`

---

## 6. Verify Event Firing

> Do I recompile or rerun to trigger this event? And how in Xcode can I see if these events are fired?

**What it did:** Explained the run vs build distinction, added `print()` statements to all tracking methods for console visibility, and documented how to filter the Xcode console by `PersonalizationService`.

---

## 7. Fix Consent

> Looks like consent is not provided. Can you set implicit optin consent?

**What it did:** Found that `SDKConfig.consentOptIn = true` was defined but never wired up. Added `SFMCSdk.cdp.setConsent(consent: .optIn)` to `AppDelegate` after SDK initialization completes.

---

## 8. Fix Network Error

> [PersonalizationService] fetchDecisions error: network(reason: "Failed. Error: A server with the specified hostname could not be found."...)

**What it did:** Identified a typo in the endpoint URL — `.salesforce.com.salesforce.com` (duplicated domain suffix). Fixed by removing the duplicate.

---

## 9. HealthEquity Theming + Navigation

> Can you update the app so that the apps are clickable and opens different pages.. now, the idea is, let the app be for HealthEquity website - so, reference structure, data on how the app could look like.

**What it did:** This was the largest change — a full transformation:
- Created `Theme.swift` with HealthEquity green (#00A651) brand colors
- Added `body: String` field to `Article` model for detail page content
- Replaced all mock data with HealthEquity topics (HSA, FSA, wellness, COBRA, commuter benefits, investing)
- Created `ArticleDetailView` — full-screen article detail page
- Wired `NavigationLink(value:)` with `navigationDestination(for: Article.self)` across all three sections
- Used `.simultaneousGesture` pattern to fire click tracking alongside NavigationLink navigation
- Re-themed category labels, badges, and accent color to HealthEquity green
- Added `trackArticleDetailView` custom event for the detail page

---

## 10. Replace Mock IDs

> Instead of sending 'mock-featured-001' or 'mock-feed-001', can you send some valid data in them - that looks good when I demo to business?

**What it did:** Replaced all `mock-*` and `trend-*` prefixed IDs with realistic UUID-style identifiers. Staggered `publishedDate` values across articles (1–7 days ago) so the feed looks like real editorial content.

---

## 11. Push to Git

> Can you push this app to git repo? Push as private repo with name as 'SF_P13N_HQY_MobileApp_Demo'

**What it did:** Staged all changes, committed with a descriptive message, installed and authenticated `gh` CLI, created the private repo on GitHub, and pushed.

---

## 12. Documentation

> Can you add a readme to this project and add the prompts used (in a separate file and linked in readme), steps to install and run this and list of events that are tracked etc?

**What it did:** Created this `PROMPTS.md` file and `README.md` with architecture overview, installation steps, event tracking reference table, SDK initialization flow, and debugging instructions.

---

## Tools Used

- **Claude Code** (Anthropic) — AI coding assistant running inside Xcode via Claude Agent SDK
- **Xcode 16** — IDE and build system
- **Salesforce Einstein Personalization SDK** (v1.0.0) — Personalization decisions
- **Salesforce SFMCSDK** (v3.0.1) — Event tracking and CDP integration
- **GitHub CLI (`gh`)** — Repository creation and push
