# App Store Connect Release Checklist

## 1. App Information
- [ ] **App Name:** WayFinder
- [ ] **Subtitle:** AI Assistant for the Visually Impaired
- [ ] **Primary Language:** English
- [ ] **Category:** Utilities (Primary), Lifestyle (Secondary)
- [ ] **Keywords:** navigation, blind, visually impaired, AI assistant, accessibility, obstacle detection, scene analysis, voice assistant
- [ ] **Support URL:** [PLACEHOLDER — host support page or GitHub]
- [ ] **Marketing URL:** [PLACEHOLDER — optional]
- [ ] **Privacy Policy URL:** [PLACEHOLDER — host PRIVACY_POLICY_DRAFT.md publicly]

## 2. Graphic Assets
- [ ] **App Icon:** 1024x1024 PNG, no transparency, no rounded corners (iOS auto-rounds)
- [ ] **Screenshots:**
  - Required: 6.7-inch (iPhone 15 Pro Max) — minimum 3
  - Required: 6.5-inch (iPhone 11 Pro Max) — minimum 3
  - Optional: 5.5-inch (iPhone 8 Plus)
  - Optional: iPad Pro 12.9-inch (if supporting iPad)
- [ ] **App Preview Video:** Optional but highly recommended for accessibility apps

## 3. App Privacy Nutrition Labels

| Data Type | Collected | Linked to User | Used for Tracking |
|:---|:---|:---|:---|
| Contact Info (Email) | Yes | Yes | No |
| Identifiers (User ID) | Yes | Yes | No |
| User Content (Photos/Videos) | Yes (temp) | No | No |
| User Content (Audio) | Yes (temp) | No | No |
| User Content (Text) | Yes | Yes | No |
| Diagnostics (Crash/Performance) | No | No | No |
| Usage Data | No | No | No |

### Notes for Nutrition Labels
- Photos/Videos and Audio are processed in real time and NOT stored permanently.
- Text content (questions and AI responses) is stored linked to the user's account.
- No third-party tracking SDKs are used.
- Firebase Authentication is used for sign-in only.

## 4. Permission Explanations (Info.plist)

| Permission Key | User-Facing String |
|:---|:---|
| `NSCameraUsageDescription` | WayFinder uses your camera to analyze your surroundings and detect obstacles to provide navigation assistance. |
| `NSMicrophoneUsageDescription` | WayFinder uses your microphone for voice commands and questions about your surroundings. The "WayFinder" wake word is detected entirely on your device. |
| `NSSpeechRecognitionUsageDescription` | WayFinder uses speech recognition to convert your spoken questions into text for AI processing. |

## 5. Firebase / Sign-In Configuration
- [ ] `GoogleService-Info.plist` added to Runner target
- [ ] Google Sign-In configured in Firebase Console for iOS
- [ ] URL schemes added to Info.plist (reversed client ID)
- [ ] Keychain sharing configured if needed

## 6. App Review Information

### Review Notes (copy to App Store Connect)
```
WayFinder is an accessibility application for blind and visually impaired users.

How to test:
1. Sign in with any Google account.
2. Grant camera and microphone permissions when prompted.
3. Say "WayFinder" or tap the microphone button to ask a question about your surroundings.
4. Tap "Analyze" to get a scene description with obstacle detection.
5. Test with VoiceOver enabled for the intended user experience.

Important:
- This app is assistive support only — it does not replace a white cane, guide dog, or human assistance.
- The camera and microphone are essential for the app's core accessibility features.
- AI scene analysis requires an active internet connection to the backend server.
- Without a deployed backend, the app runs in mock/demo mode.
```

### Demo Account
- No special demo account needed — sign in with any Google account.
- If reviewer has issues with sign-in, provide: "The app uses standard Google Sign-In via Firebase. No special credentials are required."

## 7. Known Review Risks

| Risk | Mitigation |
|:---|:---|
| Safety claims | App clearly states it is assistive support only, not a safety device |
| Health/Accessibility sensitivity | No medical claims. Positioned as supplementary tool |
| Camera/Microphone permissions | Clear justification in Info.plist. Core to app function |
| AI output quality | Disclaimers in app and store listing about accuracy limitations |
| Backend dependency | App degrades gracefully with error messages if backend unavailable |

## 8. TestFlight Release

### Steps
1. [ ] Build iOS archive in Xcode: Product → Archive
2. [ ] Upload to App Store Connect via Xcode or Transporter
3. [ ] Fill out Export Compliance: "Yes, the app uses standard encryption (HTTPS)"
4. [ ] Wait for processing (5-30 minutes)
5. [ ] Add Internal Testers (up to 25)
6. [ ] Submit for Beta App Review to add External Testers

### Pre-Upload Checks
- [ ] Bundle ID matches Firebase config: `com.wayfinder.app` (verify actual)
- [ ] Version and build number incremented
- [ ] No debug flags or test endpoints in release build
- [ ] No placeholder text visible in UI
- [ ] Signing certificate and provisioning profile valid

## 9. Pre-Submission Checks
- [ ] Privacy Policy hosted at public URL and linked in App Store Connect
- [ ] App builds and archives without errors
- [ ] All permission strings are clear and justified
- [ ] No hardcoded secrets in binary
- [ ] App gracefully handles denied permissions
- [ ] App gracefully handles no internet connection
- [ ] VoiceOver navigation works for all primary screens
