# WayFinder MVP — Setup Guide

## Quick Start (Backend)

```bash
cd wayfinder2/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Create .env from template
cp .env.example .env
# Edit .env: set ALLOW_DEV_AUTH=True for local dev

python manage.py migrate
python manage.py runserver 0.0.0.0:8000

# Verify:
curl http://localhost:8000/api/v2/health/
```

**Mock AI Mode:** Backend runs without GPU by default. Health endpoint shows `"engine_mode": "mock"`.

**Dev Auth:** With `ALLOW_DEV_AUTH=True` in `.env`, use `Authorization: Bearer dev-token` for API calls without Firebase.

## Quick Start (Mobile / Flutter)

```bash
cd wayfinder2/mobile
flutter pub get

# Run WITHOUT Picovoice (wake word disabled, manual button works):
flutter run

# Run WITH Picovoice wake word:
flutter run --dart-define=PICOVOICE_ACCESS_KEY=your_key_here

# Build Android debug APK:
flutter build apk --debug

# Build with Picovoice:
flutter build apk --debug --dart-define=PICOVOICE_ACCESS_KEY=your_key_here
```

## Required Secrets & Configs

### 1. Firebase (for Google Sign-In)

**Android:**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Project: `wayfinder-483708`
3. Project Settings → General → Android app
4. Download `google-services.json`
5. Place at: `mobile/android/app/google-services.json`

**Backend:**
1. Firebase Console → Project Settings → Service accounts
2. Generate new private key (JSON)
3. Set env: `GOOGLE_APPLICATION_CREDENTIALS=/path/to/file.json`

**iOS:** (when ready)
1. Download `GoogleService-Info.plist` from Firebase Console
2. Place at: `mobile/ios/Runner/GoogleService-Info.plist`

### 2. Picovoice Access Key (for wake word)

1. Sign up at [Picovoice Console](https://console.picovoice.ai)
2. Get your Access Key
3. Pass via `--dart-define=PICOVOICE_ACCESS_KEY=your_key`
4. The app works without it — wake word is simply disabled

### 3. AI Model (for real inference)

1. Set `RYNNBRAIN_MODEL_PATH=Qwen/Qwen3-VL-2B-Instruct` in `.env`
2. Requires NVIDIA GPU with CUDA 12+
3. First run downloads the model (~4GB) from HuggingFace

## API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/v2/health/` | No | System status |
| POST | `/api/v2/ask/` | Yes | Ask question with image |
| POST | `/api/v2/analyze/video/` | Yes | Analyze video clip |
| POST | `/api/v2/navigate/` | Yes | Navigation analysis |
| POST | `/api/v2/threats/` | Yes | Threat detection |
| POST | `/api/v2/search/` | Yes | Object search |
| GET | `/api/v2/history/` | Yes | Q&A history |
| WS | `/ws/navigate/` | No | Real-time frame streaming |

## Testing with Dev Auth

```bash
# Health (no auth needed):
curl http://localhost:8000/api/v2/health/

# Ask endpoint (with dev auth):
curl -X POST http://localhost:8000/api/v2/ask/ \
  -H "Authorization: Bearer dev-token" \
  -H "Content-Type: multipart/form-data" \
  -F "question=What is in front of me?" \
  -F "image=@test_image.jpg"
```

## Build for Release

### Android:
```bash
# Create key.properties (see key.properties.example)
# Then:
flutter build apk --release --dart-define=PICOVOICE_ACCESS_KEY=your_key
```

### iOS:
```bash
flutter create --platforms ios .
# Add GoogleService-Info.plist
# Configure signing in Xcode
flutter build ios --no-codesign
```
