#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# WayFinder 2.0 — Certbot SSL Auto-Renewal
# Install: sudo cp certbot-renew.sh /etc/cron.weekly/wayfinder-ssl-renew
#          sudo chmod +x /etc/cron.weekly/wayfinder-ssl-renew
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

LOG="/var/log/wayfinder/certbot-renew.log"

echo "[$(date)] Starting certificate renewal check..." >> "$LOG"

# Renew certificates (only renews if expiry < 30 days)
certbot renew --quiet --deploy-hook "docker exec wayfinder-nginx nginx -s reload" >> "$LOG" 2>&1

echo "[$(date)] Renewal check complete." >> "$LOG"
