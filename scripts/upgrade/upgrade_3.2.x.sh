#!/bin/bash
#
# Beginnings of an upgrade script for existing toolkit installations

STORE_LOCATION=
LIVE_LOCATION=
STORE_VERSION=

while getopts  "l:s:v:" flag
do
    case "$flag" in
        l) LIVE_LOCATION=$OPTARG;;
        s) STORE_LOCATION=$OPTARG;;
        v) STORE_VERSION=$OPTARG;;
    esac
done

# Only upgrade the versions before 3.3
if [ `echo "${STORE_VERSION:0:3} < 3.3" | bc` -eq 0 ]; then
    exit 0
fi

# Attempt to migrate accounts, groups, and passwords files
UGIDLIMIT=500
ERR=0
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/passwd > /etc/passwd.new
ERR+=$?
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/group > /etc/group.new
ERR+=$?
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534) {print $1}' /etc/passwd | tee - | egrep -f - /etc/shadow > /etc/shadow.new
ERR+=$?

if [ $ERR -eq 0 ]; then
	cp -f /etc/passwd.new /etc/passwd
	cp -f /etc/group.new /etc/group
	cp -f /etc/shadow.net /etc/shadow
else
	echo "Error: failed to migrate user information."
fi
rm -f /etc/passwd.new &> /dev/null
rm -f /etc/group.new &> /dev/null
rm -f /etc/shadow.new &> /dev/null

# Wipe out old administrative info site location data
cat /opt/perfsonar_ps/toolkit/etc/administrative_info | grep -v "site_location=" > /opt/personar_ps/toolkit/etc/administrative_info.new 2> /dev/null
cp -f /opt/personar_ps/toolkit/etc/administrative_info.new /opt/perfsonar_ps/toolkit/etc/administrative_info &> /dev/null
rm -f /opt/personar_ps/toolkit/etc/administrative_info.new &> /dev/null
