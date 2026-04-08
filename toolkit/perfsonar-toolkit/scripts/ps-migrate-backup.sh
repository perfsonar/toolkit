#!/bin/bash
#######################################################################
# ps-migrate-backup.sh <backup-tarball>
# 
# This script reads important perfSONAR configuration and system files 
# from their locations and places them in an output tarball file.
# Should be run as root.
# In its current form, the script does not backup any archive data.
#######################################################################

TEMP_BAK_NAME=ps-toolkit-migrate-backup
TEMP_BAK_DIR="/tmp/$TEMP_BAK_NAME"

#Check parameters
TEMP=$(getopt -o d --long data -n $0 -- "$@")
if [ $? != 0 ]; then
    echo "Usage: $0 [-d|--data] <tgz-file>"
    echo "Unable to parse command line"
    exit 1
fi
eval set -- "$TEMP"
    
while true; do
   case "$1" in
       -d|--data) DATA=1 ; echo "This option is currently not available. Exiting..." ; exit 1 ; shift ;;
       --) shift ; break ;;
       *) echo "Internal error!" ; exit 1 ;;
   esac
done

#Check options
if [ -z "$1" ]; then
    echo "Usage: $0 [-d|--data] <tgz-file>"
    echo "Missing path to tar file in options list"
    exit 1
elif [ -e "$1" ]; then
    echo "Backup file already exists: $1"
    exit 1
fi      
    
#Create temp directory
rm -rf $TEMP_BAK_DIR
mkdir -m 700 $TEMP_BAK_DIR
if [ "$?" != "0" ]; then
    echo "Unable to create temp directory"
    exit 1 
fi      
            
#create directory structure
mkdir -p $TEMP_BAK_DIR/etc

#get perfsonar files
printf "Backing-up perfsonar configuration..."
cp -a /etc/perfsonar $TEMP_BAK_DIR/etc
if [ "$?" != "0" ]; then
    echo "Unable to copy /etc/perfsonar"
    exit 1
fi
printf "[SUCCESS]"
echo ""

#get owamp files
printf "Backing-up owamp-server configuration..."
cp -a /etc/owamp-server $TEMP_BAK_DIR/etc
if [ "$?" != "0" ]; then
    echo "Unable to copy /etc/owamp-server"
    exit 1
fi
printf "[SUCCESS]"
echo ""

#get twamp files if exists
if [ -d "/etc/twamp-server" ]; then
    printf "Backing-up twamp-server configuration..."
    cp -a /etc/twamp-server $TEMP_BAK_DIR/etc
    if [ "$?" != "0" ]; then
        echo "Unable to copy /etc/twamp-server"
        exit 1
    fi
    printf "[SUCCESS]"
    echo ""
fi

#get NTP config
printf "Backing-up NTP configuration..."
if [ -f "/etc/ntp.conf" ]; then
    #older systems
    cp /etc/ntp.conf  $TEMP_BAK_DIR/etc/ntp.conf
    if [ "$?" != "0" ]; then
        echo "Unable to copy /etc/ntp.conf"
        exit 1
    fi
    printf "[SUCCESS]"
    echo ""    
else
    if [ -f "/etc/ntpsec/ntp.conf" ]; then
        #new systems
        cp -a /etc/ntpsec  $TEMP_BAK_DIR/etc
        if [ "$?" != "0" ]; then
            echo "Unable to copy /etc/ntpsec"
            exit 1
        fi
        printf "[SUCCESS]"
        echo ""
    else
        printf "[Unable to find NTP configuration]"
        echo ""
    fi
fi

#get chrony config if exists
printf "Backing-up chrony configuration..."
if which chronyd > /dev/null; then
    cp -a /etc/chrony  $TEMP_BAK_DIR/etc
    if [ "$?" != "0" ]; then
        echo "Unable to copy /etc/chrony"
        exit 1
    fi
    printf "[SUCCESS]"
    echo ""
fi

#get pscheduler if exists
if which pscheduler > /dev/null; then
    pscheduler backup > $TEMP_BAK_DIR/pscheduler
    if [ "$?" != "0" ]; then
        echo "Unable to create pScheduler backup"
        exit 1
    fi
fi

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