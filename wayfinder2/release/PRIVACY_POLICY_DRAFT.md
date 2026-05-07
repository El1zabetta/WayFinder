# WayFinder Privacy Policy

**Last Updated:** [DATE]

This Privacy Policy describes how WayFinder ("we", "our", or "us") collects, uses, and protects your information when you use the WayFinder mobile application ("the App").

## 1. App Purpose

WayFinder is an AI-powered assistive application designed to help blind and visually impaired users understand their surroundings through camera-based scene analysis and voice interaction. **WayFinder is assistive support only. It does not guarantee safety, replace mobility tools (such as a white cane or guide dog), human assistance, professional mobility training, or emergency services.**

## 2. Information We Collect

### 2.1 Camera and Video Data
We require camera access to capture video frames of your surroundings. These frames are temporarily sent to our backend servers for AI-based scene analysis to provide navigation guidance and obstacle detection. **Raw camera frames and video are processed in real time and are NOT permanently stored on our servers.** Only derived text descriptions and metadata (e.g., "chair ahead, slightly left") are retained.

### 2.2 Microphone and Voice Data
We require microphone access to:
- Listen for the "WayFinder" wake word, which is processed entirely offline on your device using Picovoice technology. No audio is sent to Picovoice servers.
- Record voice questions when you explicitly activate the assistant. Voice recordings are converted to text on-device via speech recognition and the resulting text may be sent to our servers. **Raw audio recordings are not stored on our servers.**

### 2.3 Speech Recognition
We use on-device speech recognition to convert your spoken questions to text. The text of your question is sent to our backend for AI processing.

### 2.4 Authentication Data
If you sign in via Google (Firebase Authentication), we collect:
- Email address
- Display name
- Firebase user identifier (UID)

This information is used to securely associate your interaction history with your account.

### 2.5 Interaction History
When you use Ask or Analyze features, the following derived data is stored on our servers:
- Your question text (for Ask mode)
- AI-generated response text
- Confidence score
- Interaction type (ask/analyze)
- Inference duration
- Session identifier
- Timestamp

## 3. What We Do NOT Store

By default, WayFinder does **not** store:
- Raw camera frames or video files
- Raw audio recordings
- Firebase authentication tokens
- Private encryption keys
- Location data (GPS)
- Contact information
- Browsing history

## 4. How We Use Your Information

- To provide real-time scene analysis and navigation guidance
- To detect obstacles and potential hazards in your path
- To answer specific questions about your surroundings
- To maintain an interaction history accessible only to you
- To improve service reliability and performance

## 5. Data Sharing

We do not sell your personal data. We use the following third-party services:
- **Firebase Authentication** (Google): For secure sign-in. Subject to [Google's Privacy Policy](https://policies.google.com/privacy).
- **Picovoice**: For offline wake word detection only. No audio data is sent to Picovoice servers.
- **Google Play Services**: For app distribution and sign-in.

## 6. Data Security

- All data in transit is encrypted using HTTPS/TLS.
- Authentication tokens are validated server-side and never logged.
- Backend access is protected by rate limiting and permission controls.
- User interaction history is scoped to individual accounts — users cannot access other users' data.

## 7. Data Retention and Deletion

- Interaction history is retained until you request deletion.
- You can request deletion of your account and all associated data by contacting us at [CONTACT EMAIL].
- Upon receiving a valid deletion request, we will remove all stored interaction data within 30 days.

## 8. Children's Privacy

WayFinder is not directed at children under 13. We do not knowingly collect personal information from children under 13. If you believe a child under 13 has provided us with personal data, please contact us at [CONTACT EMAIL].

## 9. Changes to This Policy

We may update this Privacy Policy from time to time. We will notify users of significant changes through the App or via email.

## 10. Contact Us

If you have questions about this Privacy Policy or wish to request data deletion, please contact us at:

**[CONTACT EMAIL]**
