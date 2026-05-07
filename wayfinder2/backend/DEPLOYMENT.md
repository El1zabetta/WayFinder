# 🚀 WayFinder 3.0 Deployment Guide

This document explains how to deploy the WayFinder backend and AI engine to a production server with GPU support.

## 📋 Prerequisites
- Linux Server (Ubuntu 22.04+ recommended)
- **NVIDIA GPU** with 8GB+ VRAM
- **NVIDIA Container Toolkit** installed
- Docker & Docker Compose
- Domain name with DNS pointing to your server
- Firebase Service Account JSON file

---

## 🛠 1. Server Preparation

### Install Docker & NVIDIA Toolkit
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install NVIDIA Container Toolkit (for GPU support in Docker)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

---

## 📦 2. Application Setup

### Clone and Configure
```bash
git clone https://github.com/your-org/wayfinder.git
cd wayfinder/wayfinder2/backend

# Configure Environment
cp .env.production.example .env
nano .env # Fill in SECRET_KEY, DB passwords, and Domain
```

### Add Credentials
Place your Firebase Service Account JSON file in the backend directory and name it `firebase-credentials.json`.

---

## 🚀 3. Launching

### Start Services
```bash
docker compose up -d --build
```

### Initial Database Setup
```bash
docker compose exec web python manage.py migrate
docker compose exec web python manage.py collectstatic --noinput
```

### Health Check
```bash
# Check if API is alive
curl -f http://localhost:8000/api/v2/health/

# Verify WebSocket
# Use a tool like 'wscat'
wscat -c ws://localhost:8000/ws/navigation/
```

---

## 📈 4. Maintenance

### View Logs
```bash
docker compose logs -f web    # Django/ASGI logs
docker compose logs -f worker # Celery/AI inference logs
docker compose logs -f nginx  # Access/Error logs
```

### Update Project
```bash
git pull
docker compose up -d --build
docker compose exec web python manage.py migrate
```

### Troubleshooting
- **GPU not detected**: Run `nvidia-smi` on host. Ensure `deploy.resources.reservations` is in `docker-compose.yml`.
- **WebSocket Timeout**: Check Nginx `proxy_read_timeout` and `WS_TIMEOUT_SECONDS` in `.env`.
- **Out of Memory (OOM)**: Reduce `GUNICORN_WORKERS` or use `MODEL_PRECISION=int8`.

---

## 🔒 5. SSL / HTTPS
The included Nginx config expects Let's Encrypt certificates at `/etc/letsencrypt/live/your-domain.com/`.
Use **Certbot** on the host or a sidecar container to generate them.

```bash
sudo apt install certbot
sudo certbot certonly --standalone -d api.wayfinder-ai.com
```
