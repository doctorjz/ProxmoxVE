#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Antigravity
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Ozark-Connect/NetworkOptimizer

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
  sshpass \
  iperf3 \
  wget \
  curl \
  tar \
  jq \
  git \
  unzip
msg_ok "Installed Dependencies"

msg_info "Setting up .NET 10 SDK"
wget -q https://dot.net/v1/dotnet-install.sh -O /root/dotnet-install.sh
chmod +x /root/dotnet-install.sh
/root/dotnet-install.sh --channel 10.0 >/dev/null 2>&1
export PATH="/root/.dotnet:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
rm -f /root/dotnet-install.sh
msg_ok "Setup .NET 10 SDK"

msg_info "Installing Network Optimizer"
git clone -q https://github.com/Ozark-Connect/NetworkOptimizer.git /tmp/NetworkOptimizer
cd /tmp/NetworkOptimizer

mkdir -p /opt/network-optimizer
$STD dotnet publish src/NetworkOptimizer.Web -c Release -r linux-x64 --self-contained -o /opt/network-optimizer
chmod +x /opt/network-optimizer/NetworkOptimizer.Web

cat << 'EOF' > /opt/network-optimizer/start.sh
#!/bin/bash
cd "$(dirname "$0")"
export PATH="/root/.dotnet:$PATH"
export TZ="America/Chicago"
export ASPNETCORE_URLS="http://0.0.0.0:8042"
export HOST_IP=$(hostname -I | awk '{print $1}')
export Iperf3Server__Enabled=true

./NetworkOptimizer.Web
EOF
chmod +x /opt/network-optimizer/start.sh

rm -rf /tmp/NetworkOptimizer
msg_ok "Installed Network Optimizer"

msg_info "Creating Service"
cat << 'EOF' > /etc/systemd/system/network-optimizer.service
[Unit]
Description=Network Optimizer
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/network-optimizer
ExecStart=/opt/network-optimizer/start.sh
Restart=always
RestartSec=10
StandardOutput=append:/opt/network-optimizer/logs/stdout.log
StandardError=append:/opt/network-optimizer/logs/stderr.log

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /opt/network-optimizer/logs
systemctl daemon-reload
systemctl enable -q --now network-optimizer
msg_ok "Created Service"

motd_ssh
customize
cleanup
