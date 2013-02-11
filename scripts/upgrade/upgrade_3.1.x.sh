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

OLD_CONFIG_TARBALL=$STORE_LOCATION/configs.tbz

OLD_CONFIG_LOCATION=$STORE_LOCATION/NPTools/old_config
NEW_CONFIG_LOCATION=/

# Only upgrade the versions before 3.2
if [ ! -z "$STORE_VERSION" ]; then
    exit 0
fi

if [ ! -f $OLD_CONFIG_TARBALL ]; then
    exit 0
fi

mkdir -pv $OLD_CONFIG_LOCATION
mkdir -pv $NEW_CONFIG_LOCATION

tar -xj -C $OLD_CONFIG_LOCATION -f $OLD_CONFIG_TARBALL

### SSH Keys ###
mkdir -pv $NEW_CONFIG_LOCATION/etc/ssh
cp -af $OLD_CONFIG_LOCATION/etc/ssh/ssh_host_dsa_key      $NEW_CONFIG_LOCATION/etc/ssh
cp -af $OLD_CONFIG_LOCATION/etc/ssh/ssh_host_dsa_key.pub  $NEW_CONFIG_LOCATION/etc/ssh
cp -af $OLD_CONFIG_LOCATION/etc/ssh/ssh_host_rsa_key      $NEW_CONFIG_LOCATION/etc/ssh
cp -af $OLD_CONFIG_LOCATION/etc/ssh/ssh_host_rsa_key.pub  $NEW_CONFIG_LOCATION/etc/ssh

### BWCTL ###
# Only update the limits and keys, ignore the .conf file for now
mkdir -pv $NEW_CONFIG_LOCATION/etc/bwctld
cp -f $OLD_CONFIG_LOCATION/usr/local/etc/bwctld.limits          $NEW_CONFIG_LOCATION/etc/bwctld/
cp -f $OLD_CONFIG_LOCATION/usr/local/etc/bwctld.keys            $NEW_CONFIG_LOCATION/etc/bwctld/

### OWAMP ###
# Only update the limits and keys, ignore the .conf file for now
mkdir -pv $NEW_CONFIG_LOCATION/etc/owampd
cp -f $OLD_CONFIG_LOCATION/usr/local/etc/owampd.limits          $NEW_CONFIG_LOCATION/etc/owampd/
cp -f $OLD_CONFIG_LOCATION/usr/local/etc/owampd.pfs             $NEW_CONFIG_LOCATION/etc/owampd/

### NTP ###
mkdir -pv $NEW_CONFIG_LOCATION/etc
mkdir -pv $NEW_CONFIG_LOCATION/opt/perfsonar_ps/toolkit/etc/
cp -f $OLD_CONFIG_LOCATION/etc/ntp.conf                         $NEW_CONFIG_LOCATION/etc/ntp.conf
cp -f $OLD_CONFIG_LOCATION/usr/local/etc/ntp.known_servers      $NEW_CONFIG_LOCATION/opt/perfsonar_ps/toolkit/etc/ntp_known_servers

### Toolkit Web GUI Edittable Configuration ###
mkdir -pv $NEW_CONFIG_LOCATION/opt/perfsonar_ps/toolkit/etc/
cp -f $OLD_CONFIG_LOCATION/usr/local/etc/site.info              $NEW_CONFIG_LOCATION/opt/perfsonar_ps/toolkit/etc/administrative_info
cp -f $OLD_CONFIG_LOCATION/usr/local/etc/default_accesspoint    $NEW_CONFIG_LOCATION/opt/perfsonar_ps/toolkit/etc/external_addresses
cp -f $OLD_CONFIG_LOCATION/usr/local/etc/enabled_services.info  $NEW_CONFIG_LOCATION/opt/perfsonar_ps/toolkit/etc/enabled_services

# After updating the site.info file, the various dependent config files need
# modified. A script below updates them.

### PingER ###

# Copy the PingER tests configuration to the new location and filename
mkdir -pv $NEW_CONFIG_LOCATION/opt/perfsonar_ps/PingER/etc/
cp -f $OLD_CONFIG_LOCATION/usr/local/etc/pinger_landmarks.xml $NEW_CONFIG_LOCATION/opt/perfsonar_ps/PingER/etc/pinger-landmarks.xml

# Update the PingER database password to the password from the original toolkit
# since that's what's currently configured for the database table
perl -p -i -e 's/db_passwd.*/db_password          7hckn0p1x/' $NEW_CONFIG_LOCATION/opt/perfsonar_ps/PingER/etc/daemon.conf


