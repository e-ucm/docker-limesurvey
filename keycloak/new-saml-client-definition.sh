#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

SIMPLE_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${SIMPLE_SCRIPT_DIR}/common.sh"
source "${SIMPLE_SCRIPT_DIR}/env.sh"

SCRIPT_TMP_DIR="$(mktemp -d)"
trap "rm -rf -- ""${SCRIPT_TMP_DIR}""" EXIT

#
# Utils
#

function __get_access_token()
{
    local access_token="${KEYCLOAK_ACCESS_TOKEN}"
    if [[ ! -z ${access_token} ]]; then
        echo ${access_token}
        return
    fi
    local TOKEN_URL="${KEYCLOAK_SERVER_URL}/realms/master/protocol/openid-connect/token"
    local curl_extra_opts="--insecure"
    if [[ ! -z "${KEYCLOAK_CA_FILE}" ]]; then
        curl_extra_opts="--cacert ${KEYCLOAK_CA_FILE}"
    fi
    set +e
    curl ${curl_extra_opts} -f -s -d client_id=admin-cli -d username=${KEYCLOAK_ADMIN_USERNAME} -d password=${KEYCLOAK_ADMIN_PASSWORD} -d grant_type=password ${TOKEN_URL} | jq -r '.access_token'
    local ok=$?
    set -e
    if [[ $ok -ne 0 ]]; then
        __log "Can't get Keycloak token"
        return $ok
    fi
}

function __convert_xml_saml2()
{
    if [[ $# -lt 1 ]]; then
        __log "Missing metadata URL"
        return 1
    fi

    local sp_metadata_url="$1"
    local tmp_metadata=$(mktemp -p ${SCRIPT_TMP_DIR})

    local curl_extra_opts="--insecure"
    if [[ ! -z "${KEYCLOAK_CA_FILE}" ]]; then
        curl_extra_opts="--cacert ${KEYCLOAK_CA_FILE}"
    fi
    set +e
    curl ${curl_extra_opts} -f -s -o "${tmp_metadata}" "${sp_metadata_url}"
    local ok=$?
    set -e
    if [[ $ok -ne 0 ]]; then
        __log "Can't get SP metadata '${sp_metadata_url}'"
        return $ok
    fi

    local access_token=$(__get_access_token) || exit $?

    local AUTH="Authorization: bearer ${access_token}"
    local CONVERTER_URL="${KEYCLOAK_SERVER_URL}/admin/realms/${KEYCLOAK_REALM}/client-description-converter"
    set +e
    curl ${curl_extra_opts} -f -s -X POST -H "${AUTH}" -H 'Content-type: text/plain;charset=UTF-8' ${CONVERTER_URL} -d "@${tmp_metadata}"
    ok=$?
    set -e
    if [[ $ok -ne 0 ]]; then
        __log "Can't get convert metadata"
        return $ok
    fi
    return
}

#
# Main
#

if [[ $# -lt 1 ]]; then
    __log "SAML2 'SP metadata url' expected";
    exit 1;
fi
metadata_url=$1

converted_client=$(mktemp -p ${SCRIPT_TMP_DIR})

__convert_xml_saml2 "${metadata_url}" > "${converted_client}"
jq -s '.[0] * .[1]' "${converted_client}" "${SIMPLE_SCRIPT_DIR}/new-sp.json"
