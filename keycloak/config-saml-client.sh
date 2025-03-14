#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

SIMPLE_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${SIMPLE_SCRIPT_DIR}/common.sh"
source "${SIMPLE_SCRIPT_DIR}/env.sh"

"$(dirname ${SIMPLE_SCRIPT_DIR})/overlay/usr/local/bin/wait-for" -nc -t 60 "${KEYCLOAK_SERVER_URL}" -- echo "Keycloak available"

tmp_clients=$(mktemp)
trap "rm -rf -- ""${tmp_clients}""" EXIT

RUN_IN_CONTAINER="${KEYCLOAK_IN_CONTAINER}"
RUN_IN_CONTAINER_NAME="${KEYCLOAK_CONTAINER_NAME}"

"${SIMPLE_SCRIPT_DIR}/list-clients.sh" > ${tmp_clients}

set +e
id=$(cat "${tmp_clients}" | jq -e -c -r ".[] | select(.clientId == \"${KEYCLOAK_TEST_CLIENT}\") | .id")
result=$?
set -e
if [[ $result -eq 0 ]]; then
  echo "'${KEYCLOAK_TEST_CLIENT}' client already configured"
  exit 0;
fi

"${SIMPLE_SCRIPT_DIR}/create-saml-client.sh" "${SIMPLESAMLPHP_SP_METADATA_URL}"