# Step 5 — Real Android Device Testing Report

## 1. Summary
Step 5 is **IN PROGRESS**. The build environment is verified and the debug APK was successfully built. Real-device testing requires the owner to physically connect their Android phone via USB and execute the test plan below.

**Status**: Waiting for physical Android device connection.

## 2. Device/Environment
- **Computer IP**: `192.168.1.213`
- **Backend**: Django at `/home/erbol/Рабочий стол/WayFinder/wayfinder2/backend`
- **APK**: `build/app/outputs/flutter-apk/app-debug.apk` (built successfully)
- **adb**: Installed and working
- **Physical device**: **NOT CONNECTED YET**

## 3. Pre-Test Checklist

### 3.1 Connect Phone
1. On your Android phone, go to **Settings → About Phone**.
2. Tap **Build Number** 7 times to enable Developer Options.
3. Go to **Settings → System → Developer Options**.
4. Enable **USB Debugging**.
5. Connect phone to computer via USB cable.
6. Accept the **"Allow USB debugging?"** prompt on the phone.
7. Run:
```bash
adb devices
```
You should see something like:
```
List of devices attached
XXXXXXXX    device
```

### 3.2 Start Backend
Open a **separate terminal** and run:
```bash
cd ~/Рабочий\ стол/WayFinder/wayfinder2/backend
source .venv/bin/activate
python manage.py runserver 0.0.0.0:8000
```

### 3.3 Verify Backend from Phone
Open browser on phone and navigate to:
```
http://192.168.1.213:8000/api/v2/health/
```
If it loads, backend connectivity is confirmed.

### 3.4 Run App on Phone
```bash
export JAVA_HOME="$HOME/jdks/temurin17"
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$HOME/flutter/bin:$PATH"

cd ~/Рабочий\ стол/WayFinder/wayfinder2/mobile

flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=API_BASE_URL=http://192.168.1.213:8000/api/v2 \
  --dart-define=WS_BASE_URL=ws://192.168.1.213:8000/ws
```

## 4. Test Plan

### TEST 1: App Launch
- [ ] App installs on phone
- [ ] Splash screen appears
- [ ] No crash on startup
- [ ] Auth/onboarding flow completes
- [ ] HomeCameraScreen loads

### TEST 2: Permissions
- [ ] Camera permission prompt appears → Grant
- [ ] Microphone permission prompt appears → Grant
- [ ] Camera preview activates
- [ ] Deny test: revoke permissions in Android Settings → App shows recovery path, no crash

### TEST 3: Ask WayFinder
- [ ] Tap "Ask WayFinder"
- [ ] Sheet opens, mic button visible
- [ ] Speak: "What is in front of me?"
- [ ] App transitions: Listening → Thinking → Speaking
- [ ] Answer is spoken via TTS
- [ ] Backend terminal shows request to `/api/v2/ask/`

### TEST 4: Analyze Surroundings
- [ ] Tap "Analyze Surroundings"
- [ ] Camera captures video/frame
- [ ] App transitions: Recording → Analyzing → Speaking
- [ ] Guidance is spoken via TTS
- [ ] Backend terminal shows request to `/api/v2/analyze/`
- [ ] Haptic feedback fires if threat detected

### TEST 5: Stop Speaking
- [ ] While TTS is playing, tap "Stop Speaking"
- [ ] TTS stops immediately
- [ ] App returns to Ready state
- [ ] No crash

### TEST 6: Repeat Last Response
- [ ] After Ask or Analyze, tap "Repeat Last Response"
- [ ] Last answer is spoken again
- [ ] If no previous response: app says "No previous response" or similar
- [ ] No crash

### TEST 7: History
- [ ] Open Settings → History
- [ ] Previous Ask/Analyze records appear
- [ ] Records loaded from backend

### TEST 8: TalkBack Accessibility
- [ ] Enable TalkBack: Settings → Accessibility → TalkBack → On
- [ ] Navigate HomeCameraScreen by swiping
- [ ] TalkBack reads: "Ask WayFinder", "Analyze Surroundings", "Stop Speaking", "Repeat Last Response"
- [ ] Double-tap "Ask WayFinder" → sheet opens
- [ ] No unlabeled buttons
- [ ] Focus order is logical

### TEST 9: Offline / Error Handling
- [ ] Turn off Wi-Fi/mobile data
- [ ] Try Ask → App shows/speaks connection error
- [ ] App does not freeze on "Thinking"
- [ ] Turn on Wi-Fi → App recovers
- [ ] Stop backend → Try Ask → App shows/speaks backend error, no crash

### TEST 10: Database Verification
After completing Tests 3-4, run:
```bash
cd ~/Рабочий\ стол/WayFinder/wayfinder2/backend
source .venv/bin/activate

python manage.py shell -c "
from api.models import UserSession, Message
print('sessions=', UserSession.objects.count())
print('messages=', Message.objects.count())
for m in Message.objects.order_by('-created_at')[:10]:
    print(m.id, getattr(m, 'interaction_type', None), getattr(m, 'role', None), str(getattr(m, 'firebase_uid', ''))[:20], str(getattr(m, 'content', ''))[:120])
"
```
- [ ] Ask created Message records (user question + assistant answer)
- [ ] Analyze created Message records
- [ ] firebase_uid/dev uid is present
- [ ] session_id is present

## 5. Results (Fill After Testing)

| Test | Result | Notes |
| :--- | :--- | :--- |
| App Launch | | |
| Permissions | | |
| Ask WayFinder | | |
| Analyze Surroundings | | |
| Stop Speaking | | |
| Repeat Last Response | | |
| History | | |
| TalkBack | | |
| Offline/Error | | |
| DB Verification | | |

## 6. Device Info (Fill After Testing)
- **Phone Model**: 
- **Android Version**: 
- **adb device ID**: 

## 7. Final Status (Fill After Testing)
- Does app run on real Android device? 
- Does Ask work end-to-end? 
- Does Analyze work end-to-end? 
- Does History read backend data? 
- Does TalkBack main flow work? 
- Is app ready for blind-user pilot testing? 
- Is it safe to proceed to Step 6? 

---
*Report template generated by Antigravity AI Verification Suite.*
*Fill results after physical device testing.*
