# Android Real Device Testing Guide

This guide describes how to deploy and test the WayFinder app on a physical Android device, ensuring both technical functionality and accessibility.

## 1. Prerequisites
- Physical Android device (Android 7.0+ / API 24+).
- USB cable.
- A computer with Android SDK installed.
- (Optional) Picovoice Access Key for wake word testing.

## 2. Device Preparation
1. Open **Settings** on your phone.
2. Go to **About Phone**.
3. Tap **Build Number** 7 times until "Developer mode" is enabled.
4. Go to **System > Developer Options**.
5. Enable **USB Debugging**.
6. Connect the phone to your computer and accept the "Allow USB Debugging" prompt on the device.

## 3. Verify Connection
Run:
```bash
adb devices
```
You should see your device listed as `device`.

## 4. Local Backend Setup
To test with your computer's local Django backend:
1. Ensure both your computer and phone are on the same Wi-Fi network.
2. Find your computer's local IP:
   - Linux/Mac: `hostname -I` or `ip addr`
   - Windows: `ipconfig`
3. Run the backend:
   ```bash
   cd backend
   source .venv/bin/activate
   python manage.py runserver 0.0.0.0:8000
   ```

## 5. Deployment Commands

### Option A: Standard Debug (No Wake Word)
```bash
cd mobile
flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=API_BASE_URL=http://YOUR_COMPUTER_IP:8000/api/v2 \
  --dart-define=WS_BASE_URL=ws://YOUR_COMPUTER_IP:8000/ws
```

### Option B: Full Test (With Wake Word)
```bash
flutter run \
  --dart-define=PICOVOICE_ACCESS_KEY=YOUR_KEY \
  --dart-define=APP_ENV=dev \
  --dart-define=API_BASE_URL=http://YOUR_COMPUTER_IP:8000/api/v2 \
  --dart-define=WS_BASE_URL=ws://YOUR_COMPUTER_IP:8000/ws
```

## 6. Accessibility (TalkBack) Checklist
Once the app is running:
1. **Enable TalkBack**: Settings > Accessibility > TalkBack > On.
2. **Main Navigation**:
   - Swipe through: "Ask WayFinder", "Analyze Surroundings", "Stop", "Repeat".
   - Verify every button has a clear label (no "Unlabelled button").
3. **Ask Assistant**:
   - Double-tap "Ask WayFinder".
   - Verify announcement: "Assistant opened. Tap mic to ask a question."
   - Test "Stop Speaking" button behavior.
4. **Analysis Flow**:
   - Double-tap "Analyze Surroundings".
   - Verify haptic feedback (vibration) matches threat levels.
   - Verify announcement of analyzed results.
5. **Wakeword**:
   - Say "Way Finder".
   - Verify the "Ask Assistant" sheet opens automatically.

## 7. Data Flow Verification
On the physical device:
1. Perform a voice question (e.g., "What is in front of me?").
2. Check your backend terminal logs to see the `/api/v2/ask/` request.
3. In the mobile app, go to **Settings > History**.
4. Verify the question and answer are persisted correctly.
5. Check Django Admin (`/admin/api/message/`) to ensure records are created with correct `firebase_uid`.

## 8. Troubleshooting
- **Connection Refused**: Ensure the backend is running on `0.0.0.0` and your phone can ping your computer's IP.
- **Camera Not Opening**: Verify permissions were granted in the Android "Permissions" screen.
- **Wake Word Not Responding**: Ensure `PICOVOICE_ACCESS_KEY` is valid and the mic permission is granted.
