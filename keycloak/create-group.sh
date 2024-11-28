#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

SIMPLE_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${SIMPLE_SCRIPT_DIR}/common.sh"
source "${SIMPLE_SCRIPT_DIR}/env.sh"

RUN_IN_CONTAINER="${KEYCLOAK_IN_CONTAINER}"
RUN_IN_CONTAINER_NAME="${KEYCLOAK_CONTAINER_NAME}"

#
# Main
#

if [[ $# -lt 1 ]]; then
    __log "Group name expected";
    exit 1;
fi
group_name=$1
shift

__keycloak_login
__run_command /opt/keycloak/bin/kcadm.sh create groups -r "${KEYCLOAK_REALM}" -s "name=${group_name}" $@ -i 