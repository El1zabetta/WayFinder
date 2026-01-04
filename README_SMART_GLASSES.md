# Vision AI: Smart Glasses Expansion Plan ("Vision Glass")

## 🕶️ Concept
Move the "Vision AI" experience from the smartphone screen to a wearable form factor. This eliminates the need to hold the phone, providing a true "hands-free" and "eyes-free" assistance experience.

## 🛠️ Hardware Architecture
**Device**: A lightweight, wearable client.
**Processing**: Validated hybrid approach:
- **On-Device**: Audio streaming, Image capture, Wake-word detection (lightweight).
- **Server (Phone/Cloud)**: Heavy lifting (YOLOv8, LLM, TTS, Logic).

### Proposed Bill of Materials (BoM) - DIY Prototype
1.  **Compute**: Raspberry Pi Zero 2 W (Small, Wi-Fi capable, runs Linux).
2.  **Vision**: Raspberry Pi Camera Module 2 (or NoIR if night vision needed).
3.  **Audio In**: I2S MEMS Microphone (e.g., INMP441).
4.  **Audio Out**: Bone Conduction Transducers (creates audio inside the head without blocking ears) + Amplifier (MAX98357A).
5.  **Power**: 3.7V LiPo Battery (1000mAh+) + TP4056 Charger + Boost Converter (5V).
6.  **Frame**: 3D Printed custom mount for existing glasses or full frame.

## 💻 Software Architecture

### 1. The Wearable Client (Python/C++)
Detailed workflow for the device:
- **State**: Idle -> Listening (Wake Word) -> Recording -> Transmitting -> Playing Response.
- **Wake Word**: Run `Porcupine` or a lightweight `TFLite` model on the Pi Zero to detect "Hey Vision".
- **Action**:
    - Trigger Camera capture.
    - Stream Audio/Image to the existing Django Backend (e.g., via WebSocket or HTTP POST).
    - Buffer and play received audio (TTS) response.

### 2. The Backyard Server (Existing Django)
Adapt the current `vision` app to handle streams:
- **New Endpoint**: `ws://connect/glasses/` (WebSockets).
- **Protocol**: 
    - Incoming: `{ type: "audio/image", payload: ... }`
    - Outgoing: `{ type: "audio", payload: <mp3_bytes> }`
- **Logic**: Reuse the `VisionAgent` and `AudioProcessor` classes.

## 📅 Execution Plan

### Phase 1: The "Tethered" Prototype
- **Goal**: Verify software stack without battery/size constraints.
- **Setup**: Pi Zero connected to a power bank, running a Python script interacting with the local PC Django server.
- **Milestone**: "Hey Vision", take a picture, receive description via speaker.

### Phase 2: The Wearable Form
- **Goal**: Minimize footprint.
- **Design**: Design 3D casing for the Pi and Battery. Mount camera on the side (temple).
- **Power**: Optimize OS (headless Linux) for battery life (target: 2-3 hours active).

### Phase 3: "Always-On" Navigation
- **Goal**: Continuous object detection.
- **Logic**: Instead of wake-word, toggle "Nav Mode". The device sends images every 2-3 seconds.
- **Feedback**: Short audio cues ("Door", "Stairs", "Person") played instantly.

## ❓ FAQ for "Vision Glass"
**Q: Why not use existing smart glasses (Ray-Ban Meta)?**
A: Current consumer smart glasses restrict developer access to the real-time camera stream for custom processing. A DIY solution gives full control.

**Q: Will it work offline?**
A: If the Django server runs on your phone (e.g., via Termux or if we port the core logic to a standalone Android app), YES. Otherwise, it requires a hotspot connection to your PC/Cloud.

**Q: How heavy will it be?**
A: A Pi Zero W + Battery is barely noticeable if balanced correctly (e.g., battery on the back of the head strap).
