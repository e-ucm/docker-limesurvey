#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x

: ${RUN_IN_CONTAINER:=false}
: ${RUN_IN_CONTAINER_NAME:=}
: ${RUN_IN_AS_SPECIFIC_USER:=}
: ${RUN_IN_FLAG_UI:=false}

function __docker_run_command()
{
    local container_name=$1
    shift;
    local specific_user=$1
    shift;
    local flag_ui=$1
    shift;
    if [[ ! ${specific_user} == "" ]]; then
        docker compose exec --user $specific_user $flag_ui ${container_name} "$@"
    else 
        docker compose exec $flag_ui ${container_name} "$@"
    fi
}

run_in_container=$RUN_IN_CONTAINER
case $run_in_container in
    "true" | 1)
        container_name=$RUN_IN_CONTAINER_NAME
        specific_user=$RUN_IN_AS_SPECIFIC_USER
        flag_ui=""
        case $RUN_IN_FLAG_UI in 
            "true" | 1) 
                flag_ui="-it"
                ;;
            *)
                flag_ui="-T"
                ;;
        esac
        __docker_run_command "${container_name}" "${specific_user}" "${flag_ui}" "$@"
        ;;
    *)
        "$@"
        ;;
esac