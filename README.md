# 🧭 WayFinder AI: The Ultimate Vision Assistant

WayFinder is a cutting-edge, AI-powered navigation and safety platform designed to empower visually impaired individuals with unparalleled independence. By combining real-time Computer Vision, 3D Spatial Audio, and advanced GPS routing, WayFinder acts as a "Virtual Guide" that doesn't just show the way, but actively protects the user.

---

## 🌟 Key Features

### 🧠 1. Virtual Guide (AI Vision)
Using **Gemini 1.5 Flash**, WayFinder analyzes the camera feed in real-time to detect hazards:
*   **Safety Critical Alerts:** Immediate warning for open manholes, moving vehicles, and red traffic lights.
*   **Intelligent Pathfinding:** Recognizes crowds and flow of people to suggest the safest crossing windows.
*   **Scene Description:** "What do I see?" mode provides a rich, contextual description of the surroundings.

### 🎧 2. 3D Spatial Navigation
*   **Directional Audio:** Navigation instructions are panned to the left or right ear based on the user's orientation (using the compass). If the turn is right, the voice comes from the right.
*   **Haptic Feedback:** Professional vibration patterns for different events (turning, obstacles, arrival).

### 🔍 3. Intelligent Object Search
*   High-precision mode to find specific objects like "a free seat", "the door", or "a cup" using continuous visual feedback and directional cues.

### 🔐 4. Voice-First Onboarding & Auth
*   **Complete Voice Onboarding:** The app guides new users through setup, language selection, and features entirely via voice.
*   **Seamless Google Login:** Securely sync history and settings using native Google Sign-In.

---

## 🛠 Tech Stack

### Mobile (Flutter)
- **State Management:** Provider / State UI
- **AI Integration:** Google Generative AI (Gemini)
- **Wake Word:** Picovoice Porcupine ("WayFinder")
- **Audio:** AudioPlayers (3D Panning), Record, Flutter TTS
- **Sensors:** Geolocator (GPS), Flutter Compass, SensorsPlus

### Backend (Django)
- **API:** Django REST Framework
- **Auth:** Knox Token Auth + Google OAuth 2.0
- **Database:** PostgreSQL / SQLite
- **Security:** Fully protected endpoints with usage limiting

---

## 🚀 Getting Started

### 1. Backend Setup
1. Clone the repository.
2. Create a virtual environment: `python -m venv venv`.
3. Install dependencies: `pip install -r requirements.txt`.
4. Setup `.env` file (see `.env.example`).
5. Run migrations: `python manage.py migrate`.
6. Start server: `python manage.py runserver`.

### 2. Mobile Setup (WayFinder)
1. Navigate to `WayFinder/`.
2. Install Flutter dependencies: `flutter pub get`.
3. **Important:** Create `lib/secrets.dart` from `lib/secrets.dart.example` and add your API keys.
4. Add your `google-services.json` to `android/app/`.
5. Run the app: `flutter run`.

---

## 🛡 Security & Privacy
WayFinder is built with privacy in mind. No images are stored on our servers longer than necessary for processing. All communications are encrypted over HTTPS.

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

---
*Created with ❤️ by Erbol Takhirov*
