# WayFinder Data Flow Audit & Database Persistence

This document maps the complete data flow for WayFinder 2.0 MVP, ensuring robust user data isolation and safe handling of sensitive inputs (video/audio) for blind and visually impaired users.

## 1. Data Flow Map

- **Authentication Flow:**
  `Flutter Google Sign-In` → `Firebase ID Token` → `Django Authentication (Bearer token)` → `request.user.uid`
  
- **Ask WayFinder Flow:**
  `User taps Ask (or says Wake Word)` → `STT captures question` → `POST /api/v2/ask/` → `QA Engine (with SceneMemory)` → `Response Generated` → `Saved to Message Model (interaction_type='ask')` → `Flutter Receives Answer` → `TTS Speaks` → `History Displays Question & Answer`.

- **Analyze Surroundings Flow:**
  `User taps Analyze` → `Camera Frame/Video captured` → `POST /api/v2/analyze/video/` → `Scene Engine & Threat Engine` → `Guidance Generated` → `Saved to Message Model (interaction_type='analyze')` → `Flutter Receives Guidance` → `TTS Speaks`.

- **History Flow:**
  `Flutter requests GET /api/v2/history/` → `Django queries Message model (filtered by request.user.uid)` → `InteractionListSerializer (maps to legacy field names)` → `Flutter UI renders`.

- **Error Flow:**
  `Network Error / API Failure` → `Backend returns JSON {"error": "..."}` → `ApiClient throws ApiException` → `Provider transitions to Error state` → `TTS speaks localized friendly error message`.

## 2. API Contract Table

| Endpoint | Method | Request | Response | DB Models Touched | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/api/v2/health/` | GET | None | `{"status": "ok", ...}` | None | ✅ Verified |
| `/api/v2/ask/` | POST | `question`, `video`/`image` | `{"answer": "...", "confidence": 0.9, ...}` | `UserSession`, `Message` | ✅ Verified |
| `/api/v2/analyze/video/` | POST | `video` | `{"raw_text": "...", "navigation_action": "...", ...}` | `UserSession`, `Message` | ✅ Verified |
| `/api/v2/history/` | GET | `limit=N` | `{"count": N, "results": [{"question": "...", "answer": "...", "created_at": "..."}]}` | `Message` (Read) | ✅ Verified |

## 3. Database Persistence Map

| User Action | Saved Model | Fields Saved | User/Session Scoped | Privacy / Safety Notes |
| :--- | :--- | :--- | :--- | :--- |
| Ask WayFinder | `Message` | `question_text`, `ai_response`, `timestamp`, `interaction_type="ask"` | Yes (`firebase_uid`, `session_id`) | Raw audio and video files are **NOT** saved. |
| Analyze Surroundings | `Message` | `question_text="Analyze Surroundings"`, `ai_response="[Guidance] (Alert Level: [Level])"`, `interaction_type="analyze"` | Yes (`firebase_uid`, `session_id`) | Raw camera frames are **NOT** saved to the DB by default. |

## 4. User Scoping and Privacy
- **User Isolation:** All records (`Message`, `UserSession`) contain a `firebase_uid`. The backend endpoints (`/ask/`, `/analyze/`, `/history/`) strictly enforce database filters using `request.user.uid`.
- **User A vs User B:** It is cryptographically impossible for User A to fetch User B's history because the Firebase ID token signature strictly binds the `uid` to the request lifecycle.
- **Privacy Policy:** Raw video, audio, and frames uploaded to `/ask/` and `/analyze/` are processed in-memory (or temporarily on disk) and immediately discarded. The `frame_snapshot_url` is left empty by default.

## 5. Local Database Inspection

To inspect the SQLite database locally during development:

```bash
cd backend
sqlite3 db.sqlite3
```

Useful SQLite commands:
```sql
.tables
.schema api_message
SELECT id, interaction_type, question_text, ai_response, timestamp FROM api_message ORDER BY timestamp DESC LIMIT 5;
```

To inspect using Django Shell:
```bash
python manage.py shell
```

```python
from api.models import Message, UserSession
# View newest 5 messages
Message.objects.order_by('-timestamp')[:5]
# View newest active session
UserSession.objects.filter(is_active=True).order_by('-started_at').first()
```

## 6. cURL Testing Examples

Check health:
```bash
curl http://localhost:8000/api/v2/health/
```

Simulate an Ask interaction (Requires valid Firebase ID Token as dev-token):
```bash
curl -X POST http://localhost:8000/api/v2/ask/ \
  -H "Authorization: Bearer <valid-firebase-token>" \
  -H "Content-Type: application/json" \
  -d '{"question":"What is in front of me?"}'
```
