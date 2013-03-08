#!/bin/bash

TEMP_BAK_NAME=ps-toolkit-migrate-backup
TEMP_BAK_DIR="/tmp/$TEMP_BAK_NAME"

#Check options
if [ -z "$1" ]; then
    echo "Usage: $0 <tar-file>"
    echo "Missing path to tar file in options list"
    exit 1
fi


#Create temp directory
rm -rf $TEMP_BAK_DIR
mkdir $TEMP_BAK_DIR
if [ "$?" != "0" ]; then
    echo "Unable to create temp directory"
    exit 1
fi

#create directory structure
mkdir $TEMP_BAK_DIR/etc
mkdir -p $TEMP_BAK_DIR/etc/maddash-server/maddash
mkdir -p $TEMP_BAK_DIR/etc/owampd
mkdir -p $TEMP_BAK_DIR/etc/bwctld
mkdir -p $TEMP_BAK_DIR/opt/perfsonar_ps/toolkit/etc
mkdir -p $TEMP_BAK_DIR/opt/perfsonar_ps/perfsonarbuoy_ma/etc
mkdir -p $TEMP_BAK_DIR/opt/perfsonar_ps/mesh_config/etc
mkdir -p $TEMP_BAK_DIR/mysql_data
mkdir -p $TEMP_BAK_DIR/var/lib

#get users and groups
printf "Backing-up users..."
UGIDLIMIT=500
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/passwd | grep -v "perfsonar" | grep -v "npad" > $TEMP_BAK_DIR/etc/passwd
if [ "$?" != "0" ]; then
    printf "[SUCCESS]"
    echo ""
    echo " - Note: No users found to be migrated. This may be normal if you have not setup any non-root users"
else
    printf "[SUCCESS]"
    echo ""
fi

printf "Backing-up groups..."
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/group | grep -v "perfsonar" | grep -v "npad" > $TEMP_BAK_DIR/etc/group
if [ "$?" != "0" ]; then
    printf "[SUCCESS]"
    echo ""
    echo " - Note: No groups found to be migrated. This may be normal if you have not setup any non-root users"
else
    printf "[SUCCESS]"
    echo ""
fi

printf "Backing-up passwords..."
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534) {print $1}' /etc/passwd | grep -v "perfsonar" | grep -v "npad" | tee - | egrep -f - /etc/shadow > $TEMP_BAK_DIR/etc/shadow
if [ "$?" != "0" ]; then
    printf "[SUCCESS]"
    echo ""
    echo " - Note: No user account passwords found to be migrated. This may be normal if you have not setup any non-root users"
else
    printf "[SUCCESS]"
    echo ""
fi

printf "Backing up administrative users..."
awk -F: '($1 == "wheel") {print $4}' /etc/group | sed s"/,/ /g" > $TEMP_BAK_DIR/etc/wheel_users
if [ "$?" != "0" ]; then
    printf "[SUCCESS]"
    echo ""
    echo " - Note: No user administrators found to be migrated."
else
    printf "[SUCCESS]"
    echo ""
fi

#get administrative info
printf "Backing-up administrative info..."
grep -v "site_project=pS-NPToolkit-" /opt/perfsonar_ps/toolkit/etc/administrative_info > $TEMP_BAK_DIR/opt/perfsonar_ps/toolkit/etc/administrative_info
if [ "$?" != "0" ]; then
    echo "Unable to copy /opt/perfsonar_ps/toolkit/etc/administrative_info"
    exit 1
fi
printf "[SUCCESS]"
echo ""

#get bwctl files
printf "Backing-up bwctld configuration..."
cp /etc/bwctld/bwctld.conf $TEMP_BAK_DIR/etc/bwctld/bwctld.conf 
if [ "$?" != "0" ]; then
    echo "Unable to copy /etc/bwctld/bwctld.conf"
    exit 1
fi

cp /etc/bwctld/bwctld.limits $TEMP_BAK_DIR/etc/bwctld/bwctld.limits 
if [ "$?" != "0" ]; then
    echo "Unable to copy /etc/bwctld/bwctld.limits"
    exit 1
fi

if [ -f "/etc/bwctld/bwctld.keys" ]; then
    cp /etc/bwctld/bwctld.keys $TEMP_BAK_DIR/etc/bwctld/bwctld.keys 
    if [ "$?" != "0" ]; then
        echo "Unable to copy /etc/bwctld/bwctld.keys"
        exit 1
    fi
fi

printf "[SUCCESS]"
echo ""

#get owamp files
printf "Backing-up owampd configuration..."
cp /etc/owampd/owampd.conf $TEMP_BAK_DIR/etc/owampd/owampd.conf 
if [ "$?" != "0" ]; then
    echo "Unable to copy /etc/owampd/owampd.conf"
    exit 1
fi

cp /etc/owampd/owampd.limits $TEMP_BAK_DIR/etc/owampd/owampd.limits 
if [ "$?" != "0" ]; then
    echo "Unable to copy /etc/owampd/owampd.limits"
    exit 1
fi
printf "[SUCCESS]"
echo ""

