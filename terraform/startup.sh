#!/usr/bin/env bash
# =================================================================
# LGTM Stack — GCP VM Bootstrap Script (systemd, no Docker)
# Used as metadata_startup_script in Terraform.
# Runs once on first boot as root.
#
# Installs all services as native Linux binaries managed by systemd.
# No container runtime is installed or used.
# =================================================================
set -euo pipefail

REPO_URL="https://github.com/nielvid/lgtm-stack.git"
DEPLOY_DIR="/opt/lgtm-stack"
LOG_FILE="/var/log/lgtm-startup.log"

exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== LGTM Stack Bootstrap $(date) ==="

# ---------------------------------------------------------------
# Versions
# ---------------------------------------------------------------
PROMETHEUS_VERSION="2.55.0"
ALERTMANAGER_VERSION="0.27.0"
NODE_EXPORTER_VERSION="1.8.2"
BLACKBOX_VERSION="0.25.0"
LOKI_VERSION="3.3.2"
TEMPO_VERSION="2.7.1"
OTELCOL_VERSION="0.115.1"
PUSHGATEWAY_VERSION="1.10.0"
ARCH="amd64"
BIN_DIR="/usr/local/bin"

# ---------------------------------------------------------------
# 1. System updates & base dependencies
# ---------------------------------------------------------------
echo "--- [1/10] Updating system packages ---"
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  curl wget git ca-certificates gnupg lsb-release \
  htop jq net-tools unzip tar

# ---------------------------------------------------------------
# 2. Install Grafana (via official apt repository)
# ---------------------------------------------------------------
echo "--- [2/10] Installing Grafana ---"
if ! dpkg -l grafana &>/dev/null; then
  mkdir -p /etc/apt/keyrings
  wget -q -O - https://apt.grafana.com/gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
    | tee /etc/apt/sources.list.d/grafana.list > /dev/null
  apt-get update -y
  apt-get install -y grafana
  echo "Grafana installed: $(grafana-server -v 2>&1 | head -1)"
else
  echo "Grafana already installed"
fi

# ---------------------------------------------------------------
# 3. Install Node.js 20 (for the demo app)
# ---------------------------------------------------------------
echo "--- [3/10] Installing Node.js 20 ---"
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
  echo "Node.js installed: $(node --version)"
else
  echo "Node.js already installed: $(node --version)"
fi

# ---------------------------------------------------------------
# Helper: download & install a binary release
# Usage: install_binary <name> <url> <binary_in_archive>
# ---------------------------------------------------------------
install_binary() {
  local NAME="$1"
  local URL="$2"
  local ARCHIVE="/tmp/${NAME}.tar.gz"

  echo "Downloading $NAME from $URL..."
  wget -q "$URL" -O "$ARCHIVE"
  tar -xzf "$ARCHIVE" -C /tmp/
  # Find and move all relevant binaries (the tarball usually extracts a dir)
  find /tmp -maxdepth 2 -name "${NAME}" -type f -exec mv {} "$BIN_DIR/${NAME}" \;
  chmod +x "$BIN_DIR/${NAME}"
  rm -f "$ARCHIVE"
  echo "$NAME installed: $($BIN_DIR/$NAME --version 2>&1 | head -1)"
}

# ---------------------------------------------------------------
# 4. Download & install all Prometheus-ecosystem binaries
# ---------------------------------------------------------------
echo "--- [4/10] Installing Prometheus ecosystem binaries ---"

BASE="https://github.com/prometheus"

install_binary "prometheus" \
  "${BASE}/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}.tar.gz"

# Also install promtool from the same archive
find /tmp -maxdepth 2 -name "promtool" -type f -exec mv {} "$BIN_DIR/promtool" \; 2>/dev/null || true
chmod +x "$BIN_DIR/promtool" 2>/dev/null || true

install_binary "alertmanager" \
  "${BASE}/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-${ARCH}.tar.gz"

# Also install amtool
find /tmp -maxdepth 2 -name "amtool" -type f -exec mv {} "$BIN_DIR/amtool" \; 2>/dev/null || true

install_binary "node_exporter" \
  "${BASE}/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"

install_binary "blackbox_exporter" \
  "${BASE}/blackbox_exporter/releases/download/v${BLACKBOX_VERSION}/blackbox_exporter-${BLACKBOX_VERSION}.linux-${ARCH}.tar.gz"

install_binary "pushgateway" \
  "${BASE}/pushgateway/releases/download/v${PUSHGATEWAY_VERSION}/pushgateway-${PUSHGATEWAY_VERSION}.linux-${ARCH}.tar.gz"

