import Foundation

/// Centralized configuration for the Salesforce Einstein Personalization SDK.
/// Replace placeholder values with real credentials from your Salesforce org before testing live.
enum SDKConfig {

    // MARK: - Data Cloud / CDP Credentials
    // Find these in: Data Cloud Setup > Websites & Mobile Apps > Your Mobile App Connector > Integration Guide
    static let dataCloudAppId: String = "ed3fedc0-d511-444b-9a17-5a748404871a"
    static let dataCloudEndpoint: String = "https://g-2d89jtm-zt1yjtgvrwcmrsm0.c360a.salesforce.com"

    // MARK: - Personalization Point Names
    // Must match exactly what is configured in the Salesforce Einstein Personalization UI
    // under Personalization > Personalization Points
    static let featuredStoryPoint = "Home_Hero_Test"
    static let forYouFeedPoint    = "ios.news.home.for_you_feed"

    // MARK: - Fetch Settings
    static let fetchTimeoutSeconds: Double = 5.0

    // MARK: - Consent
    // For demo/development only — set to true to opt in automatically.
    // In production, gate this on a real user consent UI and persist the decision.
    static let consentOptIn = true
}
