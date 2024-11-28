#!/usr/bin/env sh
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

: "${MKCERT_VERSION:=v1.4.4}"
: "${MKCERT_SHA256SUM:=6d31c65b03972c6dc4a14ab429f2928300518b26503f58723e532d1b0a3bbb52}"
: "${CAROOT:=/etc/traefik/ssl/ca}"
MKCERT_DOWNLOAD_URL="https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-linux-amd64"

if [[ ! -e "/usr/local/bin/mkcert" ]]; then
    # mkcert installation
    wget -O /tmp/mkcert -q ${MKCERT_DOWNLOAD_URL};
    echo "${MKCERT_SHA256SUM}  /tmp/mkcert" | sha256sum -c -w -s -;
    mv /tmp/mkcert /usr/local/bin;
    chmod +x /usr/local/bin/mkcert;
fi;

if [[ ! -e "${CAROOT}/rootCA.pem" ]]; then
    if [[ ! -d "${CAROOT}" ]]; then
        mkdir -p "${CAROOT}";
    fi;

    # generate ca
    mkdir -p ${CAROOT};
    mkcert --install;

    echo "Development CA certificate, beware !";
    cat $(mkcert -CAROOT)/rootCA.pem;
fi;