### perfSONARBUOY ###

# Copy the perfSONARBUOY configuration to the new location
mkdir -pv $NEW_CONFIG_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/
cp -f $OLD_CONFIG_LOCATION/usr/local/etc/owmesh.conf $NEW_CONFIG_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/

# Update the user/group for perfSONARBUOY to run as
perl -p -i -e 's/UserName.*/UserName    perfsonar/g' $NEW_CONFIG_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf
perl -p -i -e 's/GroupName.*/GroupName    perfsonar/g' $NEW_CONFIG_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf

# Update the location to find the various tools
perl -p -i -e 's/BinDir.*/BinDir      \/usr\/bin/g' $NEW_CONFIG_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf

# Update the location to store the various data files
perl -p -i -e 's/BWDataDir.*/BWDataDir     \/var\/lib\/perfsonar\/perfsonarbuoy_ma\/bwctl/g' $NEW_CONFIG_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf 
perl -p -i -e 's/OWPDataDir.*/OWPDataDir     \/var\/lib\/perfsonar\/perfsonarbuoy_ma\/owamp/g' $NEW_CONFIG_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf 
perl -p -i -e 's/OwampdVarDir.*/OwampdVarDir  \/var\/lib/g' $NEW_CONFIG_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf 

perl -p -i -e 's/BWCentralArchDir.*/BWCentralArchDir    \/var\/lib\/perfsonar\/perfsonarbuoy_ma\/bwctl\/archive/g' $NEW_CONFIG_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf
perl -p -i -e 's/BWCentralDataDir.*/BWCentralDataDir    \/var\/lib\/perfsonar\/perfsonarbuoy_ma\/bwctl\/upload/g' $NEW_CONFIG_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf
perl -p -i -e 's/OWPCentralArchDir.*/OWPCentralArchDir   \/var\/lib\/perfsonar\/perfsonarbuoy_ma\/owamp\/archive/g' $NEW_CONFIG_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf
perl -p -i -e 's/OWPCentralDataDir.*/OWPCentralDataDir   \/var\/lib\/perfsonar\/perfsonarbuoy_ma\/owamp\/upload/g' $NEW_CONFIG_LOCATION/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf


# Ensure that various directories that might be bind mounted from the data
# store have appropriate permissions as they may have been created by an
# earlier version.
touch /var/log/btmp
chown root:utmp /var/log/btmp

touch /var/log/wtmp
chown root:utmp /var/log/wtmp

mkdir -p /var/log/cacti
chown -R apache:root /var/log/cacti

mkdir -p /var/log/cups
chown -R lp:sys /var/log/cups

touch /var/log/mysqld.log
chown mysql:mysql /var/log/mysqld.log

mkdir -p /var/log/ndt

mkdir -p /var/log/perfsonar
chown -R perfsonar:perfsonar /var/log/perfsonar

mkdir -p /var/log/perfsonar/web_admin
chown -R apache:perfsonar /var/log/perfsonar/web_admin

# Ensure that /var/lib/mysql is owned by the mysql user
chown -R mysql:mysql /var/lib/mysql

# Ensure that the perfsonar libs are owned by the perfsonar user
mkdir -p /var/lib/perfsonar
chown -R perfsonar:perfsonar /var/lib/perfsonar

# Ensure that the cacti lib directory is owned by apache
mkdir -p /var/lib/cacti/rra
chown -R apache:root /var/lib/cacti/rra

# Ensure the httpd directory is created
mkdir -p /var/log/httpd
chown -R root:root /var/log/httpd

# Ensure the audit directory is created
mkdir -p /var/log/audit
chown -R root:root /var/log/audit


### Admin Info
# The administrative info got updated, so make sure that that new info gets
# propagated through the various config files

perl <<EOF
use strict;
use warnings;

use lib "/opt/perfsonar_ps/toolkit/lib";

use perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;

