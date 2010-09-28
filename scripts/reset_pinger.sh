#!/bin/bash
#
# reset_pinger.sh: This script resets the pinger database. It turns off mysql,
# backs up the database to something like /var/lib/mysql/pingerMA.backup.[backup
# date/time], restores the original database that came with the ISO, and then
# restarts mysql.

/etc/init.d/mysql stop
mv /var/lib/mysql/pingerMA /var/lib/mysql/pingerMA.backup.`date +"%Y-%m-%d_%H:%m:%S"`
cp -Ra /KNOPPIX/var/lib/mysql/pingerMA /var/lib/mysql/pingerMA
/etc/init.d/mysql start
