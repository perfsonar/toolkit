#!/bin/bash

# set GC_GRACE_SECONDS to 0 so data is deleted right away. If running multi-node cassandra
# set ESMOND_CLEANER_MULTI_NODE environment variable so this steps gets skipped.
if [ "$ESMOND_CLEANER_MULTI_NODE" != "1" ]; then
    cqlsh -k esmond -e "ALTER TABLE rate_aggregations WITH GC_GRACE_SECONDS = 0;"
    cqlsh -k esmond -e "ALTER TABLE base_rates WITH GC_GRACE_SECONDS = 0;"
    cqlsh -k esmond -e "ALTER TABLE raw_data WITH GC_GRACE_SECONDS = 0;"
fi

#run ps_remove_data.py to delete expired data
export ESMOND_ROOT=/usr/lib/esmond
export ESMOND_CONF=/etc/esmond/esmond.conf
export DJANGO_SETTINGS_MODULE=esmond.settings
cd $ESMOND_ROOT
if [ -e /opt/rh/python27/enable ]; then
    source /opt/rh/python27/enable
fi
. bin/activate
python ./util/ps_remove_data.py -c /etc/perfsonar/toolkit/clean_esmond_db.conf

#force a compaction
if [ "$ESMOND_CLEANER_MULTI_NODE" != "1" ]; then
    nodetool compact esmond
fi