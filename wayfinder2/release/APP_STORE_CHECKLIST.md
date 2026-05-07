# App Store Connect Release Checklist

## 1. App Information
- [ ] **App Name:** WayFinder
- [ ] **Subtitle:** AI Navigation Assistant
- [ ] **Primary Language:** English (or Russian, depending on your primary market)
- [ ] **Category:** Navigation / Medical / Utilities
- [ ] **Keywords:** navigation, blind, visually impaired, AI assistant, accessibility

## 2. Graphic Assets
- [ ] **App Icon:** 1024x1024 PNG without transparency (Add to Xcode `Assets.xcassets`).
- [ ] **Screenshots:** 
  - Required: 6.5-inch (iPhone Pro Max) screenshots.
  - Required: 5.5-inch (iPhone Plus) screenshots.

## 3. Privacy & Permissions
- [ ] **Privacy Policy URL:** Host `PRIVACY_POLICY_DRAFT.md` and paste the link.
- [ ] **App Privacy Labels (Nutrition Labels):**
  - Data Collected: User Content (Audio Data, Photos/Videos), Identifiers (User ID via Firebase).
  - Linked to User: Yes (History is saved to account).
  - Tracking: No.
- [ ] **Permission Justifications:** Apple reviewers are strict about hardware access. Ensure your `Info.plist` descriptions clearly explain *why* the camera and microphone are needed for accessibility.

## 4. App Review Requirements
- [ ] **Demo Account:** If Firebase Auth requires login, you MUST provide a demo username and password in the App Review Information section, or explain that users can sign in with Google.
- [ ] **Review Notes:** Add a note to the reviewer: "This app is an accessibility tool for visually impaired users. The camera and microphone are used to analyze surroundings in real-time. Please test using VoiceOver."
- [ ] **Video Demo:** Consider attaching a short screen recording of how the app is intended to be used, as reviewers may not immediately understand the egocentric camera interaction.

## 5. TestFlight & Release
- [ ] Upload build via Xcode or Transporter.
- [ ] Fill out export compliance (Standard Encryption used by HTTPS).
- [ ] Add Internal Testers.
- [ ] Submit for Beta App Review to add External Testers.
