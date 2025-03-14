<?php

require_once(__DIR__ . '/lib/_autoload.php');

use SimpleSAML\Utils;
use SimpleSAML\Metadata\SAMLParser;
use Symfony\Component\VarExporter\VarExporter;

function usage()
{
    fwrite(STDERR, "Usage: '.$args[0] . ' [-h | --help] -f | --file\n\n");
    fwrite(STDERR, "Converts SAML2 XML metadata to the PHP code used by SimpleSAMLphp. If -f or --file are\n");
    fwrite(STDERR, "not provided stdin it is used as metadata source.\n\n");
    fwrite(STDERR, "Options:\n");
    fwrite(STDERR, "\t-f metadata-file, --file=metadata-file\n");
    fwrite(STDERR, "\t\tReads the metadata from the provided file.\n");
    exit(1);
}

/**
 * Metadata converter
 *
 * @param string metadataFile to convert
 *
 * @see https://github.com/simplesamlphp/simplesamlphp/blob/master/modules/admin/lib/Controller/Federation.php
 */
function metadataConverter(string $metadataFile)
{
    putenv("SIMPLESAMLPHP_CONFIG_DIR=/etc/simplesamlphp");
    // The metadata global variable will be filled with the metadata we extract
    $metaloader = new \SimpleSAML\Module\metarefresh\MetaLoader();
    $source = ['src' => $metadataFile];
    $metaloader->loadSource($source);
    $metaloader->dumpMetadataStdOut();
}

// Script example.php
$shortopts  = "hf:";

$longopts  = array(
    "file:",
    "help",
);
$options = getopt($shortopts, $longopts);

if (isset($options['h']) || isset($options['help']) ) {
    usage();
}

$metadataFile = '';
$temp = null;
if ( isset($options['f']) ) {
    $metadataFile = $options['f'];
} else if ( isset($options['file']) ) {
    $metadataFile = $options['file'];
} else {
    fwrite(STDERR, "Reading metadata from stdin\n");
    $xmldata = file_get_contents('php://stdin');
    $temp = tmpfile();
    fwrite($temp, $xmldata);
    $metadataFile = stream_get_meta_data($temp)['uri'];
}

metadataConverter($metadataFile);
if ($temp != null) {
    fclose($temp);
}