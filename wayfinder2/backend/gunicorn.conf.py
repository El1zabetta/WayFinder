"""
WayFinder 2.0 — Gunicorn Configuration
ASGI server with Uvicorn workers for HTTP + WebSocket support.
"""

import os
import multiprocessing

# ─── Server socket ──────────────────────────────────────────────────────────────
bind = os.environ.get("GUNICORN_BIND", "0.0.0.0:8000")

# ─── Workers ────────────────────────────────────────────────────────────────────
# Use uvicorn workers for ASGI (WebSocket support)
worker_class = "uvicorn.workers.UvicornWorker"

# 2 workers: RynnBrain-2B consumes significant GPU VRAM (~5-6 GB per worker)
# Increase only if your GPU has >24 GB VRAM
workers = int(os.environ.get("GUNICORN_WORKERS", "2"))

# ─── Timeouts ───────────────────────────────────────────────────────────────────
# RynnBrain inference can take 10-30s for video analysis
timeout = int(os.environ.get("GUNICORN_TIMEOUT", "120"))
graceful_timeout = 30
keepalive = 5

# ─── Logging ────────────────────────────────────────────────────────────────────
accesslog = os.environ.get("GUNICORN_ACCESS_LOG", "/var/log/wayfinder/access.log")
errorlog = os.environ.get("GUNICORN_ERROR_LOG", "/var/log/wayfinder/error.log")
loglevel = os.environ.get("GUNICORN_LOG_LEVEL", "info")

# ─── Process naming ────────────────────────────────────────────────────────────
proc_name = "wayfinder"

# ─── Security ───────────────────────────────────────────────────────────────────
# Limit request sizes (50 MB max for video uploads)
limit_request_body = 50 * 1024 * 1024