# need to start the config manager so that the files can get written out
\`ifup lo\`;
\`service config_daemon start\`;

my (\$status, \$res);

my \$admin_info = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new();
(\$status, \$res) = \$admin_info->init();
print "Couldn't init: \$res" if (\$status != 0);
(\$status, \$res) = \$admin_info->save({ restart_services => 0 });
print "Couldn't save: \$res" if (\$status != 0);

\`service config_daemon stop\`;
\`ifdown lo\`;
EOF

# Users: copy over the root password and create any other users that exist, and
# weren't system accounts for Knoppix
perl <<EOF
use strict;
use warnings;

my \$group_file = "$OLD_CONFIG_LOCATION/etc/group";
my \$passwd_file = "$OLD_CONFIG_LOCATION/etc/passwd";
my \$shadow_file = "$OLD_CONFIG_LOCATION/etc/shadow";
my \$admin_group = "admin";

my @system_accounts = qw(daemon bin sys sync games man lp mail news uucp proxy majordom postgres www-data backup operator list mysql postfix nobody partimag bind sslwrap messagebus arpwatch saned vdr backuppc chipcard uml-net statd bacula npad ami ntp haldaemon sshd perfsonar);

my @admin_users = get_group_users(\$group_file, \$admin_group);

# special case the knoppix and root users
push @admin_users, "knoppix";
push @admin_users, "root";

my \$users = get_users(\$passwd_file, \$shadow_file);
foreach my \$username (@system_accounts) {
	delete(\$users->{\$username});
}

foreach my \$user_name (keys %\$users) {
	my \$user_info = \$users->{\$user_name};

	next unless (\$user_info->{password} and \$user_info->{password} ne "*" and \$user_info->{password} ne "!");

	my \$cmd;

	if (\$user_name eq "root") {
		\$cmd = "echo '\$user_name:\$user_info->{password}' | /usr/sbin/chpasswd -e";
	}
	else {
		\$cmd = "/usr/sbin/adduser -m";
                \$cmd .= " --shell \$user_info->{shell}" if (\$user_info->{shell});
		foreach my \$curr_user (@admin_users) {
			\$cmd .= " -G wheel" if (\$curr_user eq \$user_name);
		}
		\$cmd .= " -p '\$user_info->{password}'";
		\$cmd .= " ".\$user_name;
	}

	print "CMD: \$cmd\n";
	\`\$cmd\`;
}

sub get_group_users {
	my (\$group_file, \$group) = @_;

	my @users = ();
	if (open(FILE,\$group_file)) {
		while(<FILE>) {
			my (\$name,\$tmp,\$id,\$users) = split(":");
			next unless (\$name eq \$group);
			chomp \$users;
			@users = split(",",\$users);
		}
	}
	return @users;
}

sub get_users {
	my (\$passwd_file, \$shadow_file) = @_;

	my %user_info = ();

	if (open(PASSWD,\$passwd_file)) {
		while(<PASSWD>) {
			chomp;

			my (\$name,\$tmp,\$uid,\$gid,\$group,\$home,\$shell) = split(":");

			\$user_info{\$name} = () unless (\$user_info{\$name});

			\$user_info{\$name}->{'name'}  = \$name;
			\$user_info{\$name}->{'uid'}   = \$uid;
			\$user_info{\$name}->{'gid'}   = \$gid;
			\$user_info{\$name}->{'group'} = \$group;
			\$user_info{\$name}->{'home'}  = \$home;
			\$user_info{\$name}->{'shell'} = \$shell;
		}
		close(PASSWD);
	}

	if (open(SHADOW,\$shadow_file)) {
		while(<SHADOW>) {
			chomp;

			my (\$name,\$pass,\$remainder) = split(":");

			\$user_info{\$name} = () unless (\$user_info{\$name});
	
			\$user_info{\$name}->{'name'}      = \$name;
			\$user_info{\$name}->{'password'}  = \$pass;
		}

		close(SHADOW);
	}

	return \%user_info;
}
EOF

# Home: Copy the files from /home (they were stored as configuration before).
# This must be done after the password file has been updated
cp -Rav $OLD_CONFIG_LOCATION/home/* $NEW_CONFIG_LOCATION/home &> /dev/null

# Ensure users own their files
pushd $NEW_CONFIG_LOCATION/home
for user in *; do
    chown -R $user:$user /home/$user
done
popd


# Update the cacti database to account for changed paths.
CACTI_TEMP=/tmp/cacti.sql

service mysqld start &> /dev/null
mysqldump cacti > $CACTI_TEMP
sed -i "s|/usr/local/nptoolkit_scripts|/opt/perfsonar_ps/toolkit|g" $CACTI_TEMP
sed -i "s|/usr/local/web|/opt/perfsonar_ps/toolkit/web/root|g" $CACTI_TEMP
sed -i "s|/UNIONFS||g" $CACTI_TEMP
mysql cacti < $CACTI_TEMP
service mysqld stop &> /dev/null


# Update the existing network configuration
OLD_NETWORKING_CONFIG_FILE=$OLD_CONFIG_LOCATION/usr/local/etc/static.ip
if [ -f $OLD_NETWORKING_CONFIG_FILE ]; then
    IP_ADDR=
    NETMASK=
    GATEWAY=
    BOOTPROTO=
    PRIMARY=
    MTU=
    INTERFACE=
    DNS=()

    CURR_ATTRIBUTE=
    NEXT_ATTRIBUTE=
    PREV_WAS_ATTRIBUTE=no
    IS_ATTTRIBUTE_NAME=

    for value in `cat $OLD_NETWORKING_CONFIG_FILE`; do
        # we may need to back up if the value of an attribute/value pair is empty.
        # value gets unset at the end of our processing below, unless we've gone
        # to far and need to back up. Wish I could have used a goto here, it
        # would've made it a might less ugly.
        while  [ -n "$value" ]; do
             if [ "$value" == "IP_ADDR:" -o "$value" == "NETMASK:" -o "$value" == "GATEWAY:" -o "$value" == "BOOTPROTO:" -o "$value" == "PRIMARY:" -o "$value" == "MTU:" -o "$value" == "INTERFACE:" -o "$value" == "DNS:" ]; then
                 # We could have an empty value I guess. In that case, handle it appropriately.
                 IS_ATTTRIBUTE_NAME=yes
             else
                 IS_ATTTRIBUTE_NAME=no
             fi
   
             if [ "$IS_ATTTRIBUTE_NAME" == "yes" ]; then
                 if [ "$PREV_WAS_ATTRIBUTE" == "no" ]; then
                    CURR_ATTRIBUTE=$value
                    NEXT_ATTRIBUTE=
                    value=
                    continue
                 fi

                 NEXT_ATTRIBUTE=$value
                 value=
             fi

             if [ "DNS:" == "$CURR_ATTRIBUTE" ]; then
                 # push the DNS servers onto an array
                 DNS[${#DNS[*]}]=$value
             elif [ "IP_ADDR:" == "$CURR_ATTRIBUTE" ]; then
                 IP_ADDR=$value
             elif [ "NETMASK:" == "$CURR_ATTRIBUTE" ]; then
                 NETMASK=$value
             elif [ "GATEWAY:" == "$CURR_ATTRIBUTE" ]; then
                 GATEWAY=$value
             elif [ "BOOTPROTO:" == "$CURR_ATTRIBUTE" ]; then
                 BOOTPROTO=$value
             elif [ "PRIMARY:" == "$CURR_ATTRIBUTE" ]; then
                 PRIMARY=$value
             elif [ "MTU:" == "$CURR_ATTRIBUTE" ]; then
                 MTU=$value
             elif [ "INTERFACE:" == "$CURR_ATTRIBUTE" ]; then
                 INTERFACE=$value
             fi

             if [ -n "$INTERFACE" ]; then
                 echo "Generating ifcfg-$INTERFACE"
                 # Generate the ifcfg-* file for this interface
                 mkdir -p /etc/sysconfig/network-scripts
                 echo DEVICE=$INTERFACE     > /etc/sysconfig/network-scripts/ifcfg-$INTERFACE
                 echo ONBOOT=yes           >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE
                 echo TYPE=Ethernet        >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE
                 echo BOOTPROTO=$BOOTPROTO >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE
                 if [ -n "$IP_ADDR" ]; then
                 echo IPADDR=$IP_ADDR      >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE
                 fi
                 if [ -n "$NETMASK" ]; then
                 echo NETMASK=$NETMASK     >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE
                 fi
                 if [ -n "$GATEWAY" ]; then
                 echo GATEWAY=$GATEWAY     >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE
                 fi
                 if [ -n "$MTU" ]; then
                 echo MTU=$MTU             >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACE
                 fi

		 # If this interface was the primary interface, update the
		 # interface for the "discover_external_address" script to look
		 # at.
                 if [ "$PRIMARY" == "1" ]; then
                 echo external_interface         $INTERFACE  >> /opt/perfsonar_ps/toolkit/etc/discover_external_address.conf
                 fi

                 # Clear the values
                 IP_ADDR=
                 NETMASK=
                 GATEWAY=
                 BOOTPROTO=
                 PRIMARY=
                 MTU=
                 INTERFACE=
             fi
   
             value=
             if [ -n "$NEXT_ATTRIBUTE" ]; then
                 value=$NEXT_ATTRIBUTE
             fi
       done
   done

   # Fill in the DNS servers
    if [ ${#DNS[@]} -gt 0 ]; then
        echo "Generating /etc/resolv.conf"
        echo > /etc/resolv.conf
        for dns_server in "${DNS[@]}"; do
            echo nameserver $dns_server >> /etc/resolv.conf
        done
    fi
fi

