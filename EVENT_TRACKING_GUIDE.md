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
