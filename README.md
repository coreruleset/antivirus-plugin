# OWASP ModSecurity Core Rule Set - Antivirus Plugin

## Description

This is a plugin that brings antivirus support to CRS. 

The plugin is able to scan these parts of the request:

 * uploaded file
 * body (disabled by default, see below)

Communication with antivirus software is performed using a bundled Lua script and
has following characteristics:

 * no external programs or tools are executed (no forking etc.)
 * no need for extended permissions
 * antivirus software does not need to run with extended permissions to access
   scanned data

Please note, that the antivirus plugin will not raise anomaly score, but block a request
carrying a virus immediately.

Currently, only ClamAV antivirus is supported but we are planning to add support
for other antivirus software as well.

## Prerequisities

 * CRS version 3.4 or newer (or see "Preparation for older installations" below)
 * ModSecurity compiled with Lua support
 * lua-socket library
 * ModSecurity `SecTmpSaveUploadedFiles` directive is `On` or
   `SecUploadKeepFiles` directive is set to either `RelevantOnly` or `On`

## Installation

Copy all files from `plugins` directory into the `plugins` directory of your OWASP
ModSecurity Core Rule Set (CRS) installation.


### Preparation for older installations

* Create a folder named `plugins` in your existing CRS installation. That folder is meant to be on the same level as the `rules` folder. So there is your `crs-setup.conf` file and next to it the two folders `rules` and `plugins`.
* Update your CRS rules include to follow this pattern:

```
<IfModule security2_module>
 Include modsecurity.d/owasp-modsecurity-crs/crs-setup.conf

 Include modsecurity.d/owasp-modsecurity-crs/plugins/*-before.conf
 Include modsecurity.d/owasp-modsecurity-crs/rules/*.conf
 Include modsecurity.d/owasp-modsecurity-crs/plugins/*-after.conf

</IfModule>
```

_Your exact config may look a bit different, namely the paths. The important part is to accompany the rules-include with two plugins-includes before and after like above. Adjust the paths accordingly._

## Configuration

All settings can be done in file `plugins/antivirus-config-before.conf`.

### Main configuration

#### tx.antivirus-plugin_enable

This setting can be used to disable or enable the whole plugin.

Values:
 * 0 - disable plugin
 * 1 - enable plugin

Default value: 1
 
#### tx.antivirus-plugin_scan_request_body

This setting can be used to disable or enable antivirus scanning of request
bodies (REQUEST_BODY variable). Be carefull while enabling this feature as it
may use lots of system resources (depends on your usecase and environment).

Values:
 * 0 - disable antivirus scanning of request bodies
 * 1 - enable antivirus scanning of request bodies

Default value: 0

#### tx.antivirus-plugin_max_data_size_bytes

Maximum data size, in bytes, which are scanned. If data are bigger, the request
is allowed and error is logged into web server error log.

Default value: 1048576

#### tx.antivirus-plugin_network_timeout_seconds

Timeout, in seconds, for connection to antivirus. If this timeout is reached,
the request is allowed and error is logged into web server error log.

Default value: 2

### ClamAV configuration

#### tx.antivirus-plugin_clamav_connect_type

Connection to ClamAV antivirus can be done either by unix socket file or
TCP/IP.

Values:
 * socket - connect using unix socket file
 * tcp - connect using TCP/IP

Default value: socket

#### tx.antivirus-plugin_clamav_socket_file

You need to set full path to the unix socket file if
`tx.antivirus-plugin_clamav_connect_type` is set to `socket`.

Default value: /var/run/clamav/clamd.ctl

#### tx.antivirus-plugin_clamav_address

You need to set IP address or hostname if
`tx.antivirus-plugin_clamav_connect_type` is set to `tcp`.

Default value: 127.0.0.1

#### tx.antivirus-plugin_clamav_port

You need to set port if `tx.antivirus-plugin_clamav_connect_type` is set to
`tcp`.

Default value: 3310

#### tx.antivirus-plugin_clamav_chunk_size_bytes

Data are not send all at once into ClamAV but are splitted into chunks. Using
this setting, you can set the chunk size, in bytes. Make sure that this setting
does not exceed `StreamMaxLength` as defined in ClamAV configuration file
`clamd.conf`.

Default value: 4096

## Testing

After configuration, antivirus protection should be tested, for example, using:  
curl http://localhost --form "data=@eicar.com"

Get eicar test file from [https://secure.eicar.org/eicar.com](https://secure.eicar.org/eicar.com).

## Virus signatures

Any antivirus solution is useless without good virus signatures. Below is a list
of virus signatures suitable for protection of web applications.

| *Antivirus Software* | *URL* | *Type* | *Note* |
|----------------------|-------|--------|--------|
| ClamAV               | https://www.rfxn.com/projects/linux-malware-detect/ | PHP malware | free of charge |
| ClamAV               | https://malware.expert/signatures/ | PHP malware | commercial

## License

Copyright (c) 2021 OWASP ModSecurity Core Rule Set project. All rights reserved.

The OWASP ModSecurity Core Rule Set and its official plugins are distributed
under Apache Software License (ASL) version 2. Please see the enclosed LICENSE
file for full details.
