#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Antigravity
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Ozark-Connect/NetworkOptimizer

APP="Network Optimizer"
var_tags="${var_tags:-network}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-6}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

function header_info {
clear
cat <<"EOF"
    _   __     __  ____        __  _____                  
   / | / /__  / /_/ __ \____  / /_/ ___/  _____  _____  
  /  |/ / _ \/ __/ / / / __ \/ __/\__ \  / _ \ \/ / _ \ 
 / /|  /  __/ /_/ /_/ / /_/ / /_ ___/ / /  __/>  <  __/ 
/_/ |_/\___/\__/\____/ .___/\__//____/  \___/_/\_/\___/  
                    /_/                                    
EOF
}

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/network-optimizer ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating Network Optimizer"
  systemctl stop network-optimizer

  export PATH="/root/.dotnet:$PATH"
  git clone -q https://github.com/Ozark-Connect/NetworkOptimizer.git /tmp/NetworkOptimizer
  cd /tmp/NetworkOptimizer

  mkdir -p /opt/network-optimizer
  $STD dotnet publish src/NetworkOptimizer.Web -c Release -r linux-x64 --self-contained -o /opt/network-optimizer
  chmod +x /opt/network-optimizer/NetworkOptimizer.Web

  rm -rf /tmp/NetworkOptimizer

  systemctl start network-optimizer
  msg_ok "Updated successfully!"
  exit
}

install_script
start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8042${CL}"