#get enabled services
printf "Backing-up enabled services..."
cp /opt/perfsonar_ps/toolkit/etc/enabled_services $TEMP_BAK_DIR/opt/perfsonar_ps/toolkit/etc/enabled_services
if [ "$?" != "0" ]; then
    echo "Unable to copy /opt/perfsonar_ps/toolkit/etc/enabled_services"
    exit 1
fi
printf "[SUCCESS]"
echo ""

#get NTP config
printf "Backing-up NTP configuration..."
cp /opt/perfsonar_ps/toolkit/etc/ntp_known_servers $TEMP_BAK_DIR/opt/perfsonar_ps/toolkit/etc/ntp_known_servers
if [ "$?" != "0" ]; then
    echo "Unable to copy /opt/perfsonar_ps/toolkit/etc/ntp_known_servers"
    exit 1
fi

cp /etc/ntp.conf  $TEMP_BAK_DIR/etc/ntp.conf 
if [ "$?" != "0" ]; then
    echo "Unable to copy /etc/ntp.conf"
    exit 1
fi
printf "[SUCCESS]"
echo ""

#get cacti data
printf "Backing-up cacti..."
cp -r /var/lib/cacti $TEMP_BAK_DIR/var/lib/cacti
if [ "$?" != "0" ]; then
    echo "Unable to copy /var/lib/cacti"
    exit 1
fi
printf "[SUCCESS]"
echo ""

#get owmesh
printf "Backing-up scheduled tests..."
cp /opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf $TEMP_BAK_DIR/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf
if [ "$?" != "0" ]; then
    echo "Unable to copy /opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf"
    exit 1
fi
printf "[SUCCESS]"
echo ""

#get mesh config if exists
if [ -f "/opt/perfsonar_ps/mesh_config/etc/agent_configuration.conf" ]; then
    printf "Backing-up mesh configuration..."
    cp /opt/perfsonar_ps/mesh_config/etc/agent_configuration.conf $TEMP_BAK_DIR/opt/perfsonar_ps/mesh_config/etc/agent_configuration.conf
    if [ "$?" != "0" ]; then
        echo "Unable to copy /opt/perfsonar_ps/mesh_config/etc/agent_configuration.conf"
        exit 1
    fi
    printf "[SUCCESS]"
    echo ""
fi

#get maddash if exists
if [ -f "/etc/maddash/maddash-server/maddash.yaml" ]; then
    printf "Backing-up MaDDash configuration..."
    cp /etc/maddash/maddash-server/maddash.yaml $TEMP_BAK_DIR/etc/maddash/maddash-server/maddash.yaml
    if [ "$?" != "0" ]; then
        echo "Unable to copy /etc/maddash/maddash-server/maddash.yaml"
        exit 1
    fi
    printf "[SUCCESS]"
    echo ""
fi

#backup databases
printf "Backing-up bwctl results..."
mysqldump --skip-lock-tables bwctl > $TEMP_BAK_DIR/mysql_data/bwctl.sql
if [ "$?" != "0" ]; then
    echo "Unable to backup bwctl MySQL databse"
    exit 1
fi
printf "[SUCCESS]"
echo ""

printf "Backing-up owamp results..."
mysqldump --skip-lock-tables owamp > $TEMP_BAK_DIR/mysql_data/owamp.sql
if [ "$?" != "0" ]; then
    echo "Unable to backup owamp MySQL databse"
    exit 1
fi
printf "[SUCCESS]"
echo ""

printf "Backing-up traceroute results..."
mysqldump --skip-lock-tables traceroute_ma > $TEMP_BAK_DIR/mysql_data/traceroute_ma.sql
if [ "$?" != "0" ]; then
    echo "Unable to backup traceroute_ma MySQL databse"
    exit 1
fi
printf "[SUCCESS]"
echo ""

printf "Backing-up pinger results..."
mysqldump --skip-lock-tables pingerMA > $TEMP_BAK_DIR/mysql_data/pingerMA.sql
if [ "$?" != "0" ]; then
    echo "Unable to backup pingerMA MySQL databse"
    exit 1
fi
printf "[SUCCESS]"
echo ""

printf "Backing-up cacti results..."
mysqldump --skip-lock-tables cacti > $TEMP_BAK_DIR/mysql_data/cacti.sql
if [ "$?" != "0" ]; then
    echo "Unable to backup cacti MySQL databse"
    exit 1
fi
printf "[SUCCESS]"
echo ""

#create tar
printf "Creating backup file..."
CUR_DIR=`pwd`
cd /tmp
tar -czf $TEMP_BAK_NAME.tgz $TEMP_BAK_NAME
if [ "$?" != "0" ]; then
    echo "Unable to create tarball"
    exit 1
fi

cd $CUR_DIR
mv /tmp/$TEMP_BAK_NAME.tgz $1
if [ "$?" != "0" ]; then
    echo "Unable to move tarball to $1"
    exit 1
fi
printf "[SUCCESS]"
echo ""

#Clean up temp directory
rm -rf $TEMP_BAK_DIR
echo "Backup complete."
