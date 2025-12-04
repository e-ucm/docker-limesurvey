#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-false}" == "true" ]] && set -x
source "${SIMPLE_SCRIPT_DIR}/env.sh"

: ${KEYCLOAK_LOGIN_ON:=false}

function __keycloak_login() {
    if [[ ${KEYCLOAK_LOGIN_ON} = true ]]; then return; fi;
    if [[ ! -f "${SIMVA_TRUSTSTORE_FILE}" ]]; then
        if [[ -f "${SIMVA_ROOT_CA_FILE}" ]]; then
            keytool -importcert -trustcacerts -noprompt \
                -storepass "${SIMVA_TRUSTSTORE_PASSWORD}" \
                -alias "${SIMVA_TRUSTSTORE_CA_ALIAS}" \
                -keystore "${SIMVA_TRUSTSTORE_FILE}" \
                -file "${SIMVA_ROOT_CA_FILE}"
        fi
    fi

    if [[ -f "${SIMVA_TRUSTSTORE_FILE}" ]]; then
        "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh config truststore --trustpass ${SIMVA_TRUSTSTORE_PASSWORD} "/root/.keycloak/certs/$(basename "${SIMVA_TRUSTSTORE_FILE}")"
    fi
           
    # Now always login using the actual admin
    echo "--- Logging into Keycloak with the admin ---"
    "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh config credentials \
        --server "https://${SIMVA_SSO_HOST_SUBDOMAIN}.${SIMVA_EXTERNAL_DOMAIN}" \
        --realm "master" --user "${SIMVA_KEYCLOAK_ADMIN_USER}" \
        --password "${SIMVA_KEYCLOAK_ADMIN_PASSWORD}"

    export KEYCLOAK_LOGIN_ON=true

    echo "Keycloak admin login OK!"
}

