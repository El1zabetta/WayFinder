# iOS Build Fix Guide

The current machine (`Kali Linux`) lacks macOS and Xcode, which are strictly required to build the iOS version of WayFinder (`.ipa` or `.app` for Simulator).

To release the iOS app to TestFlight or run it on a real iPhone, follow these instructions on a **macOS device**.

## 1. Environment Setup (macOS)
1. Install [Xcode](https://developer.apple.com/xcode/) from the Mac App Store.
2. Install [CocoaPods](https://cocoapods.org/) (dependency manager for iOS):
   ```bash
   sudo gem install cocoapods
   ```
3. Open Xcode once to accept the license agreement and install the command-line tools.

## 2. Generate and Configure iOS Workspace
If `Podfile` does not exist yet, running `flutter build ios` will generate it.
1. From the `mobile/` directory, run:
   ```bash
   flutter clean
   flutter pub get
   cd ios
   pod install
   ```

2. Open the workspace in Xcode:
   ```bash
   open Runner.xcworkspace
   ```

## 3. Configure Signing & Capabilities in Xcode
1. In Xcode, select the `Runner` project in the left sidebar.
2. Go to the **Signing & Capabilities** tab.
3. Check the box **"Automatically manage signing"**.
4. Select your **Team** (requires an Apple Developer account).
5. Ensure the **Bundle Identifier** is set to a valid unique ID (e.g., `com.wayfinder.app`).

## 4. Firebase Configuration
For iOS, Firebase requires the `GoogleService-Info.plist` file.
1. Go to your [Firebase Console](https://console.firebase.google.com).
2. Add an iOS app using your Bundle Identifier (`com.wayfinder.app`).
3. Download the `GoogleService-Info.plist` file.
4. Drag and drop this file into Xcode, placing it directly under the `Runner` folder (same level as `Info.plist`). **Ensure "Copy items if needed" is checked**.

## 5. Podfile Adjustments
If you encounter deployment target errors, open `ios/Podfile` and ensure the second line is uncommented and set to at least iOS 13.0:
```ruby
platform :ios, '13.0'
```
Then run `cd ios && pod install` again.

## 6. Build and Release
To test on a physical device, connect your iPhone and hit the "Play" button in Xcode, or run:
```bash
flutter run -d <your-device-id>
```

To create a TestFlight release:
1. In Xcode, change the target device from a simulator to "Any iOS Device (arm64)".
2. Go to **Product > Archive** from the menu bar.
3. Once archiving completes, the Xcode Organizer will open.
4. Click **Distribute App** and follow the prompts to upload to TestFlight / App Store Connect.
