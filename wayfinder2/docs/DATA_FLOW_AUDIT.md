# WayFinder 2.0 Backend Data Flow Audit

## 1. Authentication Flow
- **Mechanism:** Firebase ID tokens via `Authorization: Bearer <token>`.
- **Decoding:** The `FirebaseAuthentication` class decodes the JWT and maps claims.
- **User Object:** DRF's `request.user` is populated with a `FirebaseUser` instance containing `uid`, `pk`, `id`, `email`, `is_authenticated=True`.
- **Dev Auth:** Active *only* if `DEBUG=True` and `ALLOW_DEV_AUTH=True`. Allows a hardcoded `dev-token` to bypass Firebase verification and attach a mock dev user. This ensures offline and rapid UI iteration is possible without internet or Firebase configuration, while preserving all downstream scoping requirements.

## 2. Interaction Flows

### Ask Flow (`/api/v2/ask/`)
1. Receives an image and a question text.
2. Authenticates the user and extracts the `uid`.
3. Calls the `scene_engine` to get the latest scene context or parses the uploaded image.
4. Returns an AI-generated answer.
5. **Persistence:** Creates a `Message` model record tied to the active `UserSession`. The `interaction_type` is set to `"ask"`.

### Analyze Flow (`/api/v2/analyze/video/` and `/api/v2/analyze/image/`)
1. Receives a short video or image payload.
2. Authenticates the user and extracts the `uid`.
3. Processes frames using OpenCV and extracts objects.
4. **Scene Memory:** Extracted `SceneFacts` are stored in the short-term `scene_memory` ring buffer.
5. Generates derived navigation/scene guidance.
6. **Persistence:** Creates a `Message` model record tied to the active `UserSession`. The `interaction_type` is set to `"analyze"`. The raw video/image is **never** saved.

### History Flow (`/api/v2/history/`)
1. The user requests their interaction history.
2. The view queries the `Message` model, filtering strictly by `firebase_uid=request.user.uid`.
3. Data is returned in reverse chronological order (newest first).
4. The response matches the Flutter app's legacy schema (`question`, `answer`, `created_at` derived from `Message`).

## 3. Persistence Map & Relationships

### `UserSession`
- Groups interactions together logically. 
- Created automatically (`get_or_create_active_session`) on the first interaction.
- **Foreign Keys:** Scoped by `firebase_uid`.

### `Message`
- The core source of truth for all Q&A and analysis events.
- **Fields saved:** `question_text`, `ai_response`, `confidence`, `grounded`, `interaction_type`, `timestamp`.
- **Foreign Keys:** Scoped by `firebase_uid` and belongs to a `UserSession`.

### `AssistantInteraction` (Legacy)
- Currently preserved for backward migration compatibility, but the active system routes history requests to the `Message` table.

## 4. Privacy and Data Policy
- **Raw Media:** Raw images, videos, audio, and camera frame bytes are completely ephemeral. They reside in RAM during processing and are immediately garbage collected. They are **not** saved to the database.
- **Cross-User Leakage:** Enforced at the DRF level using strictly filtered QuerySets (`.filter(firebase_uid=request.user.uid)`). Tests comprehensively verify isolation.
- **Secrets:** Logging configurations enforce standard output. Firebase tokens and API keys are verified statelessly or parsed locally without database persistence.
