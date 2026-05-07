# WayFinder Security + Privacy Audit Report (Step 6)

## 1. Summary
A comprehensive security and privacy audit was performed across the entire WayFinder project (backend + mobile). Two critical issues were identified and fixed. The overall security posture is solid for an MVP, with production-safe defaults already in place.

## 2. Secret Scan Results

### Scan Command
```
grep -RInE "(api[_-]?key|secret|token|password|private_key|...)" . --exclude-dir=...
```

### Findings

| Item | Status | Detail |
|:---|:---|:---|
| `backend/.env` | ✅ SAFE | Contains dev defaults only. `.gitignore` ignores `.env`. |
| `backend/.env.production.example` | ✅ SAFE | Template with placeholder values. |
| `mobile/lib/core/secrets.dart` | ✅ SAFE | Uses `String.fromEnvironment()` only. No hardcoded keys. |
| `mobile/android/app/google-services.json` | ✅ SAFE | Real file is gitignored by root and mobile `.gitignore`. |
| `mobile/ios/Runner/GoogleService-Info.plist` | ✅ SAFE | Real file is gitignored. |
| `android/key.properties` | ✅ SAFE | Gitignored. Only `.example` tracked. |
| Firebase service account JSON | ✅ SAFE | No credential file found on disk. |
| `*.jks` / `*.keystore` | ✅ SAFE | Gitignored. None committed. |

### Issues Found and Fixed

| Severity | Issue | Fix |
|:---|:---|:---|
| **CRITICAL** | `authentication.py` line 65 contained hardcoded Firebase credential filename: `wayfinder-483708-firebase-adminsdk-fbsvc-e94ec7bd43.json`. This leaks the service account key ID in source code. | Replaced with generic `firebase-service-account.json`. |
| **MEDIUM** | `/api/v2/health/` endpoint exposed `model_path` (internal server filesystem path) and `memory_entries` (internal state count) to unauthenticated users. | Removed both fields from health response. |

## 3. Backend Security Audit

### 3.1 Django Settings (`settings.py`)

| Check | Status | Detail |
|:---|:---|:---|
| `SECRET_KEY` | ✅ | Defaults to dev key; reads from `DJANGO_SECRET_KEY` env var. |
| `DEBUG` | ✅ | Defaults to `True` for dev; reads from `DEBUG` env var. |
| `ALLOWED_HOSTS` | ✅ | Reads from env; defaults to `*` for dev. |
| `CORS` | ✅ | `CORS_ALLOW_ALL_ORIGINS = DEBUG` — only allows all in debug mode. |
| `Production HTTPS` | ✅ | When `DEBUG=False`: `SECURE_SSL_REDIRECT`, `SECURE_HSTS_SECONDS=31536000`, `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE`, `SECURE_CONTENT_TYPE_NOSNIFF` all enabled. |
| `Throttling` | ✅ | `AnonRateThrottle: 20/min`, `UserRateThrottle: 60/min` enabled globally. |
| `Upload Limits` | ✅ | `DATA_UPLOAD_MAX_MEMORY_SIZE = 10MB`, `FILE_UPLOAD_MAX_MEMORY_SIZE = 10MB`. Video size also checked per-endpoint. |
| `Error Handling` | ✅ | All endpoints catch exceptions and return structured `{"error": "..."}` JSON. Stack traces only in server logs, never in API responses. |
| `Logging` | ✅ | Rotating file handler (10MB, 5 backups). Logs uid prefix only (`uid[:8]`), never full tokens or raw media. |

### 3.2 Authentication (`authentication.py`)

| Check | Status | Detail |
|:---|:---|:---|
| Dev Auth Guard | ✅ | Only activates when **both** `DEBUG=True` **AND** `ALLOW_DEV_AUTH=True`. |
| `dev-token` in production | ✅ SAFE | Impossible when `DEBUG=False`. |
| Firebase token validation | ✅ | Uses `firebase_auth.verify_id_token()` with proper exception handling. |
| `FirebaseUser.pk` | ✅ | Set to `uid` for DRF throttling compatibility. |
| Token not logged | ✅ | Only `uid` and `email` are logged, never the token itself. |

### 3.3 API Views (`views.py`)

| Check | Status | Detail |
|:---|:---|:---|
| Auth required on protected endpoints | ✅ | Default `IsAuthenticated` permission class. |
| Health endpoint open | ✅ | Explicitly `@permission_classes([AllowAny])`. |
| History scoped to user | ✅ | `Message.objects.filter(firebase_uid=uid)`. |
| History detail scoped | ✅ | `Message.objects.get(id=..., firebase_uid=uid)`. |
| No raw media stored | ✅ | Only derived text/metadata stored in `Message` model. |
| Upload size checked | ✅ | `video_file.size > max_bytes` check in `analyze_video`. |
| Structured errors | ✅ | All error responses use `{"error": "..."}` format. |

## 4. Mobile Security / Privacy Audit

### 4.1 Secrets (`secrets.dart`, `app_config.dart`)

| Check | Status | Detail |
|:---|:---|:---|
| Picovoice key | ✅ | Via `--dart-define=PICOVOICE_ACCESS_KEY`. Empty default disables gracefully. |
| API_BASE_URL | ✅ | Via `--dart-define=API_BASE_URL`. Dev defaults to `http://10.0.2.2:8000`. Prod defaults to `https://api.wayfinder-ai.com`. |
| WS_BASE_URL | ✅ | Via `--dart-define=WS_BASE_URL`. Same pattern. |
| No hardcoded secrets | ✅ | All sensitive values use `String.fromEnvironment()`. |

### 4.2 Auth Token Handling (`api_client.dart`)

