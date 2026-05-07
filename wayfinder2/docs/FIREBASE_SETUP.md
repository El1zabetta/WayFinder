# Firebase Cross-Platform Setup Guide

WayFinder uses Firebase for Authentication (Google Sign-In). Follow these steps to properly link both Android and iOS versions to your backend.

## 1. Firebase Console Setup
1. Go to the [Firebase Console](https://console.firebase.google.com).
2. Create a new project or select your existing `wayfinder-483708` project.
3. Go to **Authentication > Sign-in method** and enable **Google**.

## 2. Android Configuration
1. In the Firebase console, click **Add app** and select **Android**.
2. **Package Name:** `com.wayfinder.app`
3. **App Nickname:** WayFinder Android
4. **SHA-1 Certificate Fingerprint:** (Required for Google Sign-In)
   - To get your SHA-1 key, run: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
   - For release, use the SHA-1 from your `upload-keystore.jks`.
5. Click **Register app** and download `google-services.json`.
6. Place the file at: `mobile/android/app/google-services.json`.

## 3. iOS Configuration
1. In the Firebase console, click **Add app** and select **iOS**.
2. **Apple Bundle ID:** `com.wayfinder.app`
3. Click **Register app** and download `GoogleService-Info.plist`.
4. Open the iOS project in **Xcode** (`ios/Runner.xcworkspace`).
5. Drag and drop `GoogleService-Info.plist` into the `Runner` folder inside Xcode. Ensure "Copy items if needed" is checked.
6. (Optional) If you get URL Scheme errors during login, add the `REVERSED_CLIENT_ID` from the `GoogleService-Info.plist` to your Xcode project's **URL Types** in the Info tab.

## 4. Backend Configuration (Django)
The backend needs a Service Account to verify the Firebase ID tokens sent by the mobile app.
1. In the Firebase console, go to **Project settings > Service accounts**.
2. Click **Generate new private key**.
3. Save the downloaded JSON file securely on your server (e.g., `/etc/wayfinder/firebase-service-account.json`).
4. Set the environment variable in your backend `.env` file:
   ```env
   GOOGLE_APPLICATION_CREDENTIALS=/etc/wayfinder/firebase-service-account.json
   ```
   *(Alternatively, use `FIREBASE_CREDENTIALS_JSON` to pass the JSON as a string).*

## Dev Mode (No Firebase)
If you just want to develop the backend and frontend locally without Firebase:
1. In the backend `.env`, set `ALLOW_DEV_AUTH=True`.
2. In the frontend (mobile), the `AuthScreen` will allow bypassing Firebase if the backend accepts `Bearer dev-token`.

**WARNING:** Never enable `ALLOW_DEV_AUTH=True` in production!
