#!/usr/bin/env sh
set -eo pipefail
[[ "${DEBUG}" == "true" ]] && set -x

: "${TRAEFIK_CONFIG:=/etc/traefik}"

for dir in \
    "${TRAEFIK_CONFIG}/conf" \
    "${TRAEFIK_CONFIG}/ssl/ca" \
    "${TRAEFIK_CONFIG}/ssl/certs" \
; do \
    mkdir -p ${dir}; \
done; \

for file in $(find /etc/entrypoint/entrypoint.d -iname \*.sh | sort)
do
  source ${file}
done

exec /entrypoint.sh "$@"