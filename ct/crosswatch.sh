#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Community
# License: MIT | https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/LICENSE
# Source: https://github.com/cenodude/CrossWatch

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

APP="CrossWatch"
var_tags="${var_tags:-media;sync}"
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

  if [[ ! -d /opt/crosswatch ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  RELEASE=$(curl -fsSL https://api.github.com/repos/cenodude/CrossWatch/releases/latest | grep "tag_name" | awk '{print $2}' | sed 's/[",v]//g')
  CURRENT=$(cat /opt/crosswatch/VERSION 2>/dev/null || echo "unknown")

  if [[ "${RELEASE}" == "${CURRENT}" ]]; then
    msg_ok "Already at version ${RELEASE} — no update needed."
    exit
  fi

  msg_info "Updating ${APP} from ${CURRENT} to ${RELEASE}"
  systemctl stop crosswatch.service

  cd /opt/crosswatch
  git fetch --tags --quiet
  git checkout "v${RELEASE}" --quiet

  source /opt/crosswatch/venv/bin/activate
  pip install --upgrade --quiet -r requirements.txt

  echo "${RELEASE}" > /opt/crosswatch/VERSION
  systemctl start crosswatch.service
  msg_ok "Updated ${APP} to v${RELEASE}"
  exit
}

INSTALL_SCRIPT="https://raw.githubusercontent.com/doctorjz/ProxmoxVE/main/install/crosswatch-install.sh"

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8787${CL}"
