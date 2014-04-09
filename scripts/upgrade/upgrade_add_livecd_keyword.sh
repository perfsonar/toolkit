#!/bin/sh

ADMIN_INFO_FILE="/opt/perfsonar_ps/toolkit/etc/administrative_info"
LS_REGISTRATION_CONF_FILE="/opt/perfsonar_ps/ls_registration_daemon/etc/ls_registration_daemon.conf"

if [ -z "`grep site_project=pS-NPToolkit-LiveCD $ADMIN_INFO_FILE`" ]; then
    echo "site_project=pS-NPToolkit-LiveCD" >> $ADMIN_INFO_FILE
    echo "site_project=pS-NPToolkit-LiveCD" >> $LS_REGISTRATION_CONF_FILE
fi
