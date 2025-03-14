#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

SIMPLE_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${SIMPLE_SCRIPT_DIR}/common.sh"
source "${SIMPLE_SCRIPT_DIR}/env.sh"

SCRIPT_TMP_DIR="$(mktemp -d)"
trap "rm -rf -- ""${SCRIPT_TMP_DIR}""" EXIT

RUN_IN_CONTAINER="${KEYCLOAK_IN_CONTAINER}"
RUN_IN_CONTAINER_NAME="${KEYCLOAK_CONTAINER_NAME}"

if [[ ! -f "${KEYCLOAK_TRUSTSTORE_FILE}" ]]; then
    if [[ -f "${KEYCLOAK_CA_FILE}" ]]; then
        keytool -importcert -trustcacerts -noprompt \
            -storepass "${KEYCLOAK_TRUSTSTORE_PASS}" \
            -alias "${KEYCLOAK_CA_ALIAS}" \
            -keystore "${KEYCLOAK_TRUSTSTORE_FILE}" \
            -file "${KEYCLOAK_CA_FILE}"

        KEYCLOAK_TRUSTSTORE_FILE_NAME=$(basename "${KEYCLOAK_TRUSTSTORE_FILE}")

        if [[ ! -f "${KEYCLOAK_TRUSTSTORE_DIR}/${KEYCLOAK_TRUSTSTORE_FILE_NAME}" ]]; then
            cp "${KEYCLOAK_TRUSTSTORE_FILE}" "${KEYCLOAK_TRUSTSTORE_DIR}/${KEYCLOAK_TRUSTSTORE_FILE_NAME}"
        fi
    fi
fi

#
# Main
#

if [[ $# -lt 1 ]]; then
    __log "SAML2 'SP metadata url' expected";
    exit 1;
fi
metadata_url=$1
shift

new_client=$(mktemp -p ${SCRIPT_TMP_DIR})
"${SIMPLE_SCRIPT_DIR}/new-saml-client-definition.sh" "${metadata_url}" > "${new_client}"
__keycloak_login
cat "${new_client}" | __run_command /opt/keycloak/bin/kcadm.sh create clients -r ${KEYCLOAK_REALM} -f - $@ -i 