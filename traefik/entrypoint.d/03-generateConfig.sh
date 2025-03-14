#!/usr/bin/env sh
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

if [[ ! -f "/usr/bin/openssl" ]]; then
    apk update
    apk add openssl
    rm -rf /var/cache/apk/*
fi

: ${TRAEFIK_PASSWORD:=password}
: ${TRAEFIK_CERTS:=/etc/traefik/ssl/certs}

apr1_passwd=$(openssl passwd -apr1 "${TRAEFIK_PASSWORD}")
mkdir -p /etc/traefik/conf/dynamic-config;
cat << EOF > /etc/traefik/conf/dynamic-config/file-provider.toml
[[tls.certificates]]
    certFile = "${TRAEFIK_CERTS}/traefik-fullchain.pem"
    keyFile = "${TRAEFIK_CERTS}/traefik-key.pem"
    stores = ["default"]

[tls.stores]
    [tls.stores.default]
    [tls.stores.default.defaultCertificate]
        certFile = "${TRAEFIK_CERTS}/traefik-fullchain.pem"
        keyFile  = "${TRAEFIK_CERTS}/traefik-key.pem"

[tls.options]
    [tls.options.default]
    minVersion = "VersionTLS12"
    [tls.options.myTLSOptions]
    minVersion = "VersionTLS13"

[http.middlewares]
    [http.middlewares.dashboardAuth.basicAuth]
    # admin:${TRAEFIK_PASSWORD}
    users = [
        "admin:${apr1_passwd}"
    ]
    [http.middlewares.redirect-to-https.redirectScheme]
    scheme = "https"
    permanent = true
EOF
