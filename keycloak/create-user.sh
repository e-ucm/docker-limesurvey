#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

SIMPLE_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${SIMPLE_SCRIPT_DIR}/common.sh"
source "${SIMPLE_SCRIPT_DIR}/env.sh"

RUN_IN_CONTAINER="${KEYCLOAK_IN_CONTAINER}"
RUN_IN_CONTAINER_NAME="${KEYCLOAK_CONTAINER_NAME}"

#
# command line process
#

function usage () {
  local command=$(basename $0)
  echo 1>&2 "Usage: ${command} [<param>] <user name>"
  echo 1>&2 "Create a user in Keycloak and return it's id"
  echo 1>&2 "Options:"
  echo 1>&2 "  -h, --help"
  echo 1>&2 "      Displays this help message and exits."
  echo 1>&2 "  -p <password>, --pass=<password>"
  echo 1>&2 "      Set <password> as new user password."
  echo 1>&2 "  -g <groupId1[,groupId2]>, --groups=<groupId1[,groupId2]>"
  echo 1>&2 "      Add new user to groups with id <groupId1>, <groupId2>, etc."
}

LIST_LONG_OPTIONS=(
  "help",
  "pass:",
  "groups:"
)
LIST_SHORT_OPTIONS=(
  "h",
  "p:",
  "g:"
)

opts=$(getopt \
    --longoptions "$(printf "%s," "${LIST_LONG_OPTIONS[@]}")" \
    --options "$(printf "%s", "${LIST_SHORT_OPTIONS[@]}")" \
    --name "$(basename "$0")" \
    -- "$@"
)

eval set -- $opts

user_password=""
user_groups=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --)
      shift
      break
      ;;
    -p | --pass)
      user_password="$2"
      shift 2
      ;;
    -g | --groups)
      user_groups="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

#
# Main
#

if [[ $# -lt 1 ]]; then
    __log "Username name expected";
    usage;
    exit 1;
fi
user_name=$1
shift

__keycloak_login
user_id=$(__run_command /opt/keycloak/bin/kcadm.sh create users -r "${KEYCLOAK_REALM}" -s "username=${user_name}" -s "firstName=${user_name}" -s "lastName=Test" -s "email=${user_name}@example.com" -s emailVerified=true -s enabled=true $@ -i)
# set password
if [[ ! -z "${user_password}" ]]; then
    __run_command /opt/keycloak/bin/kcadm.sh set-password -r "${KEYCLOAK_REALM}" "--userid=${user_id}" --new-password "${user_password}"
fi

if [[ ! -z "${user_groups}" ]]; then
    tmp_groups=$(mktemp)
    trap "rm -rf -- ""${tmp_groups}""" EXIT

    "${SIMPLE_SCRIPT_DIR}/list-groups.sh" > ${tmp_groups}

    groups_names=$(echo "${user_groups}" | tr "," "\n")
    for group_name in $groups_names; do
        set +e
        group_id=$(cat "${tmp_groups}" | jq -e -c -r ".[] | select(.name == \"${group_name}\") | .id")
        result=$?
        set -e
        if [[ $result -ne 0 ]]; then
            continue
        fi
        __run_command /opt/keycloak/bin/kcadm.sh update "users/${user_id}/groups/${group_id}" -r ${KEYCLOAK_REALM} -s "realm=${KEYCLOAK_REALM}" -s "userId=${user_id}" -s "groupId=${group_id}" -n
    done

fi

echo $user_id
