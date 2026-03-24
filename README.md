# SF Personalization - HealthEquity Mobile App Demo

A SwiftUI iOS app demonstrating **Salesforce Einstein Personalization SDK** integration for a HealthEquity-themed benefits content experience. The app fetches personalized content decisions from Salesforce Data Cloud and tracks user engagement events back to the platform.

## Architecture

```
SFNewsApp/
├── App/
│   ├── AppDelegate.swift              # SDK initialization & consent
│   └── SFNewsAppApp.swift             # App entry point
├── Config/
│   ├── SDKConfig.swift                # Salesforce credentials & personalization points
│   └── Theme.swift                    # HealthEquity brand colors
├── Models/
│   ├── Article.swift                  # Core article data model
│   └── PersonalizationDecision.swift  # SDK response parser
├── Services/
│   └── PersonalizationService.swift   # SDK wrapper & event tracking
├── ViewModels/
│   └── HomeViewModel.swift            # State management & data flow
├── Views/
│   ├── HomeView.swift                 # Root container with 3 sections
│   ├── FeaturedStoryView.swift        # Hero banner (personalized)
│   ├── ArticleFeedView.swift          # "For You" feed (personalized)
│   ├── ArticleCardView.swift          # Individual article row
│   ├── ArticleDetailView.swift        # Full article detail page
│   └── TrendingView.swift             # Horizontal trending section (static)
└── Mocks/
    └── MockData.swift                 # Fallback content for demo/offline
```

## Features

- **Salesforce Einstein Personalization** — Fetches real-time personalized content decisions for the home screen hero banner and "For You" feed
- **Data Cloud Event Tracking** — Sends page views, impressions, clicks, and article detail views to Salesforce Data Cloud
- **Implicit Consent** — Automatically opts in for CDP consent so events flow immediately
- **Mock Fallback** — Displays HealthEquity-themed content when the SDK is unavailable or still initializing
- **Navigation** — All articles are tappable and navigate to a full detail page
- **HealthEquity Branding** — Green (#00A651) theme throughout with branded content

## Prerequisites

- **Xcode 16+**
- **iOS 17+ deployment target**
- **Salesforce Data Cloud org** with:
  - A Mobile App Connector configured
  - Einstein Personalization enabled
  - Personalization Points created (see Configuration below)

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/matheswarwan/SF_P13N_HQY_MobileApp_Demo.git
   cd SF_P13N_HQY_MobileApp_Demo
   ```

2. **Open in Xcode**
   ```bash
   open SFNewsApp.xcodeproj
   ```

3. **Resolve Swift Packages**
   Xcode will automatically resolve the three SPM dependencies:
   - `SFMCSDK` (v3.0.1) — Core Salesforce Mobile SDK
   - `Cdp` (v3.0.1) — Data Cloud module
   - `Personalization` (v1.0.0) — Einstein Personalization module

   If packages don't resolve automatically: **File > Packages > Resolve Package Versions**

4. **Configure credentials** in `SFNewsApp/Config/SDKConfig.swift`:
   ```swift
   static let dataCloudAppId: String = "<your-app-id>"
   static let dataCloudEndpoint: String = "<your-data-cloud-endpoint>"
   ```
   Find these in: **Data Cloud Setup > Websites & Mobile Apps > Your Mobile App Connector > Integration Guide**

5. **Configure Personalization Points** in Salesforce Einstein Personalization UI to match:
   - `ios.news.home.featured_story` — Single-item decision for the hero banner
   - `ios.news.home.for_you_feed` — Multi-item decision for the article feed

6. **Build and Run**
   Press **Cmd+R** or **Product > Run** to build and launch on a simulator or device.

## Events Tracked

All events are sent to Salesforce Data Cloud via `SFMCSdk.track(event:)`.

| Event | SDK Class | Trigger | Attributes |
|-------|-----------|---------|------------|
| **Home Page View** | `CustomEvent("HomePageView")` | Home screen loads or pull-to-refresh | `screen: "home"` |
| **Article Impression** | `ViewCatalogObjectEvent` | Article becomes visible on screen | `CatalogObject(type: "Article", id, headline, category)` |
| **Article Click** | `ViewCatalogObjectDetailEvent` | User taps an article card | `CatalogObject(type: "Article", id, headline, category)` |
| **Article Detail View** | `CustomEvent("ArticleDetailView")` | Detail page loads | `articleId, headline, category` |

### Automatic Events (via CDP module config)

| Event | Source |
|-------|--------|
| **Screen Views** | Automatic — `trackScreens(true)` in CDP config |
| **App Lifecycle** | Automatic — `trackLifecycle(true)` in CDP config |

## SDK Initialization Flow

1. `AppDelegate.initializeSDK()` builds configs for both CDP and Personalization modules
2. `SFMCSdk.initializeSdk()` initializes both modules
3. On success, `PersonalizationService.shared.markSDKReady()` is called
4. CDP consent is set to `.optIn` for demo purposes
5. `HomeViewModel.loadContent()` calls `PersonalizationModule.fetchDecisions()` with two personalization point names
6. Response is parsed into typed `Article` models and displayed

## Debugging

Filter the Xcode console by `PersonalizationService` or `SFNewsApp` to see:
```
[SFNewsApp] Module 'cdp' init status: success
[SFNewsApp] CDP consent set to optIn
[PersonalizationService] SDK is ready.
[PersonalizationService] Tracked HomePageView event
[PersonalizationService] Tracked impression for article: a1B2c3D4-...
[PersonalizationService] Tracked click for article: b7F8e2A1-...
[PersonalizationService] Tracked ArticleDetailView for article: b7F8e2A1-...
```

Debug logging is enabled in `AppDelegate` via `SFMCSdk.setLogger(logLevel: .debug)` for DEBUG builds.

## Prompts Used

This app was built using Claude Code (Anthropic's AI coding assistant). See [PROMPTS.md](PROMPTS.md) for the full sequence of prompts and instructions used during development.

## License

This is a demo application for Salesforce Einstein Personalization. Not intended for production use.
