#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Community
# License: MIT | https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/LICENSE
# Source: https://github.com/cenodude/CrossWatch

source /dev/stdin <<<"$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func)"

APP="CrossWatch"
var_install="${APP,,}"
INSTALL_DIR="/opt/crosswatch"
SERVICE_USER="crosswatch"
PORT="8787"

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  git \
  python3 \
  python3-pip \
  python3-venv \
  python3-dev \
  build-essential \
  libffi-dev \
  libssl-dev
msg_ok "Installed Dependencies"

msg_info "Fetching latest CrossWatch release"
RELEASE=$(curl -fsSL https://api.github.com/repos/cenodude/CrossWatch/releases/latest \
  | grep "tag_name" \
  | awk '{print $2}' \
  | sed 's/[",v]//g')
msg_ok "Found CrossWatch v${RELEASE}"

msg_info "Cloning CrossWatch v${RELEASE}"
git clone --quiet --branch "v${RELEASE}" --depth 1 \
  https://github.com/cenodude/CrossWatch.git "${INSTALL_DIR}"
echo "${RELEASE}" > "${INSTALL_DIR}/VERSION"
msg_ok "Cloned CrossWatch"

msg_info "Setting up Python virtual environment"
python3 -m venv "${INSTALL_DIR}/venv"
source "${INSTALL_DIR}/venv/bin/activate"
pip install --upgrade --quiet pip
pip install --quiet -r "${INSTALL_DIR}/requirements.txt"
deactivate
msg_ok "Python environment ready"

msg_info "Creating config directory"
mkdir -p /config
ln -sf /config "${INSTALL_DIR}/data"
msg_ok "Config directory created"

msg_info "Creating dedicated service user"
useradd -r -s /usr/sbin/nologin -d "${INSTALL_DIR}" "${SERVICE_USER}" 2>/dev/null || true
chown -R "${SERVICE_USER}":"${SERVICE_USER}" "${INSTALL_DIR}"
chown -R "${SERVICE_USER}":"${SERVICE_USER}" /config
msg_ok "Service user created"

msg_info "Creating systemd service"
cat <<EOF >/etc/systemd/system/crosswatch.service
[Unit]
Description=CrossWatch - Media Sync Engine
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/venv/bin/python3 crosswatch.py
Restart=on-failure
RestartSec=5
Environment="PORT=${PORT}"
Environment="CONFIG_DIR=/config"

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --quiet crosswatch.service
systemctl start crosswatch.service
msg_ok "CrossWatch service started"

motd_ssh
customize

msg_ok "Completed Successfully!"
echo -e "${APP} is accessible at: ${BGN}http://$(hostname -I | awk '{print $1}'):${PORT}${CL}"
