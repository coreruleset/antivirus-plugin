# OWASP ModSecurity Core Rule Set - Antivirus Plugin

## Description

This is a plugin that brings antivirus support to CRS.

The plugin is able to scan these parts of the request:

 * uploaded file
 * body (disabled by default, see below)

Communication with antivirus software is performed using a bundled Lua script
and has following characteristics:

 * no external programs or tools are executed (no forking etc.)
 * no need for extended permissions
 * antivirus software does not need to run with extended permissions to access
   scanned data

Please note, that the antivirus plugin will not raise anomaly score, but block a
request carrying a virus immediately.

Currently, only ClamAV antivirus is supported but we are planning to add support
for other antivirus software as well.

## Prerequisities

 * ModSecurity compiled with Lua support
 * LuaSocket library
 * ModSecurity `SecTmpSaveUploadedFiles` directive is `On` or
   `SecUploadKeepFiles` directive is set to either `RelevantOnly` or `On`

## How to determine whether you have Lua support in ModSecurity

Most modern distro packages come with Lua support compiled in. If you are unsure, or if you get odd error messages (e.g. `EOL found`) chances are you are unlucky. To be really sure look for ModSecurity announce Lua support when launching your web server:

```
... ModSecurity for Apache/2.9.5 (http://www.modsecurity.org/) configured.
... ModSecurity: APR compiled version="1.7.0"; loaded version="1.7.0"
... ModSecurity: PCRE compiled version="8.39 "; loaded version="8.39 2016-06-14"
... ModSecurity: LUA compiled version="Lua 5.3"
...
```

If this line is missing, then you are probably stuck without Lua. Check out the documentation at [coreruleset.org](https://coreruleset.org/docs) to learn how to get Lua support for your installation.

## LuaSocket library installation

LuaSocket library should be part of your linux distribution. Here is an example
of installation on Debian linux:  
`apt install lua-socket`

## Plugin installation

For full and up to date instructions for the different available plugin
installation methods, refer to [How to Install a Plugin](https://coreruleset.org/docs/configuring/plugins/#how-to-install-a-plugin)
in the official CRS documentation.

## Configuration

All settings can be done in file `plugins/antivirus-config.conf` which
must be created by copying or renamig file `plugins/antivirus-config.conf.example`:  
`cp plugins/antivirus-config.conf.example plugins/antivirus-config.conf`

### Main configuration

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
`curl http://localhost --form "data=@eicar.com"`

Using default CRS configuration, this request should end with status 403 with
the following message in the log:
`ModSecurity: Access denied with code 403 (phase 2). String match "{HEX}EICAR.TEST.3.UNOFFICIAL" at TX:antivirus-plugin_virus_name. [file "/path/plugins/antivirus-before.conf"] [line "11"] [id "9502110"] [msg "Virus {HEX}EICAR.TEST.3.UNOFFICIAL found in uploaded file eicar.com."] [data "Virus {HEX}EICAR.TEST.3.UNOFFICIAL found in uploaded file eicar.com."] [severity "CRITICAL"] [ver "antivirus-plugin/1.0.0"] [tag "capec/1000/262/441/442"] [hostname "localhost"] [uri "/"] [unique_id "Yefjb9gVcLh21zSVoqRv5wAAAFs"]`

Get eicar test file from [https://secure.eicar.org/eicar.com](https://secure.eicar.org/eicar.com).

## Virus signatures

Any antivirus solution is useless without good virus signatures. Below is a list
of virus signatures suitable for protection of web applications.

| *Antivirus Software* | *URL* | *Type* | *Note* |
|----------------------|-------|--------|--------|
| ClamAV               | https://www.rfxn.com/projects/linux-malware-detect/ | PHP malware | free of charge |
| ClamAV               | https://malware.expert/signatures/ | PHP malware | commercial |

## License

Copyright (c) 2021-2022 OWASP ModSecurity Core Rule Set project. All rights reserved.

The OWASP ModSecurity Core Rule Set and its official plugins are distributed
under Apache Software License (ASL) version 2. Please see the enclosed LICENSE
file for full details.
