#!/usr/bin/python

# File to hold constants used by various I2 scripts
# Author: Dan Bracey 5/30/08
# Revision History:
# 5/30/08 -- 1.000 -- debracey -- Initial Creation

# ANSI Colors
NORMAL="\x1b[0;39m"
RED="\x1b[1;31m"
RED_BACK="\x1b[0;41m"
GREEN="\x1b[1;32m"
YELLOW="\x1b[1;33m"
BLUE="\x1b[1;34m"
MAGENTA="\x1b[1;35m"
CYAN="\x1b[1;36m"
WHITE="\x1b[1;37m"
BLACK="\x1b[1;30m"

# Base dir (used for saving things)
BIN_DIR    = "/usr/lib/perfsonar/scripts/"
CONF_DIR   = "/etc/perfsonar"
MARKER_DIR = "/usr/local/etc/nptools_markers/"
TMP_DIR    = "/tmp/"

# Info files
USERINFO        = CONF_DIR + "site.info"
STARTINFO      = CONF_DIR + "startup.info"
IPTABLES_SAVE  = CONF_DIR + "iptables.info"
SAVEINFO       = "/var/run/toolkit/backing_store.info"
DEFAULT_ACCESSPOINT = CONF_DIR + "default_accesspoint"
ENABLEDSERVICESINFO = CONF_DIR + "enabled_services.info"

# Important system paths
UNIONFS_MEDIA = "/UNIONFS/media/"
MEDIA         = "/media/"
MOUNTS        = "/proc/mounts"
FSTAB         = "/etc/fstab" 

# StaticIP files
RESOLV   = "/etc/resolv.conf"
STATICIP = CONF_DIR + "static.ip"

# NTP Config file
NTP_CONF = "/etc/ntp.conf"
NTP_KNOWN_SERVERS = "/usr/local/etc/ntp.static.servers"
NTP_CUSTOM_SERVERS = "/usr/local/etc/ntp.custom.servers"

# OWAMP Config files
OWAMP_ROOT   = "/etc/owamp-server"
OWAMP_CONF   = OWAMP_ROOT + "owamp-server.conf"
OWAMP_LIMITS = OWAMP_ROOT + "owamp-server.limits"
OWAMP_KEYS   = OWAMP_ROOT + "owamp-server.pfs"

# Internet2's version of saveconfig
SAVECONFIG   = BIN_DIR + "save_config"

# Marker files
# These things are used by the main script to determine if files are configured
# They should be removed by the support scripts - not the main script!
ENABLEDISABLE_MARKER  = MARKER_DIR + "customize.services"
PASS_MARKER  = MARKER_DIR + "set.pass"
OWAMP_MARKER = MARKER_DIR + "customize.owamp"
NTP_MARKER   = MARKER_DIR + "customize.ntp"
TZ_MARKER    = MARKER_DIR + "customize.timezone"

SSH_INIT_SCRIPT            = "/etc/init.d/ssh"
APACHE_INIT_SCRIPT         = "/etc/init.d/httpf"
OWAMP_INIT_SCRIPT          = "/etc/init.d/owamp-server"
