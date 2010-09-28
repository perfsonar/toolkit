#!/bin/bash
#
# reset_psb_bwctl.sh: This script resets the perfSONAR-BUOY/bwctl database. It
# turns off mysql, backs up the database to something like
# /var/lib/mysql/bwctl.backup.[backup date/time], restores the original
# database that came with the ISO, and then restarts mysql.

/etc/init.d/mysql stop
mv /var/lib/mysql/bwctl /var/lib/mysql/bwctl.backup.`date +"%Y-%m-%d_%H:%m:%S"`
cp -Ra /KNOPPIX/var/lib/mysql/bwctl /var/lib/mysql/bwctl
/etc/init.d/mysql start
