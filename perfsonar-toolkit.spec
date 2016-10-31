%define _unpackaged_files_terminate_build 0

%define install_base /usr/lib/perfsonar
%define config_base /etc/perfsonar/toolkit
%define graphs_base %{install_base}/graphs

%define apacheconf apache-toolkit_web_gui.conf
%define sudoerconf perfsonar_sudo

%define init_script_1 perfsonar-configdaemon
%define init_script_2 perfsonar-generate_motd
%define init_script_3 perfsonar-configure_nic_parameters
%define init_script_4 perfsonar-psb_to_esmond

%define crontab_1     cron-service_watcher
%define crontab_3     cron-clean_esmond_db

%define cron_hourly_1 logscraper.cron

%define relnum  0.10.rc2 

Name:			perfsonar-toolkit
Version:		4.0
Release:		%{relnum}%{?dist}
Summary:		perfSONAR Toolkit
License:		Distributable, see LICENSE
Group:			Applications/Communications
URL:			http://www.perfsonar.net/
Source0:		perfsonar-toolkit-%{version}.%{relnum}.tar.gz
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:		noarch
Requires:		perl
Requires:		perl(AnyEvent) >= 4.81
Requires:		perl(AnyEvent::HTTP)
Requires:		perl(CGI)
Requires:		perl(CGI::Ajax)
Requires:		perl(CGI::Carp)
Requires:		perl(CGI::Session)
Requires:		perl(Class::Accessor)
Requires:		perl(Config::General)
Requires:		perl(Cwd)
Requires:		perl(Data::Dumper)
Requires:		perl(Data::UUID)
Requires:		perl(Data::Validate::Domain)
Requires:		perl(Data::Validate::IP)
Requires:		perl(Date::Manip)
Requires:		perl(Digest::MD5)
Requires:		perl(English)
Requires:		perl(Exporter)
Requires:		perl(Fcntl)
Requires:		perl(File::Basename)
Requires:		perl(File::Spec)
Requires:		perl(FindBin)
Requires:		perl(Getopt::Long)
Requires:		perl(IO::File)
Requires:		perl(IO::Socket)
Requires:		perl(JSON::XS)
Requires:		perl(LWP::Simple)
Requires:		perl(LWP::UserAgent)
Requires:		perl(Log::Log4perl)
Requires:		perl(Net::DNS)
Requires:		perl(Net::IP)
Requires:		perl(Net::IP)
Requires:		perl(Net::Ping)
Requires:		perl(Net::Server)
Requires:		perl(NetAddr::IP)
Requires:		perl(POSIX)
Requires:		perl(Params::Validate)
Requires:		perl(RPC::XML::Client)
Requires:		perl(RPC::XML::Server)
Requires:		perl(RPM2)
Requires:		perl(Readonly)
Requires:		perl(Regexp::Common)
Requires:		perl(Scalar::Util)
Requires:		perl(Socket)
Requires:		perl(Storable)
Requires:		perl(Sys::Hostname)
Requires:		perl(Sys::Statistics::Linux)
Requires:		perl(Template)
Requires:		perl(Term::ReadLine)
Requires:		perl(Time::HiRes)
Requires:		perl(Time::Local)
Requires:		perl(XML::LibXML) >= 1.60
Requires:		perl(XML::Simple)
Requires:		perl(XML::Twig)
Requires:		perl(aliased)
Requires:		perl(base)
Requires:		perl(lib)
Requires:		perl(utf8)
Requires:		perl(vars)
Requires:		perl(version)
Requires:		perl(warnings)

#perfSONAR packages
Requires:		perfsonar-common
Requires:		perfsonar-core
Requires:		perfsonar-lscachedaemon
Requires:		perfsonar-graphs
Requires:		perfsonar-traceroute-viewer
Requires:		perfsonar-meshconfig-jsonbuilder
Requires:       perfsonar-toolkit-compat-database
Requires:       libperfsonar-esmond-perl
Requires:       libperfsonar-perl
Requires:       libperfsonar-regulartesting-perl
Requires:       libperfsonar-sls-perl
Requires:       libperfsonar-toolkit-perl
Requires:       perfsonar-toolkit-install
Requires:       perfsonar-toolkit-systemenv
Requires:       esmond >= 2.1
Requires:       esmond-database-postgresql95

