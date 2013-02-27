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
cp -f $LIVE_LOCATION/etc/passwd /etc/passwd.new
cp -f $LIVE_LOCATION/etc/group /etc/group.new
cp -f $LIVE_LOCATION/etc/shadow /etc/shadow.new

UGIDLIMIT=500
ERR=0
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/passwd | grep -v "perfsonar" >> /etc/passwd.new
ERR=$(($ERR + $?))
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/group | grep -v "perfsonar" >> /etc/group.new
ERR=$(($ERR + $?))
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534) {print $1}' /etc/passwd | grep -v "perfsonar" | tee - | egrep -f - /etc/shadow >> /etc/shadow.new
ERR=$(($ERR + $?))

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