| Check | Status | Detail |
|:---|:---|:---|
| Token sent as Bearer header | ✅ | `request.headers['Authorization'] = 'Bearer $token'` |
| Token not logged | ✅ | Logger only prints endpoint and mode, never the token value. |
| Auth failure typed | ✅ | `ApiException.auth()` with user-friendly message. |

### 4.3 Local Storage

| Check | Status | Detail |
|:---|:---|:---|
| Raw video not stored | ✅ | Video captured → sent to backend → discarded. |
| Raw audio not stored | ✅ | Voice recorded → converted to text → discarded. |
| Offline cache | ✅ | `OfflineCacheService` caches only text responses, not raw media. |

### 4.4 Android Permissions

| Permission | Justified | Note |
|:---|:---|:---|
| CAMERA | ✅ | Core feature: scene analysis. |
| RECORD_AUDIO | ✅ | Core feature: voice commands and STT. |
| INTERNET | ✅ | Backend communication. |
| ACCESS_NETWORK_STATE | ✅ | Connectivity detection. |
| VIBRATE | ✅ | Haptic feedback for threats. |
| READ_EXTERNAL_STORAGE | ⚠️ | Present but may not be needed on API 29+. Mitigated by `maxSdkVersion=28` on WRITE. |
| WRITE_EXTERNAL_STORAGE | ✅ | `maxSdkVersion="28"` — only for legacy devices. |

### 4.5 iOS Permissions

| Permission | Present | Description OK |
|:---|:---|:---|
| NSCameraUsageDescription | ✅ | Clear, accurate. |
| NSMicrophoneUsageDescription | ✅ | Clear, accurate. |
| NSSpeechRecognitionUsageDescription | ✅ | Clear, accurate. |
| NSLocalNetworkUsageDescription | ✅ | Justified for dev testing. |
| NSPhotoLibraryUsageDescription | ✅ | Justified for image upload. |

## 5. Data Retention Summary

| Data Type | Stored? | Where | Duration |
|:---|:---|:---|:---|
| Raw video frames | ❌ | Not stored | Discarded after inference |
| Raw audio | ❌ | Not stored | Discarded after STT |
| Question text | ✅ | Backend DB (`Message.question_text`) | Until user deletion |
| AI response text | ✅ | Backend DB (`Message.ai_response`) | Until user deletion |
| Confidence/metadata | ✅ | Backend DB | Until user deletion |
| Firebase UID | ✅ | Backend DB | Until user deletion |
| Firebase ID token | ❌ | Not stored | In-memory only |

## 6. .gitignore Audit

| File | Ignored | Status |
|:---|:---|:---|
| `.env` | ✅ | Root + backend |
| `google-services.json` | ✅ | Root + mobile |
| `GoogleService-Info.plist` | ✅ | Root + mobile |
| `firebase-credentials*.json` | ✅ | Root |
| `serviceAccount*.json` | ✅ | Root |
| `*.jks` / `*.keystore` | ✅ | Root |
| `key.properties` | ✅ | Root |
| `.env.example` | ✅ NOT ignored | Tracked correctly |
| `google-services.example.json` | ✅ NOT ignored | Tracked correctly |
| `key.properties.example` | ✅ NOT ignored | Tracked correctly |

## 7. Privacy Policy / Terms Audit

| Requirement | Covered | File |
|:---|:---|:---|
| "Not a safety guarantee" | ✅ | Terms §1, §2, Store Listing |
| "Not a replacement for cane/guide dog" | ✅ | Terms §2, Store Listing |
| Camera/mic purpose disclosed | ✅ | Privacy §1 |
| Raw media not stored | ✅ | Privacy §3 |
| Text/metadata may be stored | ✅ | Privacy §3 |
| Deletion request path | ✅ | Privacy §3 (contact email placeholder) |
| Firebase Auth disclosed | ✅ | Privacy §4 |
| Picovoice offline disclosed | ✅ | Privacy §4 |
| Contact email placeholder | ⚠️ | `[CONTACT EMAIL PLACEHOLDER]` — needs real email before release |

## 8. Dependency Status
Backend `pip check` and `pip list --outdated` could not be run due to terminal lock. This should be verified manually:
```bash
cd backend && source .venv/bin/activate && pip check && pip list --outdated
```

## 9. Files Changed

| File | Change | Reason |
|:---|:---|:---|
| `backend/api/authentication.py` | Removed hardcoded Firebase credential filename | **CRITICAL**: Prevented leaking service account key ID in source |
| `backend/api/views.py` | Removed `model_path` and `memory_entries` from health endpoint | **MEDIUM**: Prevented information disclosure |
| `docs/SECURITY_PRIVACY_AUDIT_REPORT.md` | NEW | This report |

## 10. Remaining Issues

| Severity | Issue | Action |
|:---|:---|:---|
| **LOW** | `[CONTACT EMAIL PLACEHOLDER]` in privacy/terms docs | Owner must fill before store submission |
| **LOW** | `READ_EXTERNAL_STORAGE` permission may be unnecessary on API 29+ | Consider removing in future cleanup |
| **INFO** | Backend dependency health not verified | Run `pip check` manually |
| **INFO** | Real-device privacy behavior not tested | Deferred: Step 5 was skipped |

## 11. Final Status

| Question | Answer |
|:---|:---|
| Are secrets protected? | **YES** |
| Is dev auth safe? | **YES** — guarded by `DEBUG=True && ALLOW_DEV_AUTH=True` |
| Is raw media avoided by default? | **YES** — only derived text stored |
| Is backend protected by throttling? | **YES** — 20/min anon, 60/min user |
| Is production config safe? | **YES** — HTTPS, HSTS, secure cookies all enabled when `DEBUG=False` |
| Are privacy docs aligned with implementation? | **YES** |
| Is it safe to proceed to Step 7? | **YES** |