# ---------------------------------------------------------------
# 5. Download & install Loki, Tempo, OTel Collector
# ---------------------------------------------------------------
echo "--- [5/10] Installing Loki, Tempo, OTel Collector ---"

# Loki
LOKI_URL="https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-${ARCH}.zip"
wget -q "$LOKI_URL" -O /tmp/loki.zip
unzip -o /tmp/loki.zip -d /tmp/ loki-linux-${ARCH}
mv /tmp/loki-linux-${ARCH} "$BIN_DIR/loki"
chmod +x "$BIN_DIR/loki"
rm -f /tmp/loki.zip
echo "Loki installed: $($BIN_DIR/loki --version 2>&1 | head -1)"

# Tempo
TEMPO_URL="https://github.com/grafana/tempo/releases/download/v${TEMPO_VERSION}/tempo_${TEMPO_VERSION}_linux_${ARCH}.tar.gz"
wget -q "$TEMPO_URL" -O /tmp/tempo.tar.gz
tar -xzf /tmp/tempo.tar.gz -C /tmp/
mv /tmp/tempo "$BIN_DIR/tempo"
chmod +x "$BIN_DIR/tempo"
rm -f /tmp/tempo.tar.gz
echo "Tempo installed: $($BIN_DIR/tempo --version 2>&1 | head -1)"

# OpenTelemetry Collector (contrib)
OTELCOL_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTELCOL_VERSION}/otelcol-contrib_${OTELCOL_VERSION}_linux_${ARCH}.tar.gz"
wget -q "$OTELCOL_URL" -O /tmp/otelcol.tar.gz
tar -xzf /tmp/otelcol.tar.gz -C /tmp/
mv /tmp/otelcol-contrib "$BIN_DIR/otelcol-contrib"
chmod +x "$BIN_DIR/otelcol-contrib"
rm -f /tmp/otelcol.tar.gz
echo "OTel Collector installed: $($BIN_DIR/otelcol-contrib --version 2>&1 | head -1)"

# ---------------------------------------------------------------
# 6. Create system users (one per service, no login shell)
# ---------------------------------------------------------------
echo "--- [6/10] Creating system users ---"

for USER in prometheus alertmanager loki tempo otelcol node-exporter blackbox pushgateway; do
  if ! id "$USER" &>/dev/null; then
    useradd --system --no-create-home --shell /bin/false "$USER"
    echo "Created user: $USER"
  fi
done

# ---------------------------------------------------------------
# 7. Create configuration & data directories
# ---------------------------------------------------------------
echo "--- [7/10] Creating directories ---"

# Prometheus
mkdir -p /etc/prometheus/rules /var/lib/prometheus
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Alertmanager
mkdir -p /etc/alertmanager/templates /var/lib/alertmanager
chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager

# Loki
mkdir -p /etc/loki /var/lib/loki/chunks /var/lib/loki/rules /var/lib/loki/compactor
chown -R loki:loki /etc/loki /var/lib/loki

# Tempo
mkdir -p /etc/tempo /var/lib/tempo/blocks /var/lib/tempo/wal /var/lib/tempo/generator/wal
chown -R tempo:tempo /etc/tempo /var/lib/tempo

# OTel Collector
mkdir -p /etc/otelcol-contrib
chown -R otelcol:otelcol /etc/otelcol-contrib

# Blackbox
mkdir -p /etc/blackbox_exporter
chown -R blackbox:blackbox /etc/blackbox_exporter

# Pushgateway
mkdir -p /var/lib/pushgateway
chown -R pushgateway:pushgateway /var/lib/pushgateway

# Grafana provisioning (managed by grafana user, package creates this)
mkdir -p /etc/grafana/provisioning/dashboards /etc/grafana/provisioning/datasources

# ---------------------------------------------------------------
# 8. Clone / update repository
# ---------------------------------------------------------------
echo "--- [8/10] Cloning repository ---"
if [ ! -d "$DEPLOY_DIR/.git" ]; then
  git clone "$REPO_URL" "$DEPLOY_DIR"
else
  git -C "$DEPLOY_DIR" pull origin main
fi

# Set up environment file
if [ ! -f "$DEPLOY_DIR/.env" ]; then
  cp "$DEPLOY_DIR/.env.example" "$DEPLOY_DIR/.env"
  echo "⚠️  Created .env from .env.example — edit /opt/lgtm-stack/.env with real values!"
fi

# Load env vars for use in this script (Slack webhook etc.)
set -a
source "$DEPLOY_DIR/.env" || true
set +a

# ---------------------------------------------------------------
# 9. Copy configuration files to system paths
# ---------------------------------------------------------------
echo "--- [9/10] Installing configuration files ---"

# Prometheus
cp "$DEPLOY_DIR/prometheus/prometheus.yml" /etc/prometheus/prometheus.yml
cp "$DEPLOY_DIR/prometheus/rules/"*.yml    /etc/prometheus/rules/
chown -R prometheus:prometheus /etc/prometheus

# Alertmanager — inject Slack webhook from env
sed "s|\${SLACK_WEBHOOK_URL}|${SLACK_WEBHOOK_URL:-https://hooks.slack.com/REPLACE}|g" \
  "$DEPLOY_DIR/alertmanager/alertmanager.yml" > /etc/alertmanager/alertmanager.yml
cp "$DEPLOY_DIR/alertmanager/templates/slack.tmpl" /etc/alertmanager/templates/slack.tmpl
chown -R alertmanager:alertmanager /etc/alertmanager

# Loki
cp "$DEPLOY_DIR/loki/loki-config.yaml" /etc/loki/loki-config.yaml
chown -R loki:loki /etc/loki

# Tempo
cp "$DEPLOY_DIR/tempo/tempo-config.yaml" /etc/tempo/tempo-config.yaml
chown -R tempo:tempo /etc/tempo

# OTel Collector
cp "$DEPLOY_DIR/otel-collector/otel-collector-config.yaml" /etc/otelcol-contrib/config.yaml
chown -R otelcol:otelcol /etc/otelcol-contrib

# Blackbox Exporter
cp "$DEPLOY_DIR/blackbox/blackbox.yml" /etc/blackbox_exporter/config.yml
chown -R blackbox:blackbox /etc/blackbox_exporter

# Grafana provisioning
cp "$DEPLOY_DIR/grafana/provisioning/datasources/datasources.yaml" \
   /etc/grafana/provisioning/datasources/lgtm-datasources.yaml
cp "$DEPLOY_DIR/grafana/provisioning/dashboards/dashboards.yaml" \
   /etc/grafana/provisioning/dashboards/lgtm-dashboards.yaml
cp "$DEPLOY_DIR/grafana/provisioning/dashboards/"*.json \
   /etc/grafana/provisioning/dashboards/
chown -R grafana:grafana /etc/grafana/provisioning

# Grafana environment overrides
cat > /etc/grafana/grafana.env <<EOF
GF_SECURITY_ADMIN_USER=${GF_SECURITY_ADMIN_USER:-admin}
GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-changeme}
GF_USERS_ALLOW_SIGN_UP=false
GF_ANALYTICS_REPORTING_ENABLED=false
EOF

# Add EnvironmentFile to grafana-server service override
mkdir -p /etc/systemd/system/grafana-server.service.d
cat > /etc/systemd/system/grafana-server.service.d/env.conf <<EOF
[Service]
EnvironmentFile=/etc/grafana/grafana.env
EOF

# ---------------------------------------------------------------
# 10. Install systemd unit files & demo app, then start services
# ---------------------------------------------------------------
echo "--- [10/10] Installing systemd units and starting services ---"

# Copy all custom unit files from the repo
cp "$DEPLOY_DIR/systemd/"*.service /etc/systemd/system/

# Demo app — install Node.js dependencies
APP_DIR="$DEPLOY_DIR/app"
cd "$APP_DIR"
npm install --omit=dev
# Create dedicated user for app
if ! id "demo-app" &>/dev/null; then
  useradd --system --no-create-home --shell /bin/false demo-app
fi
chown -R demo-app:demo-app "$APP_DIR"

# Reload systemd and enable all services
systemctl daemon-reload

SERVICES=(
  prometheus
  alertmanager
  loki
  tempo
  otelcol-contrib
  node-exporter
  blackbox-exporter
  pushgateway
  grafana-server
  demo-app
)

for SVC in "${SERVICES[@]}"; do
  systemctl enable "$SVC" 2>/dev/null || true
  systemctl restart "$SVC"
  echo "✅ $SVC started"
done

echo ""
echo "=== LGTM Stack fully started ==="
echo "=== Grafana:     http://$(curl -s ifconfig.me 2>/dev/null || echo '<VM-IP>'):3000 ==="
echo "=== Prometheus:  http://$(curl -s ifconfig.me 2>/dev/null || echo '<VM-IP>'):9090 ==="
echo "=== Run: systemctl status prometheus alertmanager loki tempo ==="