# Misc performance/performance-related tools
Requires:		tcptrace
Requires:		xplot-tcptrace
Requires:		coreutils
Requires:		httpd
Requires:		mod_ssl
Requires:		nagios-plugins-all
Requires:		nscd
Requires:		yum-cron
%if 0%{?el7}
BuildRequires: systemd
%{?systemd_requires: %systemd_requires}
%else
Requires:		mod_auth_shadow
%endif

Obsoletes:		perl-perfSONAR_PS-TopologyService
Obsoletes:		perl-perfSONAR_PS-Toolkit
Provides:       perl-perfSONAR_PS-Toolkit

Requires(pre):	rpm
# Anaconda requires a Requires(post) to ensure that packages are installed before the %post section is run...
Requires(post):	perl
Requires(post):	perfsonar-lscachedaemon
Requires(post):	perfsonar-lsregistrationdaemon
Requires(post):	perfsonar-graphs
Requires(post):	perfsonar-meshconfig-agent

Requires(post):	perfsonar-common
Requires(post):	esmond          >= 2.1
Requires(post):	esmond-database-postgresql95
Requires(post):	bwctl-client    >= 1.6.0
Requires(post):	bwctl-server    >= 1.6.0
Requires(post):	owamp-client    >= 3.5.0
Requires(post):	owamp-server    >= 3.5.0
%if 0%{?el7}
%else
Requires(post):	mod_auth_shadow
%endif

Requires(post):	coreutils
Requires(post):	httpd
Requires(post):	iperf
Requires(post):	mod_ssl
Requires(post):	nscd


%description
The perfSONAR Toolkit web GUI and associated services.

%package systemenv
Summary:		perfSONAR Toolkit System Configuration
Group:			Development/Tools
Requires:		perfsonar-toolkit
Requires:       perfsonar-toolkit-security
Requires:       perfsonar-toolkit-sysctl
Requires:       perfsonar-toolkit-servicewatcher
Requires:       perfsonar-toolkit-ntp
Requires:       perfsonar-toolkit-library
Requires(post):	perfsonar-common
Requires(post):	perfsonar-toolkit
Requires(post):	bwctl-server    >= 1.6.0
Requires(post):	owamp-server    >= 3.5.0
Requires(post):	acpid
Requires(post):	avahi
Requires(post):	chkconfig
Requires(post):	cups
Requires(post):	httpd
Requires(post):	irda-utils
Requires(post):	irqbalance
Requires(post):	mdadm
Requires(post):	nfs-utils
Requires(post):	pcsc-lite
Requires(post):	rootfiles
Requires(post):	drop-in
Requires(post): perfsonar-toolkit-compat-database

%if 0%{?el7}
%else
Requires(post):	hal
Requires(post):	readahead
Requires(post):	bluez-utils
Requires(post): cpuspeed
%endif
Requires(pre):	rpm
Requires(post):	rsyslog
Requires(post):	setup
Requires(post):	smartmontools
Requires(post):	sudo
Obsoletes:              perfsonar-toolkit-systemenv < 4.0
Obsoletes:		perl-perfSONAR_PS-Toolkit-SystemEnvironment
Provides:       perl-perfSONAR_PS-Toolkit-SystemEnvironment

%description systemenv
Tunes and configures the system according to performance and security best
practices.

%package compat-database
Summary:		perfSONAR Database Migration
Group:			Development/Tools
Requires:		esmond-database-postgresql95
Requires:		drop-in
Requires(post):	esmond-database-postgresql95
Provides:		pscheduler-database-init
Obsoletes:              perfsonar-toolkit-systemenv < 4.0

%description compat-database
Provides necessary bridge to 4.0 that ensures old esmond data is migrated prior to the
initialization of the postgresql 9.5 data directory by pScheduler. 

