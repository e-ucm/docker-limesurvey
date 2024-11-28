#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

SIMPLE_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${SIMPLE_SCRIPT_DIR}/common.sh"
source "${SIMPLE_SCRIPT_DIR}/env.sh"

#
# Functions
#

function __create_user_if_not_exists()
{
  if [[ $# -lt 1 ]]; then
    __log "User name missing"
    return 1
  fi
  local username="$1"
  local id=""
  local result=1
  set +e
  id=$(cat "${tmp_users}" | jq -e -c -r ".[] | select(.username == \"${username}\") | .id")
  result=$?
  set -e
  if [[ $result -eq 0 ]]; then
    echo "'${username}' user already configured"
    return
  fi

  "${SIMPLE_SCRIPT_DIR}/create-user.sh" -p "${username}" --groups "${KEYCLOAK_TEST_GROUPS}" "${username}"
}

#
# Main
#

"${SIMPLE_SCRIPT_DIR}/wait-for"  -nc -t 60 "${KEYCLOAK_SERVER_URL}" -- echo "Keycloak available"

tmp_users=$(mktemp)
trap "rm -rf -- ""${tmp_users}""" EXIT

RUN_IN_CONTAINER="${KEYCLOAK_IN_CONTAINER}"
RUN_IN_CONTAINER_NAME="${KEYCLOAK_CONTAINER_NAME}"

"${SIMPLE_SCRIPT_DIR}/list-users.sh" > ${tmp_users}

users=$(echo "${KEYCLOAK_TEST_USERS}" | tr "," "\n")
for user in $users; do
  __create_user_if_not_exists "$user"
done
