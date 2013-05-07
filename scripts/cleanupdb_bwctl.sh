#!/bin/sh

# Cleanup the DB first
/opt/perfsonar_ps/perfsonarbuoy_ma/bin/check_pSB_db.pl --dbtype=bwctl --verbose

# Backup 
/opt/perfsonar_ps/perfsonarbuoy_ma/bin/clean_pSB_db.pl --mysqldump-opts="--skip-lock-tables" --dbtype=bwctl --maxmonths=6 --owmesh-dir=/opt/perfsonar_ps/perfsonarbuoy_ma/etc/ --dumpdir=/var/lib/perfsonar/db_backups/bwctl

