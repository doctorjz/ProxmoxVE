#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: doctorjz
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Crosstalk-Solutions/unifi-toolkit

if [[ -n "$FUNCTIONS_FILE_PATH" ]]; then
  source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
else
  source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func)
fi
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

msg_info "Configuring ${APP}"
mkdir -p /opt/unifi-toolkit/data

# Generate a Fernet encryption key using Python (available in Debian 12)
ENCRYPTION_KEY=$(python3 -c \
  "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null \
  || docker run --rm python:3-slim \
     sh -c "pip install -q cryptography && python -c \
     'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'")

cat > /opt/unifi-toolkit/.env <<EOF
ENCRYPTION_KEY=${ENCRYPTION_KEY}
DEPLOYMENT_TYPE=local
LOG_LEVEL=INFO
STALKER_REFRESH_INTERVAL=60
UNIFI_VERIFY_SSL=false
APP_PORT=8000
EOF

cat > /opt/unifi-toolkit/docker-compose.yml <<'COMPOSEOF'
services:
  unifi-toolkit:
    image: crosstalksolutions/unifi-toolkit:latest
    container_name: unifi-toolkit
    restart: unless-stopped
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data
      - ./.env:/app/.env:ro
    env_file:
      - .env
COMPOSEOF

chown -R 1000:1000 /opt/unifi-toolkit/data
chmod 755 /opt/unifi-toolkit/data
msg_ok "Configured ${APP}"

msg_info "Pulling & Starting ${APP} (this may take a moment)"
cd /opt/unifi-toolkit
docker compose pull &>/dev/null
docker compose up -d &>/dev/null
msg_ok "Started ${APP}"

msg_info "Creating Update Script"
cat > /usr/bin/update <<'UPDATEEOF'
#!/usr/bin/env bash
echo ""
echo "  Updating UniFi Toolkit..."
echo ""
cd /opt/unifi-toolkit
docker compose pull
docker compose up -d
docker compose exec -T unifi-toolkit alembic upgrade head 2>/dev/null || true
docker compose restart
echo ""
echo "  Update complete! Access at: http://$(hostname -I | awk '{print $1}'):8000"
echo ""
UPDATEEOF
chmod +x /usr/bin/update
msg_ok "Created Update Script"

motd_ssh
customize

msg_info "Cleaning Up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
