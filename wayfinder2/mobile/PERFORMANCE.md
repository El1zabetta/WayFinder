# ⚡ WayFinder 3.0 Performance Guide

This guide details how to monitor and optimize the performance of the WayFinder AI loop.

## 📊 Latency Metrics
The system tracks four key timestamps for every frame:
1. `received_at`: Frame reached the server.
2. `inference_started_at`: Frame entered the GPU.
3. `inference_finished_at`: AI finished processing.
4. `response_sent_at`: Result sent back to client.

### How to View
- **Client Logs**: Look for `StreamAnalysis.latencyMs` in Flutter logs.
- **Backend Logs**: Check Celery worker output for `total_latency_ms` and `queue_wait_ms`.

## 🛠 Optimization Parameters
If latency exceeds **2.0 seconds**, the app enters fallback mode. Adjust these in `.env`:

| Parameter | Recommended | Effect |
|-----------|-------------|--------|
| `GUNICORN_WORKERS` | 2-4 | Parallel request handling |
| `MAX_FRAME_SIZE` | 640 | Lowering reduces bandwidth/VRAM |
| `MODEL_PRECISION` | float16 | Use `int8` for slower GPUs |
| `currentFps` (App) | 1.0 - 10.0 | Adaptive based on network |

## 🧪 Testing Procedures
### 1. WebSocket Throughput
Use `wscat` or custom scripts to send a burst of frames and measure response density.

### 2. GPU Utilization
Run `nvidia-smi -l 1` on the server during an active session. Target < 80% utilization for stability.

### 3. Mock/Fallback Mode
If the server is down, the app automatically:
- Speaks safety hints from `OfflineCacheService`.
- Shows "Offline" status in the UI.
- Uses the last cached analysis if available.

## 📉 Bottleneck Checklist
- **Network**: High `total_latency` but low `inference_ms` -> Check 4G/5G signal or Nginx.
- **Queue**: High `queue_wait_ms` -> Add more Celery workers or a faster GPU.
- **Inference**: High `inference_ms` -> Use a smaller model or lower precision.
