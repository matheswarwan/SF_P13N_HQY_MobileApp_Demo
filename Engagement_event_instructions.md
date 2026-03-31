# Behavioral Event Tracking — SF Einstein Personalization / Data Cloud

## How Events Flow from App to Data Cloud

```
Your App Code                    SDK Layer                    Salesforce
─────────────                    ─────────                    ──────────
SFMCSdk.track(event:)  ──►  CDP module batches   ──►  Data Cloud Engagement
                             & sends via HTTP          Data Stream (ingestion)
                                   │
                                   ├── Requires: SDK initialized ✓
                                   ├── Requires: Consent = optIn ✓
                                   └── Requires: Valid endpoint + appId ✓
```

---

## Event Types and SDK Classes

There are **5 categories** of events, each using a different SDK class:

| Category | SDK Class | Data Cloud Stream | When to use |
|---|---|---|---|
| **Custom events** (page views, button clicks, engagement) | `CustomEvent(name:attributes:)` | `customInteractionLog` | Page views, button taps, custom engagement |
| **Catalog impressions** | `ViewCatalogObjectEvent(catalogObject:)` | `catalogObjectViewLog` | Item becomes visible on screen |
| **Catalog detail views** | `ViewCatalogObjectDetailEvent(catalogObject:)` | `catalogObjectDetailViewLog` | User taps into item detail |
| **Identity events** | `IdentityEvent(attributes:)` | `identityLog` | User provides PII (email, phone, profile) |
| **Consent events** | `CustomEvent(name: "consentLog", ...)` | `consentLog` | Marketing preference changes |

---

## Code Patterns for Each Event Type

### 1. Custom Event (page view, button click, engagement)

```swift
// CustomEvent init returns Optional — must unwrap with if-let
if let event = CustomEvent(
    name: "HomePageView",           // event name — appears in DC stream
    attributes: ["screen": "home"]  // arbitrary key-value pairs
) {
    SFMCSdk.track(event: event)
}
```

### 2. Catalog Object Impression

```swift
let obj = CatalogObject(
    type: "Article",               // catalog type
    id: article.id,                // unique item ID
    attributes: [
        "headline": article.headline,
        "category": article.category
    ]
)
SFMCSdk.track(event: ViewCatalogObjectEvent(catalogObject: obj))
```

### 3. Catalog Object Detail View (click-through)

```swift
let obj = CatalogObject(type: "Article", id: article.id, attributes: [
    "headline": article.headline,
    "category": article.category
])
SFMCSdk.track(event: ViewCatalogObjectDetailEvent(catalogObject: obj))
```

### 4. Identity Event

```swift
// Step 1: Update the identity profile
SFMCSdk.identity.edit { modifier in
    modifier.profileId = email
    modifier.addAttribute(key: "email", value: email)
    modifier.addAttribute(key: "firstName", value: firstName)
    modifier.addAttribute(key: "lastName", value: lastName)
    modifier.addAttribute(key: "phoneNumber", value: phone)    // NOT "phone"
    modifier.addAttribute(key: "postalCode", value: zipCode)   // NOT "zipCode"
    return modifier
}

// Step 2: Track the identity event
SFMCSdk.track(event: IdentityEvent(attributes: [
    "contactPointEmail": email,
    "phoneNumber": phone,
    "source": "signup"
]))
```

### 5. Consent Event (marketing preferences)

```swift
// Each preference is a separate consentLog event
// Uses Salesforce's consent schema: purpose / status / provider
let status = optedIn ? "Opt In" : "Opt Out"
if let event = CustomEvent(name: "consentLog", attributes: [
    "purpose": "Marketing Email",
    "status": status,
    "provider": "YourApp Name"
]) {
    SFMCSdk.track(event: event)
}
```