%package library
Summary:                perfSONAR Toolkit library
Group:                  Development/Tools
Requires:               perfsonar-common
Requires:               libperfsonar-toolkit-perl
Obsoletes:              perl-perfSONAR_PS-Toolkit-Library
Provides:               perl-perfSONAR_PS-Toolkit-Library

%description library
Installs the library files

%package install
Summary:                perfSONAR Toolkit Core Scripts
Group:                  Development/Tools
Requires:               perfsonar-toolkit-library
Obsoletes:              perl-perfSONAR_PS-Toolkit-Install-Scripts
Provides:               perl-perfSONAR_PS-Toolkit-Install-Scripts

%description install
Installs install scripts

%package security
Summary:                perfSONAR Toolkit IPTables configuration
Group:                  Development/Tools
Requires:               coreutils
%if 0%{?el7}
Requires:               firewalld
%else
Requires:               iptables
Requires:               iptables-ipv6
Requires(post):         iptables
Requires(post):         iptables-ipv6
Requires(post):         chkconfig
%endif
Requires:               fail2ban
Requires:               perfsonar-common
Requires(pre):          rpm
Requires(post):         perfsonar-common
Requires(post):         coreutils
Requires(post):         system-config-firewall-base
Requires(post):         kernel-devel
Requires(post):         kernel
Requires(post):         kernel-headers
Requires(post):         module-init-tools
Obsoletes:              perl-perfSONAR_PS-Toolkit-security
Provides:               perl-perfSONAR_PS-Toolkit-security

%description security
Configures IPTables rules and installs fail2ban for perfSONAR Toolkit

%package sysctl
Summary:                perfSONAR Toolkit sysctl configuration
Group:                  Development/Tools
Requires:               coreutils
Requires:               perfsonar-common
Requires:               initscripts
Requires(pre):          rpm
Requires(post):         coreutils
Requires(post):         perfsonar-common
Requires(post):         initscripts
Obsoletes:              perl-perfSONAR_PS-Toolkit-sysctl
Provides:               perl-perfSONAR_PS-Toolkit-sysctl

%description sysctl
Configures sysctl for the Toolkit

%package ntp
Summary:                perfSONAR Toolkit ntp configuration
Group:                  Development/Tools
Requires:               coreutils
Requires:               ntp
Requires:               libperfsonar-toolkit-perl
Requires:               perfsonar-toolkit-library
Requires(pre):          rpm
Requires(post):         perfsonar-common
Requires(post):         chkconfig
Requires(post):         coreutils
Obsoletes:              perl-perfSONAR_PS-Toolkit-ntp
Provides:               perl-perfSONAR_PS-Toolkit-ntp

%description ntp
Configures ntp servers for the Toolkit

%package servicewatcher
Summary:                perfSONAR Toolkit service watcher
Group:                  Development/Tools
Requires:               coreutils
Requires:               ntp
Requires:               perfsonar-toolkit-library
Requires:               libperfsonar-toolkit-perl
Requires(pre):          rpm
Requires(post):         perfsonar-common
Requires(post):         coreutils
Obsoletes:              perl-perfSONAR_PS-Toolkit-service-watcher
Provides:               perl-perfSONAR_PS-Toolkit-service-watcher

%description servicewatcher
Installs the service-watcher package

%pre systemenv
rm -rf %{_localstatedir}/lib/rpm-state
mkdir -p %{_localstatedir}/lib/rpm-state
rpm -q --queryformat "%%{RPMTAG_VERSION} %%{RPMTAG_RELEASE} " %{name} > %{_localstatedir}/lib/rpm-state/previous_version || :

%pre sysctl
rm -rf %{_localstatedir}/lib/rpm-state
mkdir -p %{_localstatedir}/lib/rpm-state
rpm -q --queryformat "%%{RPMTAG_VERSION} %%{RPMTAG_RELEASE} " %{name} > %{_localstatedir}/lib/rpm-state/previous_version || :

%pre security
rm -rf %{_localstatedir}/lib/rpm-state
mkdir -p %{_localstatedir}/lib/rpm-state
rpm -q --queryformat "%%{RPMTAG_VERSION} %%{RPMTAG_RELEASE} " %{name} > %{_localstatedir}/lib/rpm-state/previous_version || :

