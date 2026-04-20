// No code file was provided for modification or addition, only a detailed plan and instructions.
// Since no specific code file content was given, here is the full plan text formatted as a Swift multiline comment block,
// assuming the request is to keep the provided text in a Swift source file.

// If you need this content in a specific file or format, please specify.

//
//  MobilePushIntegrationPlan.swift
//  YourApp
//
//  Created by Integration Team on 2026-04-20.
//

/*
# Mobile Push Integration: Initial Discussion

This document outlines the plan to integrate Salesforce Marketing Cloud (SFMC) MobilePush SDK into the iOS app, the steps required in SFMC and Apple Developer, and the code-level changes we will make once credentials (including the APNs .p8 file) are available.

> Status: Waiting for APNs .p8 key. We will wire this into SFMC once available and then proceed with device registration and end-to-end testing.

---

## High-Level Overview

- In SFMC: Configure a MobilePush app, upload APNs key/cert, link it to the iOS bundle ID, and retrieve credentials (App ID, Access Token, MID, server URL).
- In Apple Developer: Ensure the App ID is push-enabled, generate an APNs authentication key (.p8), and reference its Key ID and Team ID in SFMC.
- In iOS app: Add the SFMC SDK, request notification permission, register device token, initialize/configure the SDK, handle notification delivery and interaction, and (optionally) deep links, analytics, and attributes.
- Test end-to-end from SFMC to device and verify events.

---

## Prerequisites & Pending Items

- Apple Developer access to create/manage:
  - App ID (bundle identifier must match the app)
  - APNs Auth Key (.p8) with Key ID
  - Team ID
- SFMC MobilePush app will need:
  - App ID (from SFMC)
  - Access Token (from SFMC)
  - MID (from SFMC)
  - Marketing Cloud Server URL (e.g., https://YOUR_SUBDOMAIN.rest.marketingcloudapis.com)
- Pending: APNs .p8 file (we will upload to SFMC when available).

---

## SFMC Console Setup

1. Provision iOS App for Push with Apple
   - Confirm App ID (bundle identifier, e.g., com.example.myapp) has Push Notifications capability enabled in Apple Developer.
   - Create an APNs Auth Key (.p8): Developer portal → Keys → Create → Enable APNs → Download .p8 and note Key ID and Team ID.

2. Configure MobilePush App in SFMC
   - Mobile Studio → MobilePush → Administration → Apps → Create App → iOS.
   - Provide:
     - Bundle ID (must match iOS app bundle identifier)
     - APNs Auth Key (.p8), Key ID, Team ID
     - Environment: Sandbox (development) and/or Production
   - After creation, record:
     - SFMC App ID
     - Access Token
     - MID
     - Server URL (stack-specific)

3. Data Model (optional but recommended)
   - Define attributes (e.g., locale, tier) and tags (e.g., segments) to be set from device.
   - Decide on contact key strategy (e.g., CRM ID, hashed email).

---

## iOS App Integration Plan

### 1) Add SDK Dependency

- Preferred: Swift Package Manager (SPM) if available for your SFMC SDK version.
- Alternative: CocoaPods example:

