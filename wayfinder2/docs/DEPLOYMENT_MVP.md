# WayFinder Backend MVP Deployment Guide

## Production Environment Variables
In production, your `.env` must strictly define the following. Do **not** use `ALLOW_DEV_AUTH=True`.

```env
# Security
DJANGO_SECRET_KEY=your_very_long_secure_random_string
DEBUG=False
ALLOWED_HOSTS=api.yourdomain.com,127.0.0.1
CORS_ALLOWED_ORIGINS=https://app.yourdomain.com

# Database (PostgreSQL recommended for production)
DB_ENGINE=postgresql
DB_NAME=wayfinder
DB_USER=wayfinder_user
DB_PASSWORD=your_secure_password
DB_HOST=db
DB_PORT=5432

# Redis (for WebSocket channels and Celery)
REDIS_URL=redis://redis:6379/0

# Firebase
GOOGLE_APPLICATION_CREDENTIALS=/path/to/firebase-service-account.json

# AI Model settings
RYNNBRAIN_MODEL_PATH=Qwen/Qwen3-VL-2B-Instruct
MAX_UPLOAD_SIZE_MB=10
```

## Docker Compose Setup
We recommend using Docker Compose on a GPU-enabled instance (e.g., AWS EC2 g4dn, RunPod).

1. Ensure NVIDIA Drivers and NVIDIA Container Toolkit are installed.
2. Build the containers:
   ```bash
   docker compose build
   ```
3. Run database migrations:
   ```bash
   docker compose run --rm web python manage.py migrate
   ```
4. Collect static files:
   ```bash
   docker compose run --rm web python manage.py collectstatic --no-input
   ```
5. Start the services:
   ```bash
   docker compose up -d
   ```

## Nginx & SSL (Certbot)
Configure Nginx to reverse proxy to the web container running Daphne/Gunicorn on port 8000.

1. Ensure Nginx forwards WebSocket upgrade headers:
```nginx
location /ws/ {
    proxy_pass http://localhost:8000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
}
```

2. Use Certbot to generate a free SSL certificate:
```bash
sudo certbot --nginx -d api.yourdomain.com
```

## Health Checks
To verify the production deployment, hit the health endpoint:
```bash
curl https://api.yourdomain.com/api/v2/health/
```
You should see `"engine_mode": "gpu"` if the NVIDIA container toolkit successfully passed the GPU to the Docker container.
