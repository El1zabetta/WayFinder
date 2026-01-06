# WayFinder

**AI-powered navigation and vision assistant for mobile devices**

WayFinder is a real-time AI assistant that combines computer vision, voice interaction, and intelligent navigation to help users understand their surroundings and navigate efficiently.

## Features

- 🎤 **Voice-Activated Assistant** - Wake word detection ("WayFinder") for hands-free interaction
- 👁️ **Real-Time Vision Analysis** - Object detection and scene understanding using YOLO and BLIP
- 🗺️ **Smart Navigation** - Turn-by-turn directions with voice guidance
- 🧠 **Context-Aware AI** - Personalized responses based on user profile and conversation history
- 🌐 **Multilingual Support** - English, Russian, and Kyrgyz languages
- 🎨 **Modern UI** - Sleek cyberpunk-inspired interface with dark mode

## Tech Stack

### Backend (Django)
- **Framework**: Django 6.0
- **AI Models**: 
  - Whisper (Speech-to-Text)
  - BLIP (Image Captioning)
  - YOLO (Object Detection)
  - DeepSeek/GPT (Language Model)
- **TTS**: Edge TTS / Kani TTS
- **Database**: PostgreSQL / SQLite

### Mobile (Flutter)
- **Framework**: Flutter 3.x
- **Wake Word**: Porcupine (Picovoice)
- **Navigation**: Geolocator, OpenRouteService
- **UI**: Material Design 3

## Installation

### Prerequisites
- Python 3.10+
- Flutter 3.0+
- PostgreSQL (optional, SQLite works for dev)

### Backend Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/wayfinder.git
cd wayfinder
```

2. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Configure environment variables:
```bash
cp .env.example .env
# Edit .env and add your API keys
```

5. Run migrations:
```bash
python manage.py migrate
```

6. Start the server:
```bash
python manage.py runserver
```

### Mobile Setup

1. Navigate to mobile directory:
```bash
cd vision_mobile
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Create secrets file:
```bash
# Create lib/secrets.dart with your API keys
# See lib/secrets.dart.example for template
```

4. Run the app:
```bash
flutter run
```

## Configuration

### Required API Keys

- **OPENAI_API_KEY**: For AI language model (DeepSeek or OpenAI)
- **Picovoice Access Key**: For wake word detection (get free at picovoice.ai)
- **OpenRouteService API Key**: For navigation (optional)

Add these to:
- Backend: `.env` file
- Mobile: `vision_mobile/lib/secrets.dart`

### Wake Word Setup

The custom "WayFinder" wake word model is included in `vision_mobile/assets/words/`. To create your own:

1. Visit [Picovoice Console](https://console.picovoice.ai/)
2. Create a new keyword
3. Download the `.ppn` file for Android
4. Replace `way_finder_android.ppn` in assets

## Usage

### Voice Commands

After saying "WayFinder":
- "What's in front of me?" - Analyze current camera view
- "Where am I?" - Get current location
- "Navigate to [place]" - Start turn-by-turn navigation
- "What do you see?" - Describe the scene

### Manual Mode

Tap the microphone button to record your question without using the wake word.

## Project Structure

```
wayfinder/
├── core/                 # Django project settings
├── vision/              # Main Django app
│   ├── cag.py          # Context-Affect-Guidance system
│   ├── services.py     # AI service layer
│   ├── tts_engine.py   # Text-to-speech
│   └── views.py        # API endpoints
├── vision_mobile/       # Flutter mobile app
│   ├── lib/
│   │   ├── services/   # API clients, wake word
│   │   ├── screens/    # UI screens
│   │   └── theme/      # App styling
│   └── assets/         # Wake word models
└── requirements.txt
```

## Development

### Running with ngrok (for mobile testing)

```bash
# Terminal 1: Django server
python manage.py runserver

# Terminal 2: ngrok tunnel
ngrok http 8000

# Update WEBAPP_URL in .env with ngrok URL
```

### Hot Reload

- **Backend**: Django auto-reloads on file changes
- **Mobile**: Press `r` in Flutter terminal for hot reload, `R` for hot restart

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
