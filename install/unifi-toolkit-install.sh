#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: doctorjz
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Crosstalk-Solutions/unifi-toolkit

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  ca-certificates \
  gnupg \
  lsb-release
msg_ok "Installed Dependencies"

msg_info "Installing Docker"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
$STD apt-get update
$STD apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-compose-plugin
msg_ok "Installed Docker"

msg_info "Setting Up ${APP}"
mkdir -p /opt/unifi-toolkit/data

# Generate a secure Fernet encryption key
ENCRYPTION_KEY=$(docker run --rm python:3-slim \
  sh -c "pip install -q cryptography && python -c \
  'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'" \
  2>/dev/null)

# Write .env file
cat > /opt/unifi-toolkit/.env <<EOF
ENCRYPTION_KEY=${ENCRYPTION_KEY}
DEPLOYMENT_TYPE=local
LOG_LEVEL=INFO
STALKER_REFRESH_INTERVAL=60
UNIFI_VERIFY_SSL=false
APP_PORT=8000
EOF

# Write docker-compose.yml
cat > /opt/unifi-toolkit/docker-compose.yml <<'EOF'
services:
  unifi-toolkit:
    image: crosstalksolutions/unifi-toolkit:latest
    container_name: unifi-toolkit
    restart: unless-stopped
    ports:
      - "${APP_PORT:-8000}:${APP_PORT:-8000}"
    volumes:
      - ./data:/app/data
      - ./.env:/app/.env:ro
    env_file:
      - .env
EOF

# Fix permissions
chown -R 1000:1000 /opt/unifi-toolkit/data
chmod 755 /opt/unifi-toolkit/data

msg_ok "Configured ${APP}"

msg_info "Starting ${APP} Container"
cd /opt/unifi-toolkit
docker compose pull &>/dev/null
docker compose up -d &>/dev/null
msg_ok "Started ${APP}"

msg_info "Creating Update Script"
cat > /usr/bin/update <<'EOF'
#!/usr/bin/env bash
# UniFi Toolkit updater
set -e

APP_DIR="/opt/unifi-toolkit"

echo ""
echo "  Updating UniFi Toolkit..."
echo ""

cd "$APP_DIR"

echo "  Pulling latest image..."
docker compose pull

echo "  Restarting container..."
docker compose up -d

echo "  Applying database migrations..."
docker compose exec unifi-toolkit alembic upgrade head || true

echo "  Restarting to apply changes..."
docker compose restart

echo ""
echo "  UniFi Toolkit updated successfully!"
echo "  Access at: http://$(hostname -I | awk '{print $1}'):8000"
echo ""
EOF
chmod +x /usr/bin/update
msg_ok "Update Script Created"

motd_ssh
customize

msg_info "Cleaning Up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
