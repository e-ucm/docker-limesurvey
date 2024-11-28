#!/usr/bin/env sh
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

: "${TRAEFIK_CERTS:=/etc/traefik/ssl/certs}"
: "${EXTERNAL_DOMAIN:=external.test}"

if [[ ! -e "${TRAEFIK_CERTS}/traefik-key.pem" ]]; then
    if [[ ! -d "${TRAEFIK_CERTS}" ]]; then
        # generate "localhost certificate"
        mkdir -p ${TRAEFIK_CERTS};
    fi;

    mkcert  \
        -cert-file ${TRAEFIK_CERTS}/traefik.pem \
        -key-file ${TRAEFIK_CERTS}/traefik-key.pem \
        "*.${EXTERNAL_DOMAIN}" \
        "localhost" "127.0.0.1" "::1";
    cp ${TRAEFIK_CERTS}/traefik.pem ${TRAEFIK_CERTS}/traefik-fullchain.pem;
    cat $(mkcert -CAROOT)/rootCA.pem >> ${TRAEFIK_CERTS}/traefik-fullchain.pem;
fi;