#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: doctorjz
# License: MIT | https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/LICENSE
# Source: https://github.com/Crosstalk-Solutions/unifi-toolkit

source /dev/stdin <<<"$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func)"

APP="UniFi-Toolkit"
INSTALL_DIR="/opt/unifi-toolkit"
PORT="8000"

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
  lsb-release \
  python3 \
  python3-cryptography
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

msg_info "Configuring UniFi-Toolkit"
mkdir -p "${INSTALL_DIR}/data"

ENCRYPTION_KEY=$(python3 -c \
  "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

cat > "${INSTALL_DIR}/.env" <<EOF
ENCRYPTION_KEY=${ENCRYPTION_KEY}
DEPLOYMENT_TYPE=local
LOG_LEVEL=INFO
STALKER_REFRESH_INTERVAL=60
UNIFI_VERIFY_SSL=false
APP_PORT=${PORT}
EOF

cat > "${INSTALL_DIR}/docker-compose.yml" <<'COMPOSEOF'
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

chown -R 1000:1000 "${INSTALL_DIR}/data"
chmod 755 "${INSTALL_DIR}/data"
msg_ok "Configured UniFi-Toolkit"

msg_info "Pulling & Starting UniFi-Toolkit (this may take a moment)"
cd "${INSTALL_DIR}"
docker compose pull &>/dev/null
docker compose up -d &>/dev/null
msg_ok "Started UniFi-Toolkit"

msg_info "Creating update command"
cat > /usr/local/bin/update <<'UPDATEEOF'
#!/usr/bin/env bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="/opt/unifi-toolkit"

if [[ ! -d "$INSTALL_DIR" ]]; then
  echo -e "${RED}No UniFi-Toolkit installation found at $INSTALL_DIR${NC}"
  exit 1
fi

echo -e "${YELLOW}Updating UniFi-Toolkit...${NC}"
cd "$INSTALL_DIR"

docker compose pull
docker compose up -d
docker compose exec -T unifi-toolkit alembic upgrade head 2>/dev/null || true
docker compose restart

echo -e "${GREEN}UniFi-Toolkit updated and restarted.${NC}"
echo -e "Access at: http://$(hostname -I | awk '{print $1}'):8000"
UPDATEEOF
chmod +x /usr/local/bin/update
msg_ok "Update command created — type 'update' anytime to update UniFi-Toolkit"

motd_ssh
customize

msg_ok "Completed Successfully!"
echo -e "UniFi-Toolkit is accessible at: http://$(hostname -I | awk '{print $1}'):${PORT}"
