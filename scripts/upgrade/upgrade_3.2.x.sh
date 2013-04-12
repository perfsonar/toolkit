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

#get admin users prior to replacing group file
ADMIN_USERS=`awk -F: '($1 == "wheel") {print $4}' /etc/group | sed s"/,/ /g"`

# Attempt to migrate accounts, groups, and passwords files
cp -f $LIVE_LOCATION/etc/passwd /etc/passwd.new
cp -f $LIVE_LOCATION/etc/group /etc/group.new
cp -f $LIVE_LOCATION/etc/shadow /etc/shadow.new

UGIDLIMIT=500
ERR=0
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/passwd | grep -v "perfsonar" | grep -v "npad" >> /etc/passwd.new
ERR=$(($ERR + $?))
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/group | grep -v "perfsonar" | grep -v "npad" >> /etc/group.new
ERR=$(($ERR + $?))
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534) {print $1}' /etc/passwd | grep -v "perfsonar" | grep -v "npad" | tee - | egrep -f - /etc/shadow >> /etc/shadow.new
ERR=$(($ERR + $?))

if [ $ERR -eq 0 ]; then
	cp -f /etc/passwd.new /etc/passwd
	cp -f /etc/group.new /etc/group
	cp -f /etc/shadow.new /etc/shadow
else
	echo "Error: failed to migrate user information."
fi
rm -f /etc/passwd.new &> /dev/null
rm -f /etc/group.new &> /dev/null
rm -f /etc/shadow.new &> /dev/null

#restore administrative users
if [ -n "$ADMIN_USERS" ]; then
    ADMIN_USERS_ARR=($ADMIN_USERS)
    for admin_user in "${ADMIN_USERS_ARR[@]}"
    do
        /usr/sbin/usermod -a -Gwheel $admin_user
        if [ "$?" != "0" ]; then
            echo "Unable to add user $admin_user to wheel."
        fi
    done
fi

#make sure root gets added to wheel
/usr/sbin/usermod -a -Gwheel root

#Overwrite MA and LS reg daemon files to prevent conflict with new lookup service parameters
cp -f $LIVE_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/daemon.conf /opt/perfsonar_ps/perfsonarbuoy_ma/etc/daemon.conf
cp -f $LIVE_LOCATION/opt/perfsonar_ps/traceroute_ma/etc/daemon.conf /opt/perfsonar_ps/traceroute_ma/etc/daemon.conf
cp -f $LIVE_LOCATION/opt/perfsonar_ps/ls_registration_daemon/etc/ls_registration_daemon.conf /opt/perfsonar_ps/ls_registration_daemon/etc/ls_registration_daemon.conf

#maintain version information
grep -v "site_project=pS-NPToolkit-" /opt/perfsonar_ps/toolkit/etc/administrative_info > /opt/perfsonar_ps/toolkit/etc/administrative_info.new
cp /opt/perfsonar_ps/toolkit/etc/administrative_info.new /opt/perfsonar_ps/toolkit/etc/administrative_info
SITE_PROJ_TK_VERS=`grep "site_project=pS-NPToolkit-" $LIVE_LOCATION/opt/perfsonar_ps/toolkit/etc/administrative_info`
if [ -n "$SITE_PROJ_TK_VERS" ]; then
    echo $SITE_PROJ_TK_VERS >> /opt/perfsonar_ps/toolkit/etc/administrative_info
fi

# set OWPTestPorts to defaults defined in firewall doc if not already set
OWMESH_OWP_TESTPORTS=`grep -i "OWPTestPorts" /opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf`
if [ -z "$OWMESH_OWP_TESTPORTS" ]; then
    echo "OWPTestPorts     8760-8960" >> /opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf
fi

#Reload LD cache
ldconfig



