# Picovoice (Wake Word) Setup Guide

WayFinder uses [Picovoice Porcupine](https://picovoice.ai/) to detect the wake word offline without streaming continuous audio to the backend.

## 1. Get an Access Key
1. Sign up for a free account at the [Picovoice Console](https://console.picovoice.ai).
2. Copy your **AccessKey** from the dashboard.

## 2. Generate Keyword Models (`.ppn`)
Picovoice requires specific binary models (`.ppn` files) for each platform (Android and iOS).
1. In the Picovoice Console, go to **Porcupine > Wake Word**.
2. Create a new custom wake word, e.g., "Way Finder".
3. Download the model for **Android**. It will yield a `.ppn` file.
4. Download the model for **iOS**. It will yield another `.ppn` file.
5. Rename and place them in the project:
   - `mobile/assets/models/wayfinder_android.ppn`
   - `mobile/assets/models/wayfinder_ios.ppn`
6. Make sure these assets are declared in your `mobile/pubspec.yaml`.

## 3. Running the App with Wake Word Enabled
By default, if the access key is missing, the wake word feature gracefully disables itself. You can still use the app by tapping the manual microphone button.

To enable the wake word during development, run:
```bash
flutter run --dart-define=PICOVOICE_ACCESS_KEY=your_copied_key_here
```

To build a release APK with the wake word enabled:
```bash
flutter build apk --release --dart-define=PICOVOICE_ACCESS_KEY=your_copied_key_here
```

## Troubleshooting
- **App crashes on startup:** Ensure you passed the `--dart-define` flag correctly. The code in `wakeword_service.dart` is designed to fail gracefully, but invalid `.ppn` files might cause native crashes.
- **Wake word not detected:** Ensure microphone permissions were granted and the `.ppn` file matches the current platform.
