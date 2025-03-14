: ${ENV_LOADED:=0}
[[ "$ENV_LOADED" -eq 1 ]] && return

if [[ -f ".env" ]]; then
    export "$(grep -v '^#' .env | xargs -d '\n')"
fi

: ${EXTERNAL_DOMAIN:="external.test"}
: ${INTERNAL_DOMAIN:="internal.test"}

: ${KEYCLOAK_SERVER_HOST:="sso.${EXTERNAL_DOMAIN}"}
: ${KEYCLOAK_SERVER_URL:="https://${KEYCLOAK_SERVER_HOST}"}
: ${KEYCLOAK_REALM:="master"}
: ${KEYCLOAK_ADMIN_USERNAME:="admin"}
: ${KEYCLOAK_ADMIN_PASSWORD:="password"}
: ${KEYCLOAK_TEST_CLIENT:="sp-test"}
: ${KEYCLOAK_ACCESS_TOKEN:=""}
: ${SIMPLESAMLPHP_SP_METADATA_URL:="https://simplesamlphp.${EXTERNAL_DOMAIN}/simplesamlphp/module.php/saml/sp/metadata/${KEYCLOAK_TEST_CLIENT}"}

: ${KEYCLOAK_IN_CONTAINER:="false"}
: ${KEYCLOAK_CONTAINER_NAME:="keycloak"}

: ${KEYCLOAK_TRUSTSTORE_DIR:="$(dirname ${SIMPLE_SCRIPT_DIR})/data/simva"}
: ${KEYCLOAK_TRUSTSTORE_VOL_MOUNT:="/simva"}
: ${KEYCLOAK_TRUSTSTORE_FILE_NAME:="truststore.jks"}
: ${KEYCLOAK_TRUSTSTORE_FILE:="${KEYCLOAK_TRUSTSTORE_DIR}/${KEYCLOAK_TRUSTSTORE_FILE_NAME}"}
: ${KEYCLOAK_TRUSTSTORE_PASS:="secret"}
: ${KEYCLOAK_CA_ALIAS:="KC_Alias"}
: ${KEYCLOAK_CA_FILE:="$(dirname "${SIMPLE_SCRIPT_DIR}")/data/traefik/ssl/ca/rootCA.pem"}

ENV_LOADED=1