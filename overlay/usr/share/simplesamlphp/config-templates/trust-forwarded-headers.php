<?php
// Adapted from: https://stackoverflow.com/questions/30036787/set-correct-remote-addr-in-php-fpm-called-from-apache
(function(array $options)
{
    if (! $options['trustForwardedHeaders']) {
        $forwardedHosts = isset($_SERVER['HTTP_X_FORWARDED_HOST']) ? explode('HTTP_X_FORWARDED_HOST', ',') : array();
        $proxyHosts = count($forwardedHosts);
        if ($proxyHosts == 0) {
            return;
        }
        $proxyIp = trim($forwardedHosts[$proxyHosts-1]);
        if ( ! in_array($proxyIp, $options['trustedProxiesIps']) ) {
            return;
        }
    }

    $allowedHeaders = array(
        'HTTP_X_FORWARDED_PROTO' => array('HTTPS', function($headerValue){ return $headerValue == "https" ? "on" : null;}),
        'HTTP_X_FORWARDED_HOST' => 'HTTP_HOST',
        'HTTP_X_FORWARDED_PORT' => 'SERVER_PORT',
        'HTTP_X_REAL_IP' => 'REMOTE_ADDR',
        'HTTP_X_FORWARDED_SERVER' => 'SERVER_NAME',
        'HTTP_X_FORWARDED_PORT' => 'SERVER_PORT',
    );

    foreach($allowedHeaders as $header => $serverVar) {
        if(isset($_SERVER[$header])) {
            $varName = $serverVar;
            if (is_array($serverVar)) {
                $varName = $serverVar[0];
            }

            if(isset($_SERVER[$varName])) {
                $_SERVER["ORIGINAL_$varName"] = $_SERVER[$varName];
            }

            $varValue = $_SERVER[$header];
            if (is_array($serverVar)) {
                $varValue = $serverVar[1]($varValue);
            }
            $_SERVER[$varName] = $varValue;
        }
    }
})([
    'trustForwardedHeaders' => false,
    'trustedProxiesIps' => ['127.1.1.1'],
]);