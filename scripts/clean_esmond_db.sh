#!/bin/bash
export ESMOND_ROOT=/usr/lib/esmond
export ESMOND_CONF=/etc/esmond/esmond.conf
export DJANGO_SETTINGS_MODULE=esmond.settings
cd /opt/esmond
source /opt/rh/python27/enable
. bin/activate
python ./util/ps_remove_data.py -c /etc/perfsonar/toolkit/clean_esmond_db.conf