%pre ntp
rm -rf %{_localstatedir}/lib/rpm-state
mkdir -p %{_localstatedir}/lib/rpm-state
rpm -q --queryformat "%%{RPMTAG_VERSION} %%{RPMTAG_RELEASE} " %{name} > %{_localstatedir}/lib/rpm-state/previous_version || :

%pre servicewatcher
rm -rf %{_localstatedir}/lib/rpm-state
mkdir -p %{_localstatedir}/lib/rpm-state
rpm -q --queryformat "%%{RPMTAG_VERSION} %%{RPMTAG_RELEASE} " %{name} > %{_localstatedir}/lib/rpm-state/previous_version || :

%prep
%setup -q -n perfsonar-toolkit-%{version}.%{relnum}

%build

%install
rm -rf %{buildroot}

make ROOTPATH=%{buildroot}/%{install_base} CONFIGPATH=%{buildroot}/%{config_base} install

install -D -m 0600 scripts/%{crontab_1} %{buildroot}/etc/cron.d/%{crontab_1}
install -D -m 0600 scripts/%{crontab_3} %{buildroot}/etc/cron.d/%{crontab_3}

install -D -m 0644 scripts/%{apacheconf} %{buildroot}/etc/httpd/conf.d/%{apacheconf}
install -D -m 0640 etc/%{sudoerconf} %{buildroot}/etc/sudoers.d/%{sudoerconf}

%if 0%{?el7}
install -D -m 0644 init_scripts/%{init_script_1}.service %{buildroot}/%{_unitdir}/%{init_script_1}.service
%else
install -D -m 0755 init_scripts/%{init_script_1} %{buildroot}/etc/init.d/%{init_script_1}
%endif
install -D -m 0755 init_scripts/%{init_script_2} %{buildroot}/etc/init.d/%{init_script_2}
install -D -m 0755 init_scripts/%{init_script_3} %{buildroot}/etc/init.d/%{init_script_3}
install -D -m 0755 init_scripts/%{init_script_4} %{buildroot}/etc/init.d/%{init_script_4}

