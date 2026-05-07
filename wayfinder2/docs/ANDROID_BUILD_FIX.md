# Android Build Fix Guide

The current machine (`Kali Linux`) lacks the Android SDK, preventing Flutter from building the APK/AAB files. Follow these steps to resolve the build blockers.

## 1. Install Android SDK

The easiest way to get the correct SDK and build tools is to install Android Studio or the command-line tools.

### Option A: Install Android Studio (Recommended)
1. Download Android Studio for Linux from [developer.android.com/studio](https://developer.android.com/studio).
2. Extract the archive and run `bin/studio.sh`.
3. Follow the setup wizard to install the default Android SDK.
4. Go to **SDK Manager** and ensure you have:
   - Android API 34 (UpsideDownCake)
   - Android SDK Command-line Tools (latest)
   - Android SDK Build-Tools (latest)
   - NDK (Side by side)

### Option B: Command Line Only
```bash
sudo apt-get install android-sdk
```
*(Note: Distribution packages are often outdated. Official tools are preferred).*

## 2. Configure Environment Variables

Add the following to your `~/.bashrc` or `~/.zshrc`:

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin
```
Run `source ~/.bashrc`.

## 3. Accept Licenses and Link Flutter

Run the following commands:
```bash
flutter config --android-sdk $ANDROID_HOME
flutter doctor --android-licenses
```
Accept all licenses by pressing `y`.

## 4. Build the App

Once `flutter doctor -v` shows a green checkmark for the Android toolchain, you can build:

```bash
cd wayfinder2/mobile
flutter build apk --debug
```

## 5. Release Signing
For production, you need an upload keystore.
1. Generate the keystore:
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy `key.properties.example` to `key.properties` in `android/`.
3. Update the values in `key.properties` with your passwords.
4. Build release:
   ```bash
   flutter build apk --release
   # OR
   flutter build appbundle --release
   ```
