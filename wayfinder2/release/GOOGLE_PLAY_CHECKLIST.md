# Google Play Store Release Checklist

## 1. App Details
- [ ] **App Name:** WayFinder
- [ ] **Short Description (max 80):** AI assistant that describes surroundings and answers questions by voice.
- [ ] **Full Description:** See [STORE_LISTING_DRAFT.md](STORE_LISTING_DRAFT.md)
- [ ] **Category:** Tools > Accessibility (recommended). Alternative: Lifestyle or Health & Fitness.

## 2. App Access
- [ ] **Sign-in required:** Yes — Google Sign-In via Firebase Authentication.
- [ ] **Test credentials:** For review, provide: "Sign in with any Google account. No special permissions needed. App uses camera and microphone for AI scene analysis."

## 3. Graphic Assets
- [ ] **App Icon:** 512x512 PNG, 32-bit, no transparency
- [ ] **Feature Graphic:** 1024x500 PNG
- [ ] **Phone Screenshots:** Minimum 2, recommended 4-8 (see [SCREENSHOT_PLAN.md](SCREENSHOT_PLAN.md))
- [ ] **Tablet Screenshots:** Optional for MVP
- [ ] **Promo Video:** Optional but recommended (30-60 seconds accessibility demo)

## 4. Data Safety Form

### Data Collected

| Data Type | Collected | Purpose |
|:---|:---|:---|
| User IDs (Firebase UID) | Yes | Account management, history scoping |
| Email address | Yes | Authentication via Google Sign-In |
| Photos/Videos | Yes (temporary) | AI scene analysis — **not stored permanently** |
| Audio | Yes (temporary) | Voice questions — converted to text, **audio not stored** |
| User-generated content | Yes | Question text and AI response text in history |

### Data Safety Answers
- [ ] **Data encrypted in transit:** Yes (HTTPS/TLS)
- [ ] **Data encrypted at rest:** Yes (server database encryption)
- [ ] **Users can request data deletion:** Yes (via [CONTACT EMAIL])
- [ ] **Data shared with third parties:** No (Firebase Auth is infrastructure, not sharing)
- [ ] **Compliant with Families Policy:** N/A (not a children's app)

## 5. Permissions Declaration

| Permission | Justification |
|:---|:---|
| `CAMERA` | Required to capture real-time video frames of the user's surroundings for AI scene analysis and obstacle detection. |
| `RECORD_AUDIO` | Required for voice-activated questions (speech-to-text) and wake word detection ("WayFinder"). Wake word processing is offline. |
| `INTERNET` | Required to send video frames and text questions to the AI processing backend and receive scene analysis results. |
| `VIBRATE` | Used for haptic feedback when obstacles or hazards are detected, providing non-visual alerts. |
| `ACCESS_NETWORK_STATE` | Used to check connectivity status before making backend requests, ensuring graceful offline handling. |

## 6. App Content
- [ ] **Target Audience:** 13 and older
- [ ] **Content Rating:** Complete IARC questionnaire (expected result: "Everyone")
- [ ] **Accessibility:** Mark as accessibility-focused application
- [ ] **Health claims:** None — app is assistive support only, not a medical device

## 7. Release Tracks

### Internal Testing (FIRST)
- [ ] Generate signed AAB: `flutter build appbundle --release`
- [ ] Upload AAB to Internal Testing track
- [ ] Add tester emails (up to 100 internal testers)
- [ ] Share opt-in link with testers
- [ ] Collect feedback for minimum 1 week
- [ ] Complete real-device testing checklist

### Closed Testing (AFTER Internal)
- [ ] Promote build from Internal to Closed Testing
- [ ] Wait for Google review (up to 7 days for new apps)
- [ ] Add additional testers via Google Groups

### Production (AFTER Closed)
- [ ] Only after closed testing approval and stability confirmation
- [ ] Staged rollout recommended (10% → 50% → 100%)
- [ ] **BLOCKER:** Real-device and TalkBack testing must be completed first

## 8. Release Notes Template (Internal Testing)

```
WayFinder v2.0.0 — Internal Testing Build

What's included:
• AI-powered scene analysis via camera
• Voice-activated questions ("Ask WayFinder")
• Obstacle detection with directional guidance
• Interaction history
• TalkBack-compatible design

Known limitations:
• AI runs in mock mode without GPU backend
• Real AI model requires server deployment with NVIDIA GPU
• Not a safety device — assistive support only

Please report issues to [CONTACT EMAIL]
```

## 9. Pre-Submission Checks
- [ ] Privacy Policy hosted at a public URL
- [ ] Terms of Service available
- [ ] App builds without errors
- [ ] All test suites pass
- [ ] No hardcoded secrets in APK/AAB
- [ ] No placeholder/debug text visible to users
- [ ] Signing keystore secured and backed up
