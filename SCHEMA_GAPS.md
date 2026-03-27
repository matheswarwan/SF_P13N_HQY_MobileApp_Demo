# SF Personalization — Schema Gaps & Custom Fields Needed

This document lists fields the app sends that **do not exist** in the current SF P13N data stream schemas, and fields that were fixed to match the schema.

---

## Current Data Streams (from SF P13N)

| Data Stream | Developer Name | Category | Status |
|---|---|---|---|
| App Events | `appEvents` | Engagement | In Use |
| Cart | `cart` | Engagement | In Use |
| Cart Item | `cartItem` | Engagement | In Use |
| Catalog | `catalog` | Engagement | In Use |
| Consent | `consentLog` | Engagement | In Use |
| Contact Point Address | `contactPointAddress` | Profile | In Use |
| Contact Point Email | `contactPointEmail` | Profile | In Use |
| Contact Point Phone | `contactPointPhone` | Profile | In Use |
| Identity | `identity` | Profile | In Use |
| Order | `order` | Engagement | In Use |
| Order Item | `orderItem` | Engagement | In Use |
| Party Identification | `partyIdentification` | Profile | In Use |

---

## Field That Needs to Be Added

### `Gender` — Identity Data Stream

| Property | Value |
|---|---|
| **Stream** | `identity` |
| **Field Name** | `Gender` |
| **Data Type** | `Text` |
| **Required** | No |
| **Description** | User-selected gender (Male, Female, Non-binary, Prefer not to say) |
| **App sends as** | `modifier.addAttribute(key: "Gender", value: ...)` in `identity.edit` and as `attributes["Gender"]` in `IdentityEvent` |
| **Action needed** | Add a custom `Gender` (Text) field to the `identity` data stream in Salesforce Data Cloud setup |

### How to add Gender in Salesforce

1. Go to **Data Cloud Setup** > **Data Streams**
2. Find the `identity` data stream under your Mobile App connector
3. Click **Edit** or **Manage Fields**
4. Add:
   - **Developer Name**: `Gender`
   - **Data Type**: `Text`
   - **Required**: `No`
5. Save and deploy
6. The next time the app sends an `IdentityEvent` with `Gender`, Data Cloud will map it to the new field

---

## Marketing Preferences — Uses Existing `consentLog` Stream

Marketing preferences (email, push, SMS, digest, alerts) are sent as **consent events** using the existing `consentLog` data stream schema. No new fields or streams are needed.

Each preference toggle sends a separate consent event with:

| Schema Field | Value |
|---|---|
| `purpose` | The preference name (e.g., `"Marketing Email"`, `"Push Notifications"`) |
| `status` | `"Opt In"` or `"Opt Out"` |
| `provider` | `"HealthEquity Mobile App"` |

### Consent events sent by the app

| Toggle in Profile | `purpose` value | `status` |
|---|---|---|
| Marketing Emails | `Marketing Email` | `Opt In` / `Opt Out` |
| Push Notifications | `Push Notifications` | `Opt In` / `Opt Out` |
| SMS Offers | `SMS Marketing` | `Opt In` / `Opt Out` |
| Weekly Benefits Digest | `Weekly Digest` | `Opt In` / `Opt Out` |
| Benefit Alerts | `Benefit Alerts` | `Opt In` / `Opt Out` |

These map directly to the `consentLog` schema fields:
- `purpose` (Text, optional) — what the user consents to
- `status` (Text, required) — `"Opt In"` or `"Opt Out"`
- `provider` (Text, optional) — consent source

System fields (`eventId`, `dateTime`, `eventType`, `sessionId`, `deviceId`, `category`) are populated automatically by the SDK.

Reference: [Consent Schema Documentation](https://developer.salesforce.com/docs/data/data-cloud-engagement-mobile-sdk/guide/c360a-api-engagement-mobile-sdk-consent-schema.html)

---

## Fields Fixed (Were Mismatched)

These fields were being sent with incorrect keys that didn't match the schema. They have been corrected:

| Was Sending | Schema Expects | Stream | Status |
|---|---|---|---|
| `phone` | `phoneNumber` | `identity` | **FIXED** |
| `zipCode` | `postalCode` | `identity` | **FIXED** |
| `contactPointPhone` (in IdentityEvent) | `phoneNumber` | `identity` | **FIXED** |

---

## Identity Fields — Current Mapping

| App Field | Schema Field | Stream | Status |
|---|---|---|---|
| `email` | `email` | `identity` | Matching |
| `firstName` | `firstName` | `identity` | Matching |
| `lastName` | `lastName` | `identity` | Matching |
| `phoneNumber` | `phoneNumber` | `identity` | Matching (fixed) |
| `postalCode` | `postalCode` | `identity` | Matching (fixed) |
| `Gender` | — | `identity` | **Needs to be added** |
| `contactPointEmail` | `email` | `contactPointEmail` | Matching |
| `phoneNumber` | `phoneNumber` | `contactPointPhone` | Matching (fixed) |

---

## Summary

| Category | Count | Details |
|---|---|---|
| **Custom field needed** | 1 | `Gender` on `identity` stream |
| **Uses existing stream** | 5 preferences | Via `consentLog` (purpose/status/provider pattern) |
| **Fixed key mismatches** | 3 | phone→phoneNumber, zipCode→postalCode, contactPointPhone→phoneNumber |
| **Already matching** | 5 | email, firstName, lastName, contactPointEmail, phoneNumber |