> **Reference**: [Salesforce Consent Schema Docs](https://developer.salesforce.com/docs/data/data-cloud-engagement-mobile-sdk/guide/c360a-api-engagement-mobile-sdk-consent-schema.html)

---

## Why Personalization Decisions Work but Events Don't Flow

This is a **very common** scenario. `fetchDecisions` uses the **Personalization module**, while behavioral events use the **CDP module**. They are separate modules with separate requirements:

| Requirement | fetchDecisions (Personalization) | SFMCSdk.track (CDP/Events) |
|---|---|---|
| SDK initialized | Yes | Yes |
| Valid appId + endpoint | No (uses its own config) | **Yes — CDP config** |
| Consent set to optIn | No | **Yes — #1 cause of missing events** |
| CDP module init success | No | **Yes** |
| Network reachable to DC endpoint | No | **Yes** |

---

## Troubleshooting Checklist

### 1. Consent is not set (most common cause)

Events are silently queued but **never sent** without explicit consent:

```swift
// Must be called AFTER SDK init completes successfully
SFMCSdk.cdp.setConsent(consent: .optIn)
```

If you never see `[DC Events sent]` in the console, consent is likely not set.

### 2. CDP module failed to initialize

In your SDK init callback, check that the CDP module succeeded:

```swift
SFMCSdk.initializeSdk(config) { moduleStatuses in
    for status in moduleStatuses {
        print("Module '\(status.moduleName)' status: \(status.initStatus)")
        // ✓ Look for: Module 'cdp' status: success
        // ✗ If it says 'failed', events will never send
    }
}
```

### 3. Endpoint URL is wrong

The `CdpConfigBuilder` endpoint must be a valid `https://` URL ending in `.salesforce.com`. Common mistakes:

- **Duplicated suffix**: `https://xxx.salesforce.com.salesforce.com` — breaks networking
- **HTTP instead of HTTPS** — silently fails
- **Trailing slash issues**

### 4. AppId doesn't match the Data Cloud Mobile App Connector

The `appId` in `CdpConfigBuilder` must **exactly** match what's configured in:

**Data Cloud Setup → Websites & Mobile Apps → Your Mobile App Connector**

### 5. Events are tracked before SDK is ready

If you call `SFMCSdk.track(event:)` before the SDK finishes initializing, events may be silently dropped. Always guard with a readiness check:

```swift
guard isSDKReady else { return }
```

### 6. CustomEvent init silently returns nil

`CustomEvent(name:attributes:)` returns `Optional`. If the name is empty or attributes are invalid, it returns `nil` and nothing is tracked:

```swift
// BAD — force-unwrap crashes, or event is silently nil
let event = CustomEvent(name: "", attributes: [:])!
SFMCSdk.track(event: event)

// GOOD — safely unwraps
if let event = CustomEvent(name: "PageView", attributes: ["screen": "home"]) {
    SFMCSdk.track(event: event)
}
```

---

## What to Look For in Xcode Console

### Filter by `[DC` to see Data Cloud SDK internal logs:

```
[DC Events sent]: 3 events              ← ✓ Events successfully sent to DC
[DC Events queued]: 1 event             ← Events waiting to be sent (batched)
[DC Consent]: optIn                     ← ✓ Consent was properly set
[DC Error]: hostname not found          ← ✗ Endpoint URL is wrong
```

If you see `[DC Events sent]` with a count > 0, events **are** leaving the device.

If you **don't** see this at all, the issue is one of the 6 items above (most likely consent or CDP init failure).

### Filter by `PersonalizationService` to see app-level tracking:

```
[PersonalizationService] Tracked HomePageView event
[PersonalizationService] Tracked impression for article: abc123
[PersonalizationService] Tracked click for article: abc123
[PersonalizationService] --- SET USER IDENTITY ---
[PersonalizationService]   ✓ IdentityEvent tracked
[PersonalizationService] --- CONSENT PREFERENCE EVENTS ---
[PersonalizationService]   ✓ consentLog: purpose="Marketing Email" status="Opt In"
```

---

## Schema Key Mapping (Common Mistakes)

These attribute key names must **exactly** match the Data Cloud engagement data stream schema:

| App concept | Correct SDK key | Wrong (will NOT map) |
|---|---|---|
| Phone number | `phoneNumber` | `phone`, `contactPointPhone` |
| Postal / Zip code | `postalCode` | `zipCode` |
| Gender | `Gender` (capital G — custom field) | `gender` |
| Email | `email` / `contactPointEmail` | ✓ (both work) |

---

## Required SDK Initialization Order

For events to flow, your `AppDelegate` must do these **in order**:

```swift
// 1. Build CDP config with correct appId + endpoint
let cdpConfig = CdpConfigBuilder(
    appId: SDKConfig.dataCloudAppId,
    endpoint: SDKConfig.dataCloudEndpoint
)
.trackScreens(true)
.trackLifecycle(true)
.sessionTimeout(600)
.build()

// 2. Build Personalization config
let personalizationConfig = PersonalizationConfigBuilder().build()

// 3. Initialize with BOTH modules
SFMCSdk.initializeSdk(
    ConfigBuilder()
        .setCdp(config: cdpConfig)
        .setPersonalization(config: personalizationConfig)
        .build()
) { moduleStatuses in
    // 4. Check CDP module initialized successfully
    for status in moduleStatuses {
        print("Module '\(status.moduleName)' status: \(status.initStatus)")
    }
    // 5. Set consent AFTER init completes
    SFMCSdk.cdp.setConsent(consent: .optIn)
}
```

> **Key point**: If your other app only initializes the Personalization module (or doesn't call `setConsent`), `fetchDecisions` will work but `SFMCSdk.track()` calls go nowhere.

---

## Import Requirements

```swift
import SFMCSDK          // SFMCSdk.track, SFMCSdk.identity, SFMCSdk.cdp
import Personalization   // PersonalizationModule.fetchDecisions, CustomEvent, etc.
import Cdp               // CdpModule.shared.setProfileToAnonymous()
```

> `import Cdp` is specifically needed for `CdpModule.shared.setProfileToAnonymous()`. Without it, you'll get a compile error — `SFMCSdk.cdp` does NOT expose this method.


# Sample Events from another mobile app 

```
json
[DC Events sent]: {
  "events" : [
    {
      "category" : "engagement",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "provider" : "HealthEquity Mobile App",
      "eventType" : "consentLog",
      "purpose" : "Marketing Email",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "status" : "Opt Out",
      "eventId" : "FF3AF8A5-F98C-49D1-A42A-EECC11CABA1F",
      "dateTime" : "2026-03-27T21:21:10.222Z"
    },
    {
      "category" : "profile",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "IDName" : "MC Subscriber Key",
      "eventType" : "partyIdentification",
      "IDType" : "Person Identifier",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "userId" : "a@b.c",
      "eventId" : "9B1F4459-8135-4C26-B6C3-7E9DA83E9B07",
      "dateTime" : "2026-03-27T21:21:10.226Z"
    },
    {
      "category" : "engagement",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "provider" : "HealthEquity Mobile App",
      "eventType" : "consentLog",
      "purpose" : "Push Notifications",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "status" : "Opt In",
      "eventId" : "B83CBE32-CADE-4D66-9E04-CC9D3A16C4BE",
      "dateTime" : "2026-03-27T21:21:10.228Z"
    },
    {
      "category" : "profile",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "IDName" : "MC Subscriber Key",
      "eventType" : "partyIdentification",
      "IDType" : "Person Identifier",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "userId" : "a@b.c",
      "eventId" : "FE2216AB-8851-4420-984C-2187829D4494",
      "dateTime" : "2026-03-27T21:21:10.229Z"
    },
    {
      "category" : "engagement",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "provider" : "HealthEquity Mobile App",
      "eventType" : "consentLog",
      "purpose" : "SMS Marketing",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "status" : "Opt In",
      "eventId" : "283ADB26-D0A2-40E7-A8DC-1BCB416FEB2D",
      "dateTime" : "2026-03-27T21:21:10.230Z"
    },
    {
      "category" : "engagement",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "provider" : "HealthEquity Mobile App",
      "eventType" : "consentLog",
      "purpose" : "Weekly Digest",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "status" : "Opt In",
      "eventId" : "8982494A-FD1E-4EA4-B879-0B9C8DB1DE99",
      "dateTime" : "2026-03-27T21:21:10.231Z"
    },
    {
      "category" : "engagement",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "provider" : "HealthEquity Mobile App",
      "eventType" : "consentLog",
      "purpose" : "Benefit Alerts",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "status" : "Opt In",
      "eventId" : "FF4D6F77-BDD5-4FF0-B421-0AD9089E92CB",
      "dateTime" : "2026-03-27T21:21:10.233Z"
    },
    {
      "id" : "d4E5f6G7-8h9I-0j1K-2l3M-4n5O6p7Q8r9S",
      "category" : "engagement",
      "attributeHeadline" : "Investing Your HSA: A Beginner's Guide",
      "eventType" : "catalog",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "type" : "Article",
      "eventId" : "88672551-13DE-4151-AB6D-5842A00EADDB",
      "interactionName" : "View Catalog Object Detail",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "dateTime" : "2026-03-27T21:26:10.247Z",
      "attributeCategory" : "Investing"
    },
    {
      "category" : "engagement",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "eventType" : "ArticleDetailView",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "articleId" : "d4E5f6G7-8h9I-0j1K-2l3M-4n5O6p7Q8r9S",
      "eventId" : "73861351-AC40-4602-A776-112D10789DE0",
      "dateTime" : "2026-03-27T21:26:10.394Z",
      "headline" : "Investing Your HSA: A Beginner's Guide"
    },
    {
      "id" : "e1F2g3H4-5i6J-7k8L-9m0N-1o2P3q4R5s6T",
      "category" : "engagement",
      "attributeHeadline" : "Wellness Programs That Actually Work",
      "eventType" : "catalog",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "type" : "Article",
      "eventId" : "7F8AC6B3-E975-4075-B76A-25D346D1728B",
      "interactionName" : "View Catalog Object",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "dateTime" : "2026-03-27T21:26:11.575Z",
      "attributeCategory" : "Wellness"
    },
    {
      "id" : "c9D0e1F2-3a4B-5c6D-7e8F-9a0B1c2D3e4F",
      "category" : "engagement",
      "attributeHeadline" : "Open Enrollment Checklist: 5 Steps to Get It Right",
      "eventType" : "catalog",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "type" : "Article",
      "eventId" : "13416C4D-9BB1-4BED-8428-A8F241F88F8F",
      "interactionName" : "View Catalog Object",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "dateTime" : "2026-03-27T21:26:11.578Z",
      "attributeCategory" : "Benefits"
    },
    {
      "id" : "d4E5f6G7-8h9I-0j1K-2l3M-4n5O6p7Q8r9S",
      "category" : "engagement",
      "attributeHeadline" : "Investing Your HSA: A Beginner's Guide",
      "eventType" : "catalog",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "type" : "Article",
      "eventId" : "61AEDB34-23CA-470E-B889-DD46B95556C4",
      "interactionName" : "View Catalog Object",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "dateTime" : "2026-03-27T21:26:11.580Z",
      "attributeCategory" : "Investing"
    },
    {
      "id" : "b7F8e2A1-4c3D-9a0E-bC12-dE56fG78hI90",
      "category" : "engagement",
      "attributeHeadline" : "FSA Eligible Expenses You Didn't Know About",
      "eventType" : "catalog",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "type" : "Article",
      "eventId" : "A48D1215-CDAE-4438-A090-0AB65EE3A7DE",
      "interactionName" : "View Catalog Object",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "dateTime" : "2026-03-27T21:26:11.581Z",
      "attributeCategory" : "FSA"
    },
    {
      "id" : "ef62f9f7-0f0e-48df-afdc-5c8cc250ba40",
      "category" : "engagement",
      "attributeHeadline" : "Featured",
      "eventType" : "catalog",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "type" : "Article",
      "eventId" : "56EE0F62-781A-4DA0-857D-199A67BD8BDA",
      "interactionName" : "View Catalog Object",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "dateTime" : "2026-03-27T21:26:11.582Z",
      "attributeCategory" : "Featured"
    },
    {
      "category" : "engagement",
      "channel" : "mobile",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "screen" : "home",
      "eventType" : "HomePageView",
      "sessionId" : "272F011F-6726-4C7D-A15B-54CEDDAA70A6",
      "eventId" : "A8B17705-3526-4D78-B30B-F818074FF032",
      "dateTime" : "2026-03-27T21:26:11.610Z"
    },
    {
      "category" : "engagement",
      "appVersion" : "1.0",
      "channel" : "mobile",
      "appName" : "SFNewsApp",
      "deviceId" : "FB8E8F03-B1BA-4064-92F3-877006273081",
      "eventType" : "appEvents",
      "sessionId" : "A16154DF-FF6B-4C1B-B47F-249EAD968DCD",
      "behaviorType" : "AppLaunch",
      "eventId" : "4E53E2DE-E04F-45A0-A095-C1213C2B1262",
      "dateTime" : "2026-03-31T17:51:03.430Z"
    }
  ]
}
```
