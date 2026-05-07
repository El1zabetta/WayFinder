# WayFinder 2.0
> Powered by **RynnBrain 2B** — Egocentric AI Navigation Assistant

## Architecture

```
wayfinder2/
├── backend/                    ← Django 5 + Channels
│   ├── wayfinder/              ← Project config
│   │   ├── settings.py         ← RynnBrain model config
│   │   ├── urls.py             ← URL routing
│   │   └── asgi.py             ← HTTP + WebSocket
│   ├── api/
│   │   ├── rynnbrain_engine.py ← RynnBrain-2B inference (Nav/CoP/Plan/Base)
│   │   ├── video_processor.py  ← Frame extraction pipeline (2 FPS, PyAV)
│   │   ├── views.py            ← REST endpoints
│   │   ├── consumers.py        ← WebSocket real-time streaming
│   │   └── urls.py             ← API URL routing
│   ├── manage.py
│   └── requirements.txt
└── mobile/                     ← Flutter 3.22+
    └── lib/
        ├── main.dart            ← App entry, Provider setup
        ├── core/
        │   ├── app_theme.dart   ← Dark glassmorphism theme
        │   └── navigation_service.dart
        ├── services/
        │   ├── api_client.dart          ← Django API client
        │   ├── spatial_audio_service.dart ← 3D TTS panning
        │   └── voice_command_service.dart ← Voice intent parsing
        ├── providers/
        │   ├── navigation_provider.dart ← Nav state (Provider)
        │   └── safety_provider.dart     ← Safety/CoP state
        ├── screens/
        │   ├── home_screen.dart   ← Voice-first dashboard
        │   ├── camera_screen.dart ← Live egocentric capture
        │   ├── search_screen.dart ← RynnBrain-Plan object search
        │   └── settings_screen.dart
        └── widgets/
            ├── glass_card.dart    ← Glassmorphism card
            ├── audio_compass.dart ← 3D audio direction visual
            ├── threat_overlay.dart ← Camera threat bboxes
            └── pulse_button.dart  ← Animated voice button
```

## API Endpoints

| Method | URL | Mode | Description |
|--------|-----|------|-------------|
| POST | `/api/v2/analyze/video/` | Nav/CoP/Plan/Base | Analyze video clip |
| POST | `/api/v2/analyze/image/` | Any | Analyze single frame |
| POST | `/api/v2/navigate/` | Nav | Get next nav action |
| POST | `/api/v2/threats/` | CoP | Detect hazards + trajectories |
| POST | `/api/v2/search/` | Plan | Find object in scene |
| GET | `/api/v2/health/` | — | System health check |
| WS | `ws://host/ws/navigate/` | Any | Real-time frame streaming |

## RynnBrain Modes

| Mode | Model | Task |
|------|-------|------|
| `nav` | RynnBrain-Nav | Vision-language navigation, obstacle avoidance |
| `cop` | RynnBrain-CoP | Chain-of-Point threat detection, trajectory prediction |
| `plan` | RynnBrain-Plan | Object search, affordance grounding, task planning |
| `base` | RynnBrain-2B | General egocentric scene understanding |

## Starting the Backend

```bash
# 1. Create a virtual environment
python -m venv venv
venv\Scripts\activate        # Windows
source venv/bin/activate     # Linux/Mac

# 2. Install dependencies
cd wayfinder2/backend
pip install -r requirements.txt

# 3. Set the model path (or leave default HuggingFace Hub path)
export RYNNBRAIN_MODEL_PATH=Alibaba-DAMO-Academy/RynnBrain-2B   # or local path

# 4. Start the Daphne ASGI server
daphne -b 0.0.0.0 -p 8000 wayfinder.asgi:application

# Or via Django dev server (HTTP only)
python manage.py runserver 0.0.0.0:8000
```

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `RYNNBRAIN_MODEL_PATH` | `Alibaba-DAMO-Academy/RynnBrain-2B` | Path to the model |
| `DJANGO_SECRET_KEY` | dev key | Django secret |
| `DEBUG` | `True` | Debug mode |

## Starting the Flutter App

```bash
cd wayfinder2/mobile

# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build APK
flutter build apk --release
```

> **Tip:** For Android emulator, the backend URL is `http://10.0.2.2:8000/api/v2`  
> For a real device, it is the IP of your computer on the local network.

## System Requirements

- **GPU**: NVIDIA with CUDA 12+ support (16GB+ VRAM recommended for RynnBrain-2B)
- **RAM**: 16GB+
- **CPU**: Runs in mock-mode without GPU (for development)
- **Python**: 3.11+
- **Flutter**: 3.22+

## Spatiotemporal Grounding

RynnBrain-2B uses normalized coordinates **[0–1000]** for all spatial outputs:

```
<object> x1,y1,x2,y2 </object>   → Object bounding box
<area> x1,y1,...,xn,yn </area>   → Zone polygon
<trajectory> x1,y1,...,xn,yn </trajectory> → Movement trajectory
<frame N> → Binding to video frame
```

WayFinder transforms these coordinates → **azimuth/elevation** → **3D audio panning**.