mkdir -p %{buildroot}/usr/lib/firewalld/services/
mv etc/firewalld/services/* %{buildroot}/usr/lib/firewalld/services/
rm -rf etc/firewalld

mv etc/* %{buildroot}/%{config_base}

# Clean up unnecessary files
rm -rf %{buildroot}/%{install_base}/etc
rm -rf %{buildroot}/%{install_base}/scripts/%{crontab_1}
rm -rf %{buildroot}/%{install_base}/scripts/%{crontab_3}
rm -rf %{buildroot}/%{install_base}/scripts/%{apacheconf}
rm -rf %{buildroot}/%{install_base}/init_scripts

%clean
rm -rf %{buildroot}

%post
# Add a group of users who can login to the web ui
%if 0%{?el7}
touch /etc/perfsonar/toolkit/psadmin.htpasswd
chgrp apache /etc/perfsonar/toolkit/psadmin.htpasswd
chmod 0640 /etc/perfsonar/toolkit/psadmin.htpasswd
%else
/usr/sbin/groupadd psadmin 2> /dev/null || :
%endif
/usr/sbin/groupadd pssudo 2> /dev/null || :

mkdir -p /var/log/perfsonar/web_admin
chown apache:perfsonar /var/log/perfsonar/web_admin

mkdir -p /var/lib/perfsonar/db_backups/bwctl
chown perfsonar:perfsonar /var/lib/perfsonar/db_backups/bwctl
mkdir -p /var/lib/perfsonar/db_backups/owamp
chown perfsonar:perfsonar /var/lib/perfsonar/db_backups/owamp
mkdir -p /var/lib/perfsonar/db_backups/traceroute
chown perfsonar:perfsonar /var/lib/perfsonar/db_backups/traceroute

mkdir -p /var/lib/perfsonar/log_view/bwctl
mkdir -p /var/lib/perfsonar/log_view/ndt	
mkdir -p /var/lib/perfsonar/log_view/owamp

#Make sure root is in the wheel group for fresh install. If upgrade, keep user settings
if [ $1 -eq 1 ] ; then
    /usr/sbin/usermod -a -Gwheel root
    
    #3.5.1 fixes
    #make sure web_admin.conf points to the right lscache directory
    sed -i "s:/var/lib/perfsonar/ls_cache:/var/lib/perfsonar/lscache:g" %{install_base}/web-ng/etc/web_admin.conf
    
    #make sure we trash pre-3.5.1 config_daemon
    /etc/init.d/config_daemon stop &>/dev/null || :
    chkconfig --del config_daemon &>/dev/null || :
fi


mkdir -p /var/run/web_admin_sessions
chown apache /var/run/web_admin_sessions

mkdir -p /var/run/toolkit/

# Install a link to the logs into the web location
ln -sf /var/log/perfsonar %{install_base}/web-ng/root/admin/logs

#Set bundle type and version
echo "perfsonar-toolkit" > /var/lib/perfsonar/bundles/bundle_type
echo "%{version}" > /var/lib/perfsonar/bundles/bundle_version
chmod 644 /var/lib/perfsonar/bundles/bundle_type
chmod 644 /var/lib/perfsonar/bundles/bundle_version

# we need all these things readable the CGIs (XXX: the configuration daemon
# should be how they read these, but that'd require a fair number of changes,
# so we'll put that in the "maybe" category.
chmod o+r /etc/perfsonar/lsregistrationdaemon.conf
chmod o+r %{config_base}/ntp_known_servers
chmod o+r /etc/bwctl-server/bwctl-server.limits 2> /dev/null
chmod o+r /etc/bwctl-server/bwctl-server.keys 2> /dev/null
chmod o+r /etc/owamp-server/owamp-server.limits 2> /dev/null
chmod o+r /etc/owamp-server/owamp-server.pfs 2> /dev/null

%if 0%{?el7}
%else
chkconfig --add %{init_script_1}
%endif
chkconfig --add %{init_script_2}
chkconfig --add %{init_script_3}
chkconfig --add %{init_script_4}

%if 0%{?el7}
systemctl --quiet enable %{init_script_1}
%else
chkconfig %{init_script_1} on
%endif
chkconfig %{init_script_2} on
chkconfig %{init_script_3} on
chkconfig %{init_script_4} on

# apache needs to be on for the toolkit to work
chkconfig --level 2345 httpd on

#adding cassandra and postgres for esmond
chkconfig --add cassandra
chkconfig cassandra on
chkconfig postgresql-9.5 on

#Restart pscheduler daemons to make sure they got all tests, tools, and archivers
#also meshconfig-agent because it needs pscheduler
%if 0%{?el7}
systemctl restart httpd &>/dev/null || :
systemctl restart pscheduler-archiver &>/dev/null || :
systemctl restart pscheduler-runner &>/dev/null || :
systemctl restart pscheduler-scheduler &>/dev/null || :
systemctl restart pscheduler-ticker &>/dev/null || :
systemctl restart perfsonar-meshconfig-agent &>/dev/null || :
%else
/sbin/service httpd restart &>/dev/null || :
/sbin/service pscheduler-archiver restart &>/dev/null || :
/sbin/service pscheduler-runner restart &>/dev/null || :
/sbin/service pscheduler-scheduler restart &>/dev/null || :
/sbin/service pscheduler-ticker restart &>/dev/null || :
/sbin/service perfsonar-meshconfig-agent restart &>/dev/null || :
%endif

#Restart config_daemon and fix nic parameters
%if 0%{?el7}
systemctl restart %{init_script_1} &>/dev/null || :
%else
/etc/init.d/%{init_script_1} restart &>/dev/null || :
%endif
/etc/init.d/%{init_script_3} start &>/dev/null || :

%post systemenv
if [ -f %{_localstatedir}/lib/rpm-state/previous_version ] ; then
    PREV_VERSION=`cat %{_localstatedir}/lib/rpm-state/previous_version`
    rm %{_localstatedir}/lib/rpm-state/previous_version
fi

for script in %{install_base}/scripts/system_environment/*; do
	if [ $1 -eq 1 ] ; then
		echo "Running: $script new"
		$script new
	else
		echo "Running: $script upgrade ${PREV_VERSION}"
		$script upgrade ${PREV_VERSION}
	fi
done

# Add a script to inspire them to create a 'psadmin' and sudo user if they don't already have one
# Clear out old references first to fix bug where these got repeated
sed -i "/add_psadmin_user/d" /root/.bashrc
sed -i "/add_pssudo_user/d" /root/.bashrc
sed -i '/^if \[ -t 0 -a -t 1 -a -t 2 \];/,/^fi/d' /root/.bashrc 
cat >> /root/.bashrc <<EOF
if [ -t 0 -a -t 1 -a -t 2 ]; then
# Run the add_psadmin_user script to ensure that a psadmin user has been created
%{install_base}/scripts/add_psadmin_user --auto
# Run the add_pssudo_user script to encourage disabling root ssh
%{install_base}/scripts/add_pssudo_user --auto
fi
EOF


#########################################################################
# The system environment scripts monkey with the apache configuration, so
# reload apache when we're done. We use reload here so that we don't start
# Apache if the administrator has shut it down for some reason
#########################################################################
service httpd reload || :

%post compat-database

if [ $1 -eq 1 ] ; then
    #make sure the auth type is something pscheduler can use
    cp -f /etc/perfsonar/toolkit/default_service_configs/pg_hba.conf /var/lib/pgsql/9.5/data/pg_hba.conf
    
    #disable old postgresql
    /sbin/service postgresql stop || :
    chkconfig postgresql off
    
    #enable new postgresql
    /sbin/service postgresql-9.5 restart || :
    chkconfig postgresql-9.5 on
fi

%post ntp
if [ -f %{_localstatedir}/lib/rpm-state/previous_version ] ; then
    PREV_VERSION=`cat %{_localstatedir}/lib/rpm-state/previous_version`
    rm %{_localstatedir}/lib/rpm-state/previous_version
fi

if [ $1 -eq 1 ] ; then
	echo "Running: configure_ntpd new"
    %{install_base}/scripts/configure_ntpd new
else
    echo "Running: configure_ntpd upgrade ${PREV_VERSION}"
    %{install_base}/scripts/configure_ntpd upgrade ${PREV_VERSION}
fi

#enabling ntp service
chkconfig ntpd on

%post security

#configuring firewall
echo "Running: configure_firewall install"
%{install_base}/scripts/configure_firewall install

#enabling services
%if 0%{?el7}
systemctl enable firewalld
systemctl enable fail2ban
%else
chkconfig iptables on
chkconfig ip6tables on
chkconfig fail2ban on
%endif

%post sysctl

if [ -f %{_localstatedir}/lib/rpm-state/previous_version ] ; then
    PREV_VERSION=`cat %{_localstatedir}/lib/rpm-state/previous_version`
    rm %{_localstatedir}/lib/rpm-state/previous_version
fi

if [ $1 -eq 1 ] ; then
	echo "Running:  new"
    %{install_base}/scripts/configure_sysctl new
else
    echo "Running: configure_sysctl upgrade ${PREV_VERSION}"
    %{install_base}/scripts/configure_sysctl upgrade ${PREV_VERSION}
fi

%post servicewatcher


%files
%defattr(0644,perfsonar,perfsonar,0755)
%config(noreplace) %{config_base}/*
%exclude %{config_base}/default_system_firewall_settings.conf
%exclude %{config_base}/old_firewall_settings.conf
%exclude %{config_base}/perfsonar_firewall_settings.conf
%exclude %{config_base}/perfsonar_firewalld_settings.conf
%exclude %{config_base}/ntp_known_servers
%exclude %{config_base}/servicewatcher.conf
%exclude %{config_base}/servicewatcher-logger.conf
%exclude %{config_base}/templates/ntp_conf.tmpl
%exclude %{config_base}/default_service_configs/pg_hba.conf
%exclude %{config_base}/default_service_configs/pscheduler_limits.conf
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/*
%{install_base}/web-ng/*
/etc/httpd/conf.d/*
%attr(0640,root,root) /etc/sudoers.d/*
%attr(0644,root,root) /etc/cron.d/%{crontab_3}
# Make sure the cgi scripts are all executable
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/administrative_info/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/regular_testing/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/host.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/services.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/services/host.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/services/ntp.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/services/communities.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/services/regular_testing.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/tests.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/gui/reverse_traceroute.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/gui/services/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/services/host.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/services/communities.cgi
%if 0%{?el7}
%attr(0644,root,root) %{_unitdir}/%{init_script_1}.service
%else
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_1}
%endif
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_2}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_3}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_4}
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/add_psadmin_user
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/add_pssudo_user
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/clean_esmond_db.sh
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_cacti
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/%{cron_hourly_1}
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/manage_users
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/mod_interface_route
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/ps-toolkit-migrate-backup.sh
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/ps-toolkit-migrate-restore.sh
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/psb_to_esmond.pl
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/remove_home_partition
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/upgrade/*

%files systemenv
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/system_environment/*
%exclude %{install_base}/scripts/system_environment/configure_esmond 

%files security
%config %{config_base}/default_system_firewall_settings.conf
%config %{config_base}/old_firewall_settings.conf
%config %{config_base}/perfsonar_firewall_settings.conf
%config %{config_base}/perfsonar_firewalld_settings.conf
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_firewall
/usr/lib/firewalld/services/*.xml

%files install
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/nptoolkit-configure.py
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/install-optional-packages.py
%attr(0644,root,root) %{config_base}/default_service_configs/pscheduler_limits.conf

%files sysctl
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_sysctl

%files ntp
%config %{config_base}/ntp_known_servers
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/autoselect_ntp_servers
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_ntpd
%{config_base}/templates/ntp_conf.tmpl

%files library
%{install_base}/lib/perfSONAR_PS/*
%{install_base}/lib/OWP/*
%{install_base}/python_lib/*
%doc %{install_base}/doc/*

%files servicewatcher
%config(noreplace) %{config_base}/servicewatcher.conf
%config(noreplace) %{config_base}/servicewatcher-logger.conf
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/service_watcher
%attr(0644,root,root) /etc/cron.d/%{crontab_1}

%files compat-database
%attr(0644,root,root) %{config_base}/default_service_configs/pg_hba.conf
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/system_environment/configure_esmond 

%changelog
* Thu Mar 4 2015 sowmya@es.net
- Splitting out Install Script package and Toolkit library package

* Thu Feb 25 2015 sowmya@es.net
- Splitting service watcher

* Thu Feb 12 2015 sowmya@es.net
- Splitting ntp package

* Tue Feb 9 2015 sowmya@es.net
- Splitting out sysctl package

* Mon Feb 9 2015 sowmya@es.net 
- rpm bundling of iptables

* Thu Jun 19 2014 andy@es.net 3.4-4
- 3.4rc2 release

* Tue Oct 02 2012 asides@es.net 3.3-1
- 3.3 beta release
- Add support for LiveUSB and clean up rpm install output

* Fri Sep 07 2012 asides@es.net 3.2.2-6
- Changed System Environment post requires Internet2-repo to Internet2-epel6-repo
- Added package nscd as a requirement to the pSPS-Toolkit package

* Thu Jul 19 2012 asides@es.net 3.2.2-2
- Replaced aufs with aufs-util and kmod-aufs new packages for EL 6

* Tue Jun 26 2012 asides@es.net 3.2.2-2
- Removed firstboot-tui, kudzu, and yum-updatesd from System Environment package for compatibility with EL 6
- Replaced apmd with acpid and sysklogd with rsyslogd from System Environment package for compatibility with EL 6

* Tue Oct 19 2010 aaron@internet2.edu 3.2-6
- 3.2 final RPM release

* Wed Sep 08 2010 aaron@internet2.edu 3.2-4
- -rc4 RPM release

* Wed Sep 08 2010 aaron@internet2.edu 3.2-3
- -rc3 RPM release

* Wed Jun 18 2010 aaron@internet2.edu 3.2-1
- Initial -rc1 RPM release perfSONAR_PS-Toolkit-3.4.2.4.tar.gz
