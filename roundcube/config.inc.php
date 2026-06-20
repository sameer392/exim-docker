<?php

/* Local configuration for Roundcube Webmail */

// ----------------------------------
// IMAP
// ----------------------------------
// The IMAP host (and optionally port number) chosen to perform the log-in.
// Leave blank to show a textbox at login, give a list of hosts
// to display a pulldown menu or set one host as string.
// Enter hostname with prefix ssl:// to use Implicit TLS, or use
// prefix tls:// to use STARTTLS.
// If port number is omitted it will be set to 993 (for ssl://) or 143 otherwise.
// Supported replacement variables:
// %n - hostname ($_SERVER['SERVER_NAME'])
// %t - hostname without the first part
// %d - domain (http hostname $_SERVER['HTTP_HOST'] without the first part)
// %s - domain name after the '@' from e-mail address provided at login screen
// For example %n = mail.domain.tld, %t = domain.tld
// WARNING: After hostname change update of mail_host column in users table is
//          required to match old user data records with the new host.
$config['imap_host'] = 'ssl://dovecot-mailserver:31993';

// ----------------------------------
// SMTP
// ----------------------------------
// SMTP server host (and optional port number) for sending mails.
// Enter hostname with prefix ssl:// to use Implicit TLS, or use
// prefix tls:// to use STARTTLS.
// If port number is omitted it will be set to 465 (for ssl://) or 587 otherwise.
// Supported replacement variables:
// %h - user's IMAP hostname
// %n - hostname ($_SERVER['SERVER_NAME'])
// %t - hostname without the first part
// %d - domain (http hostname $_SERVER['HTTP_HOST'] without the first part)
// %z - IMAP domain (IMAP hostname without the first part)
// For example %n = mail.domain.tld, %t = domain.tld
// To specify different SMTP servers for different IMAP hosts provide an array
// of IMAP host (no prefix or port) and SMTP server e.g. ['imap.example.com' => 'smtp.example.net']
$config['smtp_host'] = 'tls://exim-mailserver:587';

// Database configuration
$config['db_dsnw'] = 'mysql://roundcube:roundcube_pass@db:3306/roundcubemail';

// IMAP socket context options
// See https://php.net/manual/en/context.ssl.php
// The example below enables server certificate validation
//$config['imap_conn_options'] = [
//  'ssl'         => [
//     'verify_peer'  => true,
//     'verify_depth' => 3,
//     'cafile'       => '/etc/openssl/certs/ca.crt',
//   ],
// ];
// Note: These can be also specified as an array of options indexed by hostname
$config['imap_conn_options'] = array (
  'ssl' => 
  array (
    'verify_peer' => false,
    'verify_peer_name' => false,
    'allow_self_signed' => true,
  ),
);

// IMAP connection timeout, in seconds. Default: 0 (use default_socket_timeout)
$config['imap_timeout'] = 15;

// SMTP AUTH type (DIGEST-MD5, CRAM-MD5, LOGIN, PLAIN or empty to use
// best server supported one)
$config['smtp_auth_type'] = 'LOGIN';

// SMTP socket context options
// See https://php.net/manual/en/context.ssl.php
// The example below enables server certificate validation, and
// requires 'smtp_timeout' to be non zero.
// $config['smtp_conn_options'] = [
//     'ssl' => [
//         'verify_peer'  => true,
//         'verify_depth' => 3,
//         'cafile'       => '/etc/openssl/certs/ca.crt',
//     ],
// ];
// Note: These can be also specified as an array of options indexed by hostname
$config['smtp_conn_options'] = array (
  'ssl' => 
  array (
    'verify_peer' => false,
    'verify_peer_name' => false,
  ),
);

// Support URL
$config['support_url'] = '';

// Logging
$config['log_dir'] = 'logs/';

// Location of temporary saved files such as attachments and cache files
// must be writeable for the user who runs PHP process (Apache user if mod_php is being used)
$config['temp_dir'] = '/tmp/roundcube-temp';

// Security
$config['des_key'] = '9VowK5N2qSylHA1E6IBIc9sx';

// Encryption algorithm. You can use any method supported by OpenSSL.
// Default is set for backward compatibility to DES-EDE3-CBC,
// but you can choose e.g. AES-256-CBC which we consider a better choice.
$config['cipher_method'] = 'AES-256-CBC';

// Product name
$config['product_name'] = 'Webmail';

// Specifies the full path of the original HTTP request, either as a real path or
// $_SERVER field name. This might be useful when Roundcube runs behind a reverse
// proxy using a subpath. This is a path part of the URL, not the full URL!
// The reverse proxy config can specify a custom header (e.g. X-Forwarded-Path) containing
// the path under which Roundcube is exposed to the outside world (e.g. /rcube/).
// This header value is then available in PHP with $_SERVER['HTTP_X_FORWARDED_PATH'].
// By default the path comes from  'REDIRECT_SCRIPT_URL', 'SCRIPT_NAME' or 'REQUEST_URI',
// whichever is set (in this order).
$config['request_path'] = '/';

// Plugins
$config['plugins'] = ['archive', 'zipdownload'];

// Language
$config['language'] = 'en_US';

// Enable spellcheck
$config['enable_spellcheck'] = true;

// Timezone
$config['timezone'] = 'Asia/Kolkata';

// Enable user preferences
$config['user_preferences'] = true;

// Enable caching
$config['enable_caching'] = true;

$config['message_cache_lifetime'] = '10d';

// Enable message threading
$config['enable_threading'] = true;

// Override Docker config - our settings come AFTER the include
$config['imap_host'] = 'ssl://dovecot-mailserver:31993';
$config['smtp_host'] = 'tls://exim-mailserver:587';

// Server saves SMTP copies to Sent; avoid duplicate from Roundcube IMAP append.
$config['smtp_save_to_sent'] = false;

// Behind nginx reverse proxy on port 80
$config['reverse_proxy'] = true;
