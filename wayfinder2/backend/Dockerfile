# ═══════════════════════════════════════════════════════════════════════════════
# WayFinder 2.0 — Production Dockerfile (CUDA + RynnBrain-2B)
# Base: NVIDIA CUDA 12.4 runtime on Ubuntu 22.04
# ═══════════════════════════════════════════════════════════════════════════════

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS base

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# ─── System dependencies ────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    ffmpeg \
    libsm6 \
    libxext6 \
    libgl1 \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3

# ─── Working directory ──────────────────────────────────────────────────────────
WORKDIR /app

# ─── Python dependencies ────────────────────────────────────────────────────────
COPY requirements.txt .

# Install PyTorch with CUDA support first (from PyTorch index)
# Then install remaining deps, skipping torch to avoid CPU override
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir torch>=2.7.0 --index-url https://download.pytorch.org/whl/cu124 && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir flash-attn>=2.6.3 --no-build-isolation 2>/dev/null || echo "Flash Attention not installed (optional)"

# ─── Application code ───────────────────────────────────────────────────────────
COPY . .

# ─── Collect static files ───────────────────────────────────────────────────────
RUN python manage.py collectstatic --noinput 2>/dev/null || true

# ─── Create directories ─────────────────────────────────────────────────────────
RUN mkdir -p /var/log/wayfinder

# ─── Non-root user (security) ───────────────────────────────────────────────────
RUN groupadd -r wayfinder && useradd -r -g wayfinder -d /app wayfinder && \
    chown -R wayfinder:wayfinder /app /var/log/wayfinder

USER wayfinder

# ─── Health check ────────────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD curl -f http://localhost:8000/api/v2/health/ || exit 1

EXPOSE 8000

# ─── Entry point: gunicorn with uvicorn workers (ASGI) ──────────────────────────
CMD ["gunicorn", "wayfinder.asgi:application", "-c", "gunicorn.conf.py"]
