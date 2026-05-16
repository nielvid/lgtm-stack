#!/usr/bin/env bash
# =================================================================
# LGTM Stack — GCP VM Bootstrap Script
# Used as metadata_startup_script in Terraform.
# Runs once on first boot as root.
# =================================================================
set -euo pipefail

REPO_URL="https://github.com/nielvid/lgtm-stack.git"  
DEPLOY_DIR="/opt/lgtm-stack"
LOG_FILE="/var/log/lgtm-startup.log"

exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== LGTM Stack Bootstrap $(date) ==="

# ---------------------------------------------------------------
# 1. System updates
# ---------------------------------------------------------------
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  curl wget git ca-certificates gnupg lsb-release \
  htop jq net-tools unzip

# ---------------------------------------------------------------
# 2. Install Docker Engine
# ---------------------------------------------------------------
if ! command -v docker &>/dev/null; then
  echo "Installing Docker..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  echo "Docker installed: $(docker --version)"
else
  echo "Docker already installed: $(docker --version)"
fi

# ---------------------------------------------------------------
# 3. Clone repository
# ---------------------------------------------------------------
if [ ! -d "$DEPLOY_DIR" ]; then
  echo "Cloning repository to $DEPLOY_DIR..."
  git clone "$REPO_URL" "$DEPLOY_DIR"
else
  echo "Repository already cloned — pulling latest..."
  git -C "$DEPLOY_DIR" pull origin main
fi

# ---------------------------------------------------------------
# 4. Set up environment file
# ---------------------------------------------------------------
if [ ! -f "$DEPLOY_DIR/.env" ]; then
  cp "$DEPLOY_DIR/.env.example" "$DEPLOY_DIR/.env"
  echo "Created .env from .env.example — edit with your values!"
fi

# ---------------------------------------------------------------
# 5. Create required host directories
# ---------------------------------------------------------------
mkdir -p /tmp/pushgateway
chmod 777 /tmp/pushgateway

# ---------------------------------------------------------------
# 6. Start the stack
# ---------------------------------------------------------------
echo "Starting LGTM stack..."
cd "$DEPLOY_DIR"
docker compose pull
docker compose up -d --build

echo "=== LGTM Stack started. Check status with: docker compose ps ==="
echo "=== Grafana: http://$(curl -s ifconfig.me):3000 ==="
