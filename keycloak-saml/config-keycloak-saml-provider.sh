#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

KEYCLOAK_SERVER_URL="http://0.0.0.0:8080"
KEYCLOAK_REALM="master"
KEYCLOAK_ADMIN_USERNAME="admin"
KEYCLOAK_ADMIN_PASSWORD="password"

/opt/keycloak/bin/kcadm.sh config credentials --server ${KEYCLOAK_SERVER_URL} --realm ${KEYCLOAK_REALM} --user ${KEYCLOAK_ADMIN_USERNAME} --password ${KEYCLOAK_ADMIN_PASSWORD}
/opt/keycloak/bin/kcadm.sh create identity-provider/instances -r ${KEYCLOAK_REALM} -s alias=saml \
-s providerId=saml \
-s enabled=true \
-s displayName="SAML Limesurvey"