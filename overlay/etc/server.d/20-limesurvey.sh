#!/usr/bin/env bash


function limesurvey_setup()
{
    if [[ ! -e "/etc/limesurvey/config.php" ]]; then
        echo >&2 "No config file in /etc/limesurvey Copying default config file..."
        #Copy default config file but also allow for the addition of attributes
        awk '/lime_/ && c == 0 { c = 1; system("cat") } { print }' application/config/config-sample-mysql.php > /etc/limesurvey/config.php <<'EOPHP'
            'attributes' => array(),
EOPHP
    fi

    if [[ -e "/var/www/html/application/config/config.php" ]] && [[ ! -L "/var/www/html/application/config/config.php" ]]; then
        rm /var/www/html/application/config/config.php
    fi

    if [[ ! -L "/var/www/html/application/config/config.php" ]]; then
        ln -s /etc/limesurvey/config.php /var/www/html/application/config/config.php
    fi

    if [[ ! -e "/var/www/html/plugins/index.html" ]]; then
        echo >&2 'Seems that /var/www/html/plugins was bind mounted, restoring files'
        (cd "/usr/share/limesurvey/plugins"; tar -cf - . 2> /dev/null) | ( tar -C /var/www/html/plugins -xpf - > /dev/null 2>&1)
    fi

    if [[ ! -e "/var/www/html/upload/readme.txt" ]]; then
        echo >&2 'Seems that /var/www/html/upload was bind mounted, restoring files'
        (cd "/usr/share/limesurvey/upload"; tar -cf - . 2> /dev/null) | ( tar -C /var/www/html/upload -xpf - > /dev/null 2>&1)
    fi

    if [[ ! -e "/var/www/html/tmp/index.html" ]]; then
        echo >&2 'Seems that /var/www/html/tmp was bind mounted, restoring files'
        (cd "/usr/share/limesurvey/tmp"; tar -cf - . 2> /dev/null) | ( tar -C /var/www/html/tmp -xpf - > /dev/null 2>&1)
    fi

    limesurvey_configure "/etc/limesurvey/config.php"
}