function __list_keycloak_resources() {
    __keycloak_login
    if [[ $# -lt 1 ]]; then
        echo "keycloak resource path expected";
        exit 1;
    fi
    keycloak_resource=$1
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource fields expected";
        exit 1;
    fi
    fields=$1
    shift 1

    __keycloak_login
    "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh get $keycloak_resource -r ${SIMVA_SSO_REALM} --fields $fields
}

function __list_clients() {
    __list_keycloak_resources "clients" "id,clientId"
}

function __list_client_scopes() {
   __list_keycloak_resources "client-scopes" "id,name"
}

function __list_roles() {
   __list_keycloak_resources "roles" "id,name"
}

function __list_users() {
   __list_keycloak_resources "users" "id,username"
}

function __get_keycloak_resource() {
    if [[ $# -lt 1 ]]; then
        echo "keycloak resource path expected";
        exit 1;
    fi
    keycloak_resource=$1
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource 'id' expected";
        exit 1;
    fi
    id=$1

    __keycloak_login
    "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh get -r ${SIMVA_SSO_REALM} "$keycloak_resource/${id}"
}

function __get_client() {
    __get_keycloak_resource "clients" $@
}

function __get_client_scope() {
   __get_keycloak_resource "client-scopes" $@
}

function __get_role() {
   __get_keycloak_resource "roles" $@
}

function __get_user() {
   __get_keycloak_resource "users" $@
}

function __add_keycloak_resource() {
    if [[ $# -lt 1 ]]; then
        echo "keycloak resource path expected";
        exit 1;
    fi
    keycloak_resource=$1
    shift 1
    
    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource file expected";
        exit 1;
    fi
    keycloak_resource_file=$1
    shift 1
    __keycloak_login
    "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh create $keycloak_resource -r ${SIMVA_SSO_REALM} -f $keycloak_resource_file -i
}

function __add_client() {
    __add_keycloak_resource "clients" $@
}

function __add_client_scope() {
   __add_keycloak_resource "client-scopes" $@
}

function __add_role() {
   __add_keycloak_resource "roles" $@
}

function __add_user() {
   __add_keycloak_resource "users" $@
}

function __update_keycloak_resource() {
     if [[ $# -lt 1 ]]; then
        echo "keycloak resource path expected";
        exit 1;
    fi
    keycloak_resource=$1
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "Value for $keycloak_resource id expected";
        exit 1;
    fi
    endpointId=$1;
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource file expected";
        exit 1;
    fi
    keycloak_resource_file=$1
    shift 1
    __keycloak_login
    "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh update $keycloak_resource/$endpointId -r ${SIMVA_SSO_REALM} -f $keycloak_resource_file
}

function __update_client() {
    __update_keycloak_resource "clients" $@
}

function __update_realm() {
    if [[ $# -lt 1 ]]; then
        echo "Realm file expected";
        exit 1;
    fi
    keycloak_resource_file=$1
    shift 1

    __keycloak_login
    "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh update "realms/$SIMVA_SSO_REALM" -f $keycloak_resource_file
}

function __update_realm_with_params() {
    if [[ $# -lt 1 ]]; then
        echo "Params expecteds expected";
        exit 1;
    fi

    __keycloak_login
    "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh update "realms/$SIMVA_SSO_REALM" "$@"
}

function __update_client_scope() {
   __update_keycloak_resource "client-scopes" $@
}

function __update_role() {
   __update_keycloak_resource "roles" $@
}

function __update_user() {
   __update_keycloak_resource "users" $@
}

function __add_or_update_keycloak_resource() {
     if [[ $# -lt 1 ]]; then
        echo "keycloak resource path expected";
        exit 1;
    fi
    keycloak_resource=$1
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource field expected";
        exit 1;
    fi
    field=$1;
    shift 1
    fields=$field;

    if [[ $# -lt 1 ]]; then
        echo "Lookup $keycloak_resource field expected";
        exit 1;
    fi
    lookupField=$1;
    shift 1
    if [[ ! $lookupField == $field ]]; then 
        fields=$fields,$lookupField;
    fi

    if [[ $# -lt 1 ]]; then
        echo "Endpoint $keycloak_resource field expected";
        exit 1;
    fi
    endpointField=$1;
    shift 1
    if [[ ! $lookupField == $endpointField ]]; then 
        if [[ ! $field == $endpointField ]]; then 
            fields=$fields,$endpointField;
        fi
    fi

    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource local folder expected";
        exit 1;
    fi
    localFolder=$1;
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource docker folder expected";
        exit 1;
    fi
    dockerFolder=$1;
    shift 1

    tmp_clients="${SIMVA_CONFIG_HOME}/keycloak/simva-realm/${keycloak_resource//\//_}.json"
    __list_keycloak_resources $keycloak_resource $fields > $tmp_clients
    for file in $localFolder/*; do
        filename=$(basename "$file")
        id=$(cat $file | jq -e -c -r ".$lookupField")
        keycloak_resource_id=$(cat $file | jq -e -c -r ".$field")
        set +e
        present_keycloak_resource=$(cat "${tmp_clients}" | jq -e -c -r ".[] | select(.$lookupField == \"${id}\")")
        result=$?
        set -e
        if [[ $result -eq 0 ]]; then
            present_keycloak_resource_name=$(echo $present_keycloak_resource | jq -e -c -r ".$field")
            present_keycloak_resource_id=$(echo $present_keycloak_resource | jq -e -c -r ".$endpointField")
            echo "'${present_keycloak_resource_name}' $keycloak_resource already configured. Reload it..."
            __update_keycloak_resource $keycloak_resource $present_keycloak_resource_id "$dockerFolder/$filename"
        else
            echo "'${keycloak_resource_id}' $keycloak_resource not configured."
            __add_keycloak_resource $keycloak_resource "$dockerFolder/$filename"
        fi
    done
}

function __add_or_update_client() {
    __add_or_update_keycloak_resource "clients" "clientId" "id" "id" $@
}

function __add_or_update_client_scope() {
   __add_or_update_keycloak_resource "client-scopes" "name" "id" "id" $@
}

function __add_or_update_role() {
    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource local folder expected";
        exit 1;
    fi
    localFolder=$1;
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource docker folder expected";
        exit 1;
    fi
    dockerFolder=$1;
    shift 1

    __add_or_update_keycloak_resource "roles" "name" "name" "name" $localFolder $dockerFolder
    __keycloak_login
    for file in $localFolder/*; do
        composite=$(jq -c -r ".composite // false" "$file")
        if [[ "$composite" != "true" ]]; then continue; fi;
        rolename=$(jq -c -r ".name" "$file")
        composites=$(jq -c -r '.composites.realm // [] | join(" ")' "$file")  # Ensure empty array if not found
        roles=""
        for compose in $composites; do
            composedRole=$(__get_role_from_exact "name" "$compose")
            roles+="--rolename $compose "
        done
        echo "$roles"
        __keycloak_login
        "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh add-roles -r ${SIMVA_SSO_REALM} --rname $rolename $roles
        clients=$(jq -c -r '.composites.client // { "defaultClient": [] } | to_entries[] | "\(.key)=\(.value)"' "$file")
        for client in $clients; do
            clientid=$(echo "$client" | cut -d'=' -f1)     # Extract the clientid
            roles=$(echo "$client" | cut -d'=' -f2)        # Extract the rest as the role
            echo "Processing client: $clientid"
            roleTable=$(echo "$roles" | jq -c -r '. // [] | join(" ")')
            clientRoles=""
            for role in $roleTable; do
                clientRoles+="--rolename $role "
            done
            if [[ ! $clientRoles == "" ]]; then 
                echo $clientRoles
                __keycloak_login
                "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh add-roles -r ${SIMVA_SSO_REALM} --rname $rolename --cclientid $clientid $clientRoles
            fi
        done
    done
    role=$(__get_role_from_exact "name" "default-roles-${SIMVA_SSO_REALM}")
    echo $role
    roleid=$(echo $role | jq -e -c -r ".id")
    echo $roleid
    __update_realm_with_params -s defaultRole={\"id\":\"$roleid\"}
}

function __get_keycloak_resource_from_exact() {
    if [[ $# -lt 1 ]]; then
        echo "keycloak resource path expected";
        exit 1;
    fi
    keycloak_resource=$1
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource 'field' expected";
        exit 1;
    fi
    field=$1
    shift 1
    
    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource 'field $field value' expected";
        exit 1;
    fi
    value=$1

    __keycloak_login
    "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh get -r ${SIMVA_SSO_REALM} "$keycloak_resource" -q exact=true -q $field=$value | jq -e -c -r ".[] | select(.$field == \"${value}\")"
}

function __get_client_from_exact() {
    __get_keycloak_resource_from_exact "clients" $@
}

function __get_client_scope_from_exact() {
   __get_keycloak_resource_from_exact "client-scopes" $@
}

function __get_role_from_exact() {
   __get_keycloak_resource_from_exact "roles" $@
}

function __get_user_from_exact() {
   __get_keycloak_resource_from_exact "users" $@
}

function __add_or_update_keycloak_resource_from_exact() {
     if [[ $# -lt 1 ]]; then
        echo "keycloak resource path expected";
        exit 1;
    fi
    keycloak_resource=$1
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource field expected";
        exit 1;
    fi
    field=$1;
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "Lookup $keycloak_resource field expected";
        exit 1;
    fi
    lookupField=$1;
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "Endpoint $keycloak_resource field expected";
        exit 1;
    fi
    endpointField=$1;
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource local folder expected";
        exit 1;
    fi
    localFolder=$1;
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource docker folder expected";
        exit 1;
    fi
    dockerFolder=$1;
    shift 1

    for file in $localFolder/*; do
        filename=$(basename "$file")
        id=$(cat $file | jq -e -c -r ".$lookupField")
        keycloak_resource_id=$(cat $file | jq -e -c -r ".$field")
        set +e
        present_keycloak_resource=$(__get_keycloak_resource_from_exact $keycloak_resource $field $keycloak_resource_id);
        result=$?
        set -e
        if [[ $result -eq 0 ]]; then
            present_keycloak_resource_name=$(echo $present_keycloak_resource | jq -e -c -r ".$field")
            present_keycloak_resource_id=$(echo $present_keycloak_resource | jq -e -c -r ".$endpointField")
            echo "'${present_keycloak_resource_name}' $keycloak_resource already configured. Reload it..."
            __update_keycloak_resource $keycloak_resource $present_keycloak_resource_id "$dockerFolder/$filename"
        else
            echo "'${keycloak_resource_id}' $keycloak_resource not configured."
            __add_keycloak_resource $keycloak_resource "$dockerFolder/$filename"
        fi
    done
}


function __add_or_update_user() {
    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource local folder expected";
        exit 1;
    fi
    localFolder=$1;
    shift 1

    if [[ $# -lt 1 ]]; then
        echo "$keycloak_resource docker folder expected";
        exit 1;
    fi
    dockerFolder=$1;
    shift 1
    
    __add_or_update_keycloak_resource_from_exact "users" "username" "username" "id" $localFolder $dockerFolder
    for file in $localFolder/*; do
        username=$(jq -c -r ".username" "$file")
        realmRoles=$(jq -c -r '.realmRoles // [] | join(" ")' "$file")  # Ensure empty array if not found
        roles=""
        for role in $realmRoles; do
            composedRole=$(__get_role_from_exact "name" "$role")
            roles+="--rolename $role "
        done
        if [[ ! $roles == "" ]]; then 
            echo $roles
            __keycloak_login
            "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh add-roles -r ${SIMVA_SSO_REALM} --uusername $username $roles
        fi
        clients=$(jq -c -r '.clientRoles // { "defaultClient": [] } | to_entries[] | "\(.key)=\(.value)"' "$file")
        for client in $clients; do
            clientid=$(echo "$client" | cut -d'=' -f1)     # Extract the clientid
            roles=$(echo "$client" | cut -d'=' -f2)        # Extract the rest as the role
            echo "Processing client: $clientid"
            roleTable=$(echo "$roles" | jq -c -r '. // [] | join(" ")')
            clientRoles=""
            for role in $roleTable; do
                clientRoles+="--rolename $role "
            done
            if [[ ! $clientRoles == "" ]]; then 
                echo $clientRoles
                __keycloak_login
                "${SIMPLE_SCRIPT_DIR}/run-command.sh" /opt/keycloak/bin/kcadm.sh add-roles -r ${SIMVA_SSO_REALM} --uusername $username --cclientid $clientid $clientRoles
            fi
        done
    done
}