# WayFinder 2.0
> Powered by **RynnBrain 2B** — Egocentric AI Navigation Assistant

## Архитектура

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

## Запуск Backend

```bash
# 1. Создать виртуальное окружение
python -m venv venv
venv\Scripts\activate        # Windows
source venv/bin/activate     # Linux/Mac

# 2. Установить зависимости
cd wayfinder2/backend
pip install -r requirements.txt

# 3. Задать путь к модели (или оставить HuggingFace Hub путь)
set RYNNBRAIN_MODEL_PATH=Alibaba-DAMO-Academy/RynnBrain-2B   # или локальный путь

# 4. Запустить Daphne ASGI сервер
daphne -b 0.0.0.0 -p 8000 wayfinder.asgi:application

# Или через Django dev server (только HTTP)
python manage.py runserver 0.0.0.0:8000
```

### Переменные окружения

| Переменная | По умолчанию | Описание |
|---|---|---|
| `RYNNBRAIN_MODEL_PATH` | `Alibaba-DAMO-Academy/RynnBrain-2B` | Путь к модели |
| `DJANGO_SECRET_KEY` | dev key | Django secret |
| `DEBUG` | `True` | Debug mode |

## Запуск Flutter App

```bash
cd wayfinder2/mobile

# Установить зависимости
flutter pub get

# Запустить на устройстве/эмуляторе
flutter run

# Сборка APK
flutter build apk --release
```

> **Совет:** Для Android эмулятора backend URL = `http://10.0.2.2:8000/api/v2`  
> Для реального устройства = IP вашего компьютера в локальной сети

## Системные требования

- **GPU**: NVIDIA с поддержкой CUDA 12+ (рекомендуется 16GB+ VRAM для RynnBrain-2B)
- **RAM**: 16GB+
- **CPU**: Работает в mock-режиме без GPU (для разработки)
- **Python**: 3.11+
- **Flutter**: 3.22+

## Spatiotemporal Grounding

RynnBrain-2B использует нормализованные координаты **[0–1000]** для всех пространственных выходов:

```
<object> x1,y1,x2,y2 </object>   → Bounding box объекта
<area> x1,y1,...,xn,yn </area>   → Полигон зоны
<trajectory> x1,y1,...,xn,yn </trajectory> → Траектория движения
<frame N> → Привязка к кадру видео
```

WayFinder преобразует эти координаты → **azimuth/elevation** → **3D audio panning**.
