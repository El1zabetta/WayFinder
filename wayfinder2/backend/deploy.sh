#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# WayFinder 2.0 — Production Deploy Script
# Target: Ubuntu 22.04 with NVIDIA GPU (Hetzner / RunPod)
# Usage:  chmod +x deploy.sh && sudo bash deploy.sh
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Colors ─────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[WayFinder]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ─── Check root ─────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "This script must be run as root (use sudo)"

# ─── Configuration ──────────────────────────────────────────────────────────────
APP_DIR="/opt/wayfinder"
REPO_URL="${REPO_URL:-}"
DOMAIN="${DOMAIN:-}"
EMAIL="${EMAIL:-}"

if [[ -z "$DOMAIN" ]]; then
    read -rp "Enter your domain name (e.g. api.wayfinder.kz): " DOMAIN
fi
if [[ -z "$EMAIL" ]]; then
    read -rp "Enter your email for SSL certificates: " EMAIL
fi

log "Starting WayFinder 2.0 deployment on $(hostname)"
log "Domain: $DOMAIN | Email: $EMAIL"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: System Update
# ═══════════════════════════════════════════════════════════════════════════════
log "Step 1/7: Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Install NVIDIA Drivers + Container Toolkit
# ═══════════════════════════════════════════════════════════════════════════════
log "Step 2/7: Setting up NVIDIA GPU drivers..."

if ! command -v nvidia-smi &> /dev/null; then
    log "Installing NVIDIA drivers..."
    apt-get install -y -qq ubuntu-drivers-common
    ubuntu-drivers autoinstall
    warn "NVIDIA drivers installed. A REBOOT may be required."
    warn "After reboot, run this script again to continue."
else
    log "NVIDIA drivers already installed: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
fi

# NVIDIA Container Toolkit
if ! command -v nvidia-ctk &> /dev/null; then
    log "Installing NVIDIA Container Toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
    apt-get update -qq
    apt-get install -y -qq nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker 2>/dev/null || true
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Install Docker + Docker Compose
# ═══════════════════════════════════════════════════════════════════════════════
log "Step 3/7: Installing Docker..."

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    systemctl start docker
else
    log "Docker already installed: $(docker --version)"
fi

# Ensure Docker Compose plugin is available
if ! docker compose version &> /dev/null; then
    apt-get install -y -qq docker-compose-plugin
fi

# Restart Docker to apply NVIDIA runtime
systemctl restart docker

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Clone / Update Application
# ═══════════════════════════════════════════════════════════════════════════════
log "Step 4/7: Setting up application directory..."

mkdir -p "$APP_DIR"

if [[ -n "$REPO_URL" ]]; then
    if [[ -d "$APP_DIR/.git" ]]; then
        log "Pulling latest changes..."
        cd "$APP_DIR" && git pull
    else
        log "Cloning repository..."
        git clone "$REPO_URL" "$APP_DIR"
    fi
else
    warn "No REPO_URL provided. Make sure your code is already at $APP_DIR"
    warn "You can copy files manually: scp -r ./wayfinder2/backend/* root@server:$APP_DIR/"
fi

BACKEND_DIR="$APP_DIR/wayfinder2/backend"
cd "$BACKEND_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: Configure Environment
# ═══════════════════════════════════════════════════════════════════════════════
log "Step 5/7: Configuring environment..."

if [[ ! -f "$BACKEND_DIR/.env" ]]; then
    cp "$BACKEND_DIR/.env.example" "$BACKEND_DIR/.env"

    # Generate secure random keys
    GENERATED_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))" 2>/dev/null || openssl rand -base64 50)
    GENERATED_DB_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))" 2>/dev/null || openssl rand -base64 24)

    # Replace placeholders in .env
    sed -i "s|CHANGE-ME-to-a-random-50-char-string|${GENERATED_SECRET}|g" "$BACKEND_DIR/.env"
    sed -i "s|CHANGE-ME-strong-db-password|${GENERATED_DB_PASS}|g" "$BACKEND_DIR/.env"
    sed -i "s|your-domain.com|${DOMAIN}|g" "$BACKEND_DIR/.env"
    sed -i "s|your-email@example.com|${EMAIL}|g" "$BACKEND_DIR/.env"

    log "Generated .env with secure random credentials"
    warn "Review $BACKEND_DIR/.env before proceeding!"
else
    log ".env already exists, skipping generation"
fi

# Replace domain in nginx.conf
log "Configuring nginx for domain: $DOMAIN"
sed -i "s|wayfinder-ai.com|${DOMAIN}|g" "$BACKEND_DIR/nginx/nginx.conf"
log "Nginx configured for $DOMAIN"

# Create log directory
mkdir -p /var/log/wayfinder
chmod 777 /var/log/wayfinder

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: SSL Certificates (Let's Encrypt)
# ═══════════════════════════════════════════════════════════════════════════════
log "Step 6/7: Setting up SSL certificates..."

apt-get install -y -qq certbot

if [[ ! -d "/etc/letsencrypt/live/wayfinder" ]]; then
    log "Obtaining SSL certificate for $DOMAIN..."

    # Create a temporary nginx for the ACME challenge
    mkdir -p /var/www/certbot

    # Stop anything on port 80
    systemctl stop nginx 2>/dev/null || true
    docker stop wayfinder-nginx 2>/dev/null || true

    certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --cert-name wayfinder \
        -d "$DOMAIN" \
        || err "Failed to obtain SSL certificate. Make sure $DOMAIN points to this server."

    log "SSL certificate obtained successfully"
else
    log "SSL certificate already exists, skipping"
fi

# Auto-renewal cron (certbot handles this, but ensure it's there)
systemctl enable certbot.timer 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: Build & Launch
# ═══════════════════════════════════════════════════════════════════════════════
log "Step 7/7: Building and starting containers..."

cd "$BACKEND_DIR"

# Build and start all services
docker compose up -d --build

# Wait for the database to be ready
log "Waiting for database to be ready..."
sleep 10

# Run Django migrations
docker compose exec -T web python manage.py migrate --noinput

log "Running collectstatic..."
docker compose exec -T web python manage.py collectstatic --noinput 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${GREEN}  WayFinder 2.0 — Deployment Complete!${NC}"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "  🌐  API:       https://${DOMAIN}/api/v2/health/"
echo "  🔌  WebSocket: wss://${DOMAIN}/ws/navigate/"
echo ""
echo "  📋  Useful commands:"
echo "    docker compose logs -f web        # Django logs"
echo "    docker compose logs -f nginx      # Nginx logs"
echo "    docker compose exec web python manage.py createsuperuser"
echo "    docker compose restart web        # Restart after .env change"
echo ""
echo "  📁  Logs: /var/log/wayfinder/"
echo "  📁  Config: ${BACKEND_DIR}/.env"
echo "═══════════════════════════════════════════════════════════════════"
