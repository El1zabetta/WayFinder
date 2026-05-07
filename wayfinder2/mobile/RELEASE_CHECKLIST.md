# 🚀 WayFinder 3.0 Release Checklist

This checklist ensures the app is ready for submission to the App Store and Google Play.

## 📱 App Information
- **App Name**: WayFinder
- **Short Description**: AI-powered navigation assistant for the visually impaired.
- **Full Description**: WayFinder uses the RynnBrain-2B AI model to provide real-time spatial awareness, obstacle detection, and navigation guidance via spatial audio. Features include wake word activation ("Way Finder") and voice-first Q&A about the environment.
- **Privacy Policy**: Required (must state that camera/mic data is processed for navigation and not sold to 3rd parties).
- **Safety Disclaimer**: "WayFinder is an assistive tool and not a replacement for traditional mobility aids (canes, guide dogs). Always prioritize your physical safety."

## 🔐 Permissions Explanation
- **Camera**: Used to analyze the environment and detect obstacles in real-time.
- **Microphone**: Used for wake word detection and voice commands/questions.
- **Location**: (Optional) Used for mapping and destination-based navigation.

## 🎨 Assets Checklist
- [ ] App Icon (1024x1024)
- [ ] Splash Screen
- [ ] Screenshots:
    - [ ] Home Screen with Camera Preview
    - [ ] AI Assistant Sheet (Q&A mode)
    - [ ] Navigation guidance card active
    - [ ] Audio Compass visualization

## 🛠 Technical QA
- [ ] **Wake Word**: Works on Android and iOS (best-effort).
- [ ] **Offline Mode**: App provides safety hints when the server is unreachable.
- [ ] **Screen Reader**: All buttons have meaningful `Semantics` labels.
- [ ] **Latency**: Backend metrics show <500ms inference time on GPU.
- [ ] **Battery**: App handles background state correctly (stops camera/mic).

## 📦 Build Commands
### Android
```bash
flutter build apk --release --flavor prod
# OR
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
# Then open Xcode and Archive
```

## ⚠️ Known Limitations
- Requires active internet connection for high-quality AI analysis.
- Performance depends on GPU availability on the backend.
- Low-light conditions may affect vision accuracy.
