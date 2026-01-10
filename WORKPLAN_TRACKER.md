# Project Workplan Tracker - Vision AI

## Phase 1: Foundation & Core Features (Completed)
- [x] **Project Scaffolding**: Setup Django, Telegram Bot structure.
- [x] **Basic Vision Integration**: Integrate BLIP/LLM for image description.
- [x] **Object Detection**: Implement YOLOv8 for real-time "Navigator Mode".
- [x] **Voice Interface**: Text-to-Speech (Edge-TTS) and Speech-to-Text (Whisper).
- [x] **Frontend Development**: create Telegram Mini App UI (HTML/JS/CSS).

## Phase 2: Refinement & Advanced Features (Current - Jan 2026)
- [x] **Hands-Free Activation**: "Hey Vision" wake word detection.
- [x] **Memory System**: Implement RAG-lite for remembering context.
- [ ] **Performance Optimization**: Reduce latency for Object Detection loop (Target: <2s).
- [ ] **Robust Error Handling**: Better retries for network/API failures.
- [ ] **Cross-Platform Testing**: Verify consistent behavior on iOS vs Android Telegram.

## Phase 3: Hardware Expansion (Future - "Vision Glass")
- [ ] **Hardware Selection**: Finalize components (Raspberry Pi/ESP32, Camera, Battery).
- [ ] **Prototype Assembly**: 3D print frame or mount.
- [ ] **Firmware Development**: Streaming client for the hardware.
- [ ] **Server Adaptation**: Optimize endpoints for continuous low-latency stream.
