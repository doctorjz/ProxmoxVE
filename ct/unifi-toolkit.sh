#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: doctorjz
# License: MIT | https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/LICENSE
# Source: https://github.com/Crosstalk-Solutions/unifi-toolkit

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

APP="UniFi-Toolkit"
var_tags="${var_tags:-unifi;network;docker}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

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
  docker compose pull
  docker compose up -d
  docker compose exec -T unifi-toolkit alembic upgrade head 2>/dev/null || true
  docker compose restart
  msg_ok "Updated ${APP}"
  exit
}

start
build_container

msg_info "Running UniFi-Toolkit installer"
pct exec "$CTID" -- bash -c "$(curl -fsSL https://raw.githubusercontent.com/doctorjz/ProxmoxVE/main/install/unifi-toolkit-install.sh)"
msg_ok "UniFi-Toolkit installer finished"

description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8000${CL}"