function limesurvey_configure()
{
    if [[ $# -lt 1 ]]; then
        echo >&2 'Expected config file path';
        return 1;
    fi

    local config_file="$1"

    if [ -z "$LIMESURVEY_DB_PASSWORD" ]; then
        echo >&2 'error: missing required LIMESURVEY_DB_PASSWORD environment variable'
        echo >&2 '  Did you forget to -e LIMESURVEY_DB_PASSWORD=... ?'
        echo >&2
        echo >&2 '  (Also of interest might be LIMESURVEY_DB_USER and LIMESURVEY_DB_NAME.)'
        exit 1
    fi

    function __limesurvey_set_config() {
        local config_file="$1"
        local key="$2"
        local value="$3"
        sed -i -r -e "/^\s*['\"]$(__sed_escape_lhs "$key")['\"]/s/>(\s*)(.*)/>\1$(__sed_escape_rhs "$value"),/g" "$config_file"

    }

    __limesurvey_set_config $config_file 'connectionString' "'mysql:host=$LIMESURVEY_DB_HOST;port=3306;dbname=$LIMESURVEY_DB_NAME;'"
    __limesurvey_set_config $config_file 'tablePrefix' "'$LIMESURVEY_TABLE_PREFIX'"
    __limesurvey_set_config $config_file 'username' "'$LIMESURVEY_DB_USER'"
    __limesurvey_set_config $config_file 'password' "'$LIMESURVEY_DB_PASSWORD'"
    __limesurvey_set_config $config_file 'urlFormat' "'path'"
    __limesurvey_set_config $config_file 'showScriptName' "false"
    __limesurvey_set_config $config_file 'debug' "$LIMESURVEY_DEBUG"
    __limesurvey_set_config $config_file 'debugsql' "$LIMESURVEY_SQL_DEBUG"

    if [[ -n "$MYSQL_SSL_CA" ]]; then
        __limesurvey_set_config $config_file 'attributes' "array(PDO::MYSQL_ATTR_SSL_CA => '\/var\/www\/html\/$MYSQL_SSL_CA', PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false)"
    fi

    if [[ -n "$LIMESURVEY_USE_INNODB" ]]; then
        #If you want to use INNODB - remove MyISAM specification from LimeSurvey code
        sed -i "/ENGINE=MyISAM/s/\(ENGINE=MyISAM \)//1" application/core/db/MysqlSchema.php
    fi


    chown www-data:www-data -R tmp 
    mkdir -p upload/surveys
    chown www-data:www-data -R upload 
    chown www-data:www-data -R application/config

    DBSTATUS=$(TERM=dumb php -- "$LIMESURVEY_DB_HOST" "$LIMESURVEY_DB_USER" "$LIMESURVEY_DB_PASSWORD" "$LIMESURVEY_DB_NAME" "$LIMESURVEY_TABLE_PREFIX" "$MYSQL_SSL_CA" <<'EOPHP'
<?php
    // database might not exist, so let's try creating it (just to be safe)

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

    if (!$con->query('CREATE DATABASE IF NOT EXISTS `' . $con->real_escape_string($argv[4]) . '`')) {
        fwrite($stderr, "\n" . 'MySQL "CREATE DATABASE" Error: ' . $con->error . "\n");
        $con->close();
        exit(1);
    }

    $con->select_db($con->real_escape_string($argv[4]));

    $inst = $con->query("SELECT * FROM `" . $con->real_escape_string($argv[5]) . "users" . "`");

    $con->close();

    if ($inst->num_rows > 0) {
        exit("DBEXISTS");
    } else {
        exit(0);
    }
EOPHP
)


    if [[ "$DBSTATUS" != "DBEXISTS" ]] &&  [[ -n "$LIMESURVEY_ADMIN_USER" ]] && [[ -n "$LIMESURVEY_ADMIN_PASSWORD" ]]; then
        echo >&2 'Database not yet populated - installing Limesurvey database'
        php application/commands/console.php install "$LIMESURVEY_ADMIN_USER" "$LIMESURVEY_ADMIN_PASSWORD" "$LIMESURVEY_ADMIN_NAME" "$LIMESURVEY_ADMIN_EMAIL" verbose
        echo >&2 'Configure default global settings'
        limesurvey_global_configuration
    fi

    if [[ -n "$LIMESURVEY_ADMIN_USER" ]] && [[ -n "$LIMESURVEY_ADMIN_PASSWORD" ]]; then
        echo >&2 'Updating password for admin user'
        php application/commands/console.php resetpassword "$LIMESURVEY_ADMIN_USER" "$LIMESURVEY_ADMIN_PASSWORD"
    fi

}

function limesurvey_global_configuration()
{

    DBSTATUS=$(TERM=dumb php -- "$LIMESURVEY_DB_HOST" "$LIMESURVEY_DB_USER" "$LIMESURVEY_DB_PASSWORD" "$LIMESURVEY_DB_NAME" "$LIMESURVEY_TABLE_PREFIX" "$MYSQL_SSL_CA" <<'EOPHP'
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

    $settings = array(
        'rpc_publish_api' => '1',
        'RPCInterface' => 'json',
        'force_ssl' => 'on'
    );

    $query = "INSERT INTO `".$argv[5]."settings_global` (`stg_name`, `stg_value`) VALUES (?, ?) ";

    $stmt = $con->prepare($query);

    if (!$stmt->bind_param("ss", $setting_name, $setting_value)) {
        fwrite($stderr, "\n" . 'MySQL "Global configuration" error: ' . $con->error . "\n");
        $con->close();
        exit(1);
    }

    $con->query("START TRANSACTION");
    foreach ($settings as $setting_name => $setting_value) {
        if (!$stmt->execute()) {
            fwrite($stderr, "\n" . 'MySQL "Global configuration" error: ' . $con->error . "\n");
            $con->close();
            exit(1);
        }
    }
    $stmt->close();
    $con->query("COMMIT");

    $con->close();

    fwrite($stderr, "\n" . 'MySQL "Global settings configured" updated'. "\n");

    exit(0);
EOPHP
)

}

limesurvey_setup