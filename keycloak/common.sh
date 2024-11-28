: ${COMMON_LOADED:=0}
[[ "$COMMON_LOADED" -eq 1 ]] && return

function __log()
{
    >&2 echo "$@"
}

# Simple
# see: https://stackoverflow.com/a/246128
function __script_path()
{
    local SOURCE=${BASH_SOURCE[0]}
    if [[ $# -gt 0 ]]; then
        SOURCE=$1
    fi
    local SCRIPT_DIR=$( cd -- "$( dirname -- "${SOURCE}" )" &> /dev/null && pwd )
    echo $SCRIPT_DIR
}

# Advanced
# see: https://stackoverflow.com/a/246128
function __adv_script_path()
{
    local SOURCE=${BASH_SOURCE[0]}
    if [[ $# -gt 0 ]]; then
        SOURCE=$1
    fi
    local SCRIPT_DIR=$SOURCE
    while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
        SOURCE=$(readlink "$SOURCE")
        [[ $SOURCE != /* ]] && SOURCE=$SCRIPT_DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
    echo $SCRIPT_DIR
}

function __run_command()
{
    local run_in_container=${RUN_IN_CONTAINER:-"false"}
    local container_name=${RUN_IN_CONTAINER_NAME:-"myContainer"}
    case $run_in_container in
        "true" | 1)
            __docker_run_command "${container_name}" "$@"
            ;;
        *)
            "$@"
            ;;
    esac
}

function __docker_run_command()
{
    local container_name=$1
    shift;
    docker compose exec -T ${container_name} "$@"
}

function __keycloak_login()
{
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

    if [[ -f "${KEYCLOAK_TRUSTSTORE_FILE}" ]]; then
    __run_command /opt/keycloak/bin/kcadm.sh config truststore --trustpass ${KEYCLOAK_TRUSTSTORE_PASS} "${KEYCLOAK_TRUSTSTORE_VOL_MOUNT}/${KEYCLOAK_TRUSTSTORE_FILE_NAME}"
    fi

    __run_command /opt/keycloak/bin/kcadm.sh config credentials --server ${KEYCLOAK_SERVER_URL} --realm ${KEYCLOAK_REALM} --user ${KEYCLOAK_ADMIN_USERNAME} --password ${KEYCLOAK_ADMIN_PASSWORD}
}

COMMON_LOADED=1