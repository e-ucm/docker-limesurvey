#!/usr/bin/env bash

function limesurvey_saml_setup()
{

    DBSTATUS=$(TERM=dumb php -- "$LIMESURVEY_DB_HOST" "$LIMESURVEY_DB_USER" "$LIMESURVEY_DB_PASSWORD" "$LIMESURVEY_DB_NAME" "$LIMESURVEY_TABLE_PREFIX" "$MYSQL_SSL_CA" "$LIMESURVEY_SAML_PLUGIN_NAME" "$LIMESURVEY_SAML_PLUGIN_VERSION" "$LIMESURVEY_SAML_PLUGIN_AUTH_SOURCE" "$LIMESURVEY_SAML_PLUGIN_UID_MAPPING" <<'EOPHP'
<?php
    error_reporting(E_ERROR | E_PARSE);

    $stderr = fopen('php://stderr', 'w');

    list($host, $socket) = explode(':', $argv[1], 2);
    $port = 0;
    if (is_numeric($socket)) {
        $port = (int) $socket;
        $socket = null;
    }

    $maxTries = 10;
    do {
        $con = mysqli_init();
        if (isset($argv[6]) && !empty($argv[6])) {
            mysqli_ssl_set($con,NULL,NULL,"/var/www/html/" . $argv[6],NULL,NULL);
        }
        $mysql = mysqli_real_connect($con,$host, $argv[2], $argv[3], '', $port, $socket, MYSQLI_CLIENT_SSL_DONT_VERIFY_SERVER_CERT);
            if (!$mysql) {
                fwrite($stderr, "\n" . 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
                --$maxTries;
                if ($maxTries <= 0) {
                        exit(1);
                }
                sleep(3);
            }
    } while (!$mysql);

    $con->select_db($con->real_escape_string($argv[4]));

    $res = $con->query("SELECT 1 FROM `".$con->real_escape_string($argv[5])."plugins` WHERE `name` = '".$con->real_escape_string($argv[7])."'");

    if ($res !== false && $res->num_rows > 0) {
        fwrite($stderr, "\n" . 'MySQL "AuthSAML plugin" already installed'. "\n");
        $res->free();
        $con->close();
        exit(0);
    }

    if (!$con->query("INSERT INTO `".$con->real_escape_string($argv[5])."plugins` (`name`, `plugin_type`, `active`, `priority`, `version`, `load_error`, `load_error_message`) VALUES ('".$con->real_escape_string($argv[7])."', 'user', 1, 0, '".$con->real_escape_string($argv[8])."', NULL, NULL)")) {
        fwrite($stderr, "\n" . 'MySQL "Activate AuthSAML plugin" error: ' . $con->error . "\n");
        $con->close();
        exit(1);
    }

    $last_plugin_id = $con->insert_id;

    $settings = array(
        array('simplesamlphp_path', '"\\/usr\\/share\\/simplesamlphp"'),
        array('simplesamlphp_logo_path', 'null'),
        array('simplesamlphp_cookie_session_storage', '"1"'),
        array('saml_authsource', '"'.$con->real_escape_string($argv[9]).'"'),
        array('saml_uid_mapping', '"'.$con->real_escape_string($argv[10]).'"'),
        array('saml_mail_mapping', '"mail"'),
        array('saml_group_mapping', '"member"'),
        array('user_access_group', '""'),
        array('saml_name_mapping', '"cn"'),
        array('auto_create_users', '"1"'),
        array('auto_update_users', '"1"'),
        array('force_saml_login', '""'),
        array('authtype_base', '"Authdb"'),
        array('storage_base', '"DbStorage"'),
        array('logout_redirect', '"\\/admin"'),
        array('allowInitialUser', '""'),
        array('auto_create_labelsets', '""'),
        array('auto_create_participant_panel', '""'),
        array('auto_create_settings_plugins', '""'),
        array('auto_create_surveys', '"1"'),
        array('auto_create_templates', '""'),
        array('auto_create_user_groups', '""'),
    );

    $query = "INSERT INTO `".$argv[5]."plugin_settings` (`plugin_id`, `model`, `model_id`, `key`, `value`) VALUES (?, NULL, NULL, ?, ?)";

    $stmt = $con->prepare($query);

    if (!$stmt->bind_param("iss", $last_plugin_id, $key, $value)) {
        fwrite($stderr, "\n" . 'MySQL "Configure AuthSAML plugin" error: ' . $con->error . "\n");
        $con->close();
        exit(1);
    }

    $con->query("START TRANSACTION");
    foreach ($settings as $value) {
        list($key, $value) = $value;
        if (!$stmt->execute()) {
            fwrite($stderr, "\n" . 'MySQL "Configure AuthSAML plugin" error: ' . $con->error . "\n");
            $con->close();
            exit(1);
        }
    }
    $stmt->close();
    $con->query("COMMIT");

    $con->close();

    fwrite($stderr, "\n" . 'MySQL "AuthSAML plugin" installed'. "\n");

    exit(0);
EOPHP
)

}

limesurvey_saml_setup