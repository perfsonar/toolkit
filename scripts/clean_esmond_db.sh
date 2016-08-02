#!/bin/bash
export ESMOND_ROOT=/usr/lib/esmond
export ESMOND_CONF=/etc/esmond/esmond.conf
export DJANGO_SETTINGS_MODULE=esmond.settings
cd $ESMOND_ROOT
if [ -e /opt/rh/python27/enable ]; then
    source /opt/rh/python27/enable
fi
. bin/activate
python ./util/ps_remove_data.py -c /etc/perfsonar/toolkit/clean_esmond_db.conf
