#!/bin/bash
#
# reset_psb_owamp.sh: This script resets the perfSONAR-BUOY/owamp database. It
# turns off mysql, backs up the database to something like
# /var/lib/mysql/owamp.backup.[backup date/time], restores the original
# database that came with the ISO, and then restarts mysql.

/etc/init.d/mysql stop
mv /var/lib/mysql/owamp /var/lib/mysql/owamp.backup.`date +"%Y-%m-%d_%H:%m:%S"`
cp -Ra /KNOPPIX/var/lib/mysql/owamp /var/lib/mysql/owamp
/etc/init.d/mysql start
