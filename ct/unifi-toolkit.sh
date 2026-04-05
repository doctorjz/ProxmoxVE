#!/usr/bin/env bash
# Copyright (c) 2021-2025 community-scripts ORG
# Author: doctorjz
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Crosstalk-Solutions/unifi-toolkit

source <(curl -fsSL https://raw.githubusercontent.com/doctorjz/ProxmoxVE/main/misc/build.func)

APP="UniFi-Toolkit"
var_tags="unifi;network;docker"
var_cpu="2"
var_ram="1024"
var_disk="8"
var_os="debian"
var_version="12"
var_unprivileged="1"

function header_info {
  clear
  cat <<"EOF"
  _   _       _  ____  _   _____         _ _    _ _   
 | | | |_ __ (_)/ ___|(_) |_   _|__  ___| | | _(_) |_ 
 | | | | '_ \| | |___ | |   | |/ _ \/ _ \ | |/ / | __|
 | |_| | | | | |  ___|| |   | | (_) (_) | |   <| | |_ 
  \___/|_| |_|_|_|    |_|   |_|\___/\___/_|_|\_\_|\__|

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
  if [[ ! -d /opt/unifi-toolkit ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating ${APP}"
  cd /opt/unifi-toolkit
  docker compose pull &>/dev/null
  docker compose up -d &>/dev/null
  docker compose exec unifi-toolkit alembic upgrade head &>/dev/null
  docker compose restart &>/dev/null
  msg_ok "Updated ${APP}"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8000${CL}"
