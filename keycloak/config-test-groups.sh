#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

SIMPLE_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${SIMPLE_SCRIPT_DIR}/common.sh"
source "${SIMPLE_SCRIPT_DIR}/env.sh"

#
# Functions
#

function __create_group_if_not_exists()
{
  if [[ $# -lt 1 ]]; then
    __log "Group name missing"
    return 1
  fi
  local group_name="$1"
  local id=""
  local result=1
  set +e
  id=$(cat "${tmp_groups}" | jq -e -c -r ".[] | select(.name == \"${group_name}\") | .id")
  result=$?
  set -e
  if [[ $result -eq 0 ]]; then
    echo "'${group_name}' group already configured"
    return
  fi

  "${SIMPLE_SCRIPT_DIR}/create-group.sh" "${group_name}"
}

#
# Main
#

"${SIMPLE_SCRIPT_DIR}/wait-for"  -nc -t 60 "${KEYCLOAK_SERVER_URL}" -- echo "Keycloak available"

tmp_groups=$(mktemp)
trap "rm -rf -- ""${tmp_groups}""" EXIT

RUN_IN_CONTAINER="${KEYCLOAK_IN_CONTAINER}"
RUN_IN_CONTAINER_NAME="${KEYCLOAK_CONTAINER_NAME}"

"${SIMPLE_SCRIPT_DIR}/list-groups.sh" > ${tmp_groups}

groups=$(echo "${KEYCLOAK_TEST_GROUPS}" | tr "," "\n")
for group in $groups; do
  __create_group_if_not_exists "$group"
done
