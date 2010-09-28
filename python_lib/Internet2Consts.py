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
BIN_DIR    = "/opt/perfsonar_ps/toolkit/scripts/"
CONF_DIR   = "/usr/local/etc/"
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

# NDT Template
NDT_TEMPLATE = "/usr/local/etc/tcpbw100.template"
NDT_SAVE     = "/usr/local/ndt/tcpbw100.html"

# NPAD Templates
NPAD_DIR           = "/usr/local/npad-dist/"
NPAD_WWW           = "/usr/local/npad-dist/www/"
NPAD_HTML_TEMPLATE = "/usr/local/etc/diag_form.html.template"
NPAD_HTML_SAVE     = NPAD_WWW + "diag_form.html"

# NTP Config file
NTP_CONF = "/etc/ntp.conf"
NTP_KNOWN_SERVERS = "/usr/local/etc/ntp.static.servers"
NTP_CUSTOM_SERVERS = "/usr/local/etc/ntp.custom.servers"

# BWCTL Config files
BWCTL_ROOT   = "/usr/local/etc/"
BWCTL_CONF   = BWCTL_ROOT + "bwctld.conf"
BWCTL_LIMITS = BWCTL_ROOT + "bwctld.limits"
BWCTL_KEYS   = BWCTL_ROOT + "bwctld.keys"

# OWAMP Config files
OWAMP_ROOT   = "/usr/local/etc/"
OWAMP_CONF   = OWAMP_ROOT + "owampd.conf"
OWAMP_LIMITS = OWAMP_ROOT + "owampd.limits"
OWAMP_KEYS   = OWAMP_ROOT + "owampd.pfs"

# Internet2's version of saveconfig
SAVECONFIG   = BIN_DIR + "save_config"

# Marker files
# These things are used by the main script to determine if files are configured
# They should be removed by the support scripts - not the main script!
ENABLEDISABLE_MARKER  = MARKER_DIR + "customize.services"
PASS_MARKER  = MARKER_DIR + "set.pass"
BWCTL_MARKER = MARKER_DIR + "customize.bwctl"
OWAMP_MARKER = MARKER_DIR + "customize.owamp"
NTP_MARKER   = MARKER_DIR + "customize.ntp"
NDT_MARKER   = MARKER_DIR + "customize.ndt"
NPAD_MARKER  = MARKER_DIR + "customize.npad"
TZ_MARKER    = MARKER_DIR + "customize.timezone"

SSH_INIT_SCRIPT            = "/etc/init.d/ssh"
APACHE_INIT_SCRIPT         = "/etc/init.d/apache2"
BWCTL_INIT_SCRIPT          = "/etc/init.d/bwctld.sh"
OWAMP_INIT_SCRIPT          = "/etc/init.d/owampd.sh"
NDT_INIT_SCRIPT            = "/etc/init.d/ndt"
NPAD_INIT_SCRIPT           = "/etc/init.d/npad"
PINGER_INIT_SCRIPT         = "/etc/init.d/PingER.sh"
SNMP_MA_INIT_SCRIPT        = "/etc/init.d/snmpMA.sh"
PSB_MA_INIT_SCRIPT         = "/etc/init.d/pSB.sh"
PSB_MASTER_INIT_SCRIPT     = "/etc/init.d/pSB_master.sh"
PSB_COLLECTOR_INIT_SCRIPT  = "/etc/init.d/pSB_collector.sh"
