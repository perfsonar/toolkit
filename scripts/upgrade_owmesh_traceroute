#!/bin/sh

OWMESH_FILE="/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf"
REQUIRED_PARAMS="TraceDataDir TraceCentralHost TraceCentralDBName"
VALUES=("/var/lib/perfsonar/traceroute_ma/upload/" "localhost" "traceroute_ma")

index=0
for param in $REQUIRED_PARAMS
do
    PARAM_EXISTS=`grep -i "$param" $OWMESH_FILE`
    if [ -z  "$PARAM_EXISTS" ]; then
        echo "$param     ${VALUES[$index]}" >> $OWMESH_FILE;
    fi
    index=`expr $index + 1`
done
