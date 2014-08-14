#!/bin/bash
export ESMOND_ROOT=/opt/esmond
export ESMOND_CONF=$ESMOND_ROOT/esmond.conf
export DJANGO_SETTINGS_MODULE=esmond.settings
cd /opt/esmond
source /opt/rh/python27/enable
. bin/activate
python ./util/ps_remove_data.py -c /opt/perfsonar_ps/toolkit/etc/clean_esmond_db.conf
