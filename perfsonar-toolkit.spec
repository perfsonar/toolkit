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

%define relnum  0.0.a1 

Name:			perfsonar-toolkit
Version:		3.5.1
Release:		%{relnum}
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
Requires:		perl(Class::Fields)
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
Requires:		perl(IO::Interface)
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
Requires:		perfsonar-lscachedaemon
Requires:		perfsonar-lsregistrationdaemon
Requires:		perfsonar-graphs
Requires:		perfsonar-regulartesting
Requires:		perfsonar-meshconfig-agent
Requires:		perfsonar-meshconfig-jsonbuilder
Requires:       perfsonar-oppd-bwctl
Requires:       perfsonar-oppd-owamp
Requires:       libperfsonar-toolkit-perl
Requires:       perfsonar-toolkit-install
Requires:       perfsonar-toolkit-systemenv

#perfSONAR service packages
Requires:		esmond          >= 2.0
Requires:		bwctl-client    >= 1.6.0
Requires:		bwctl-server    >= 1.6.0
Requires:		ndt
Requires:		owamp-client    >= 3.5.0
Requires:		owamp-server    >= 3.5.0

# Misc performance/performance-related tools
Requires:		nuttcp
Requires:		iperf
Requires:		iperf3
Requires:		paris-traceroute
Requires:		tcptrace
Requires:		xplot-tcptrace
Requires:		coreutils
Requires:		httpd
Requires:		mod_auth_shadow
Requires:		mod_ssl
Requires:		nagios-plugins-all
Requires:		nscd
Requires:		yum-cron

Obsoletes:		perl-perfSONAR_PS-TopologyService
Obsoletes:		perl-perfSONAR_PS-Toolkit
Provides:       perl-perfSONAR_PS-Toolkit

Requires(pre):	rpm
# Anaconda requires a Requires(post) to ensure that packages are installed before the %post section is run...
Requires(post):	perl
Requires(post):	perfsonar-lscachedaemon
Requires(post):	perfsonar-lsregistrationdaemon
Requires(post):	perfsonar-graphs
Requires(post):	perfsonar-regulartesting

Requires(post):	perfsonar-common
Requires(post):	esmond          >= 2.0
Requires(post):	bwctl-client    >= 1.6.0
Requires(post):	bwctl-server    >= 1.6.0
Requires(post):	ndt
Requires(post):	owamp-client    >= 3.5.0
Requires(post):	owamp-server    >= 3.5.0

Requires(post):	coreutils
Requires(post):	httpd
Requires(post):	iperf
Requires(post):	mod_auth_shadow
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
Requires(post):	bwctl-server    >= 1.6.0
Requires(post):	owamp-server    >= 3.5.0
Requires(post):	acpid
Requires(post):	avahi
Requires(post):	bluez-utils
Requires(post):	chkconfig
Requires(post): cpuspeed
Requires(post):	cups
Requires(post):	hal
Requires(post):	httpd
Requires(post):	irda-utils
Requires(post):	irqbalance
Requires(post):	mdadm
Requires(post):	nfs-utils
Requires(post):	pcsc-lite
Requires(post):	readahead
Requires(post):	rootfiles
Requires(pre):	rpm
Requires(post):	rsyslog
Requires(post):	setup
Requires(post):	smartmontools
Requires(post):	sudo
Obsoletes:		perl-perfSONAR_PS-Toolkit-SystemEnvironment
Provides:       perl-perfSONAR_PS-Toolkit-SystemEnvironment

%description systemenv
Tunes and configures the system according to performance and security best
practices.

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
Requires:               iptables
Requires:               iptables-ipv6
Requires:               fail2ban
Requires:               perfsonar-common
Requires(pre):          rpm
Requires(post):         perfsonar-common
Requires(post):         coreutils
Requires(post):         system-config-firewall-base
Requires(post):         chkconfig
Requires(post):         kernel-devel
Requires(post):         kernel
Requires(post):         kernel-headers
Requires(post):         iptables
Requires(post):         iptables-ipv6
Obsoletes:              perl-perfSONAR_PS-Toolkit-security
Provides:               perl-perfSONAR_PS-Toolkit-security

%description security
Configures IPTables rules and installs fail2ban for perfSONAR Toolkit

%package sysctl
Summary:                perfSONAR Toolkit sysctl configuration
Group:                  Development/Tools
Requires:               coreutils
Requires:               perfsonar-common
Requires(pre):          rpm
Requires(post):         coreutils
Requires(post):         perfsonar-common
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

install -D -m 0755 init_scripts/%{init_script_1} %{buildroot}/etc/init.d/%{init_script_1}
install -D -m 0755 init_scripts/%{init_script_2} %{buildroot}/etc/init.d/%{init_script_2}
install -D -m 0755 init_scripts/%{init_script_3} %{buildroot}/etc/init.d/%{init_script_3}
install -D -m 0755 init_scripts/%{init_script_4} %{buildroot}/etc/init.d/%{init_script_4}

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
/usr/sbin/groupadd psadmin 2> /dev/null || :
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
elif [ $1 -eq 2 ] ; then
    #make sure web_admin.conf points to the right lscache directory
    sed -i "s:/var/lib/perfsonar/ls_cache:/var/lib/perfsonar/lscache:g" %{install_base}/web-ng/etc/web_admin.conf
    sed -i "s:/var/lib/perfsonar/ls_cache:/var/lib/perfsonar/lscache:g" %{install_base}/web/root/admin/administrative_info/etc/web_admin.conf
    sed -i "s:/var/lib/perfsonar/ls_cache:/var/lib/perfsonar/lscache:g" %{install_base}/web/root/admin/regular_testing/etc/web_admin.conf
fi


mkdir -p /var/run/web_admin_sessions
chown apache /var/run/web_admin_sessions

mkdir -p /var/run/toolkit/

# Modify the perfsonar-graphs CGIs to use the toolkit's header/footer/sidebar
ln -sf %{install_base}/web/templates/header.tmpl %{graphs_base}/templates/
ln -sf %{install_base}/web/templates/sidebar.html %{graphs_base}/templates/
ln -sf %{install_base}/web/templates/footer.tmpl %{graphs_base}/templates/

# Install a link to the logs into the web location
ln -sf /var/log/perfsonar %{install_base}/web/root/admin/logs
ln -sf /var/log/perfsonar %{install_base}/web-ng/root/admin/logs

# Install links to the toolkit header/footer/sidebar in the log_view
ln -sf %{install_base}/web/templates/header.tmpl %{install_base}/web/root/admin/log_view/templates/
ln -sf %{install_base}/web/templates/sidebar.html %{install_base}/web/root/admin/log_view/templates/
ln -sf %{install_base}/web/templates/footer.tmpl %{install_base}/web/root/admin/log_view/templates/

# Overwrite the existing configuration files for the services with new
# configuration files containing the default settings.
cp -f %{config_base}/default_service_configs/lsregistrationdaemon.conf /etc/perfsonar/lsregistrationdaemon.conf

#Remove old pS-NPToolkit-* community from admin_info (removal added in version 3.4)
grep -v "site_project=pS-NPToolkit-" %{config_base}/administrative_info > %{config_base}/administrative_info.tmp
mv %{config_base}/administrative_info.tmp %{config_base}/administrative_info

#Set bundle type and version
echo "perfsonar-toolkit" > /var/lib/perfsonar/bundles/bundle_type
echo "%{version}" > /var/lib/perfsonar/bundles/bundle_version
chmod 644 /var/lib/perfsonar/bundles/bundle_type
chmod 644 /var/lib/perfsonar/bundles/bundle_version

#Make sure that the administrator_info file gets reloaded
%{install_base}/scripts/update_administrative_info.pl 2> /dev/null

# we need all these things readable the CGIs (XXX: the configuration daemon
# should be how they read these, but that'd require a fair number of changes,
# so we'll put that in the "maybe" category.
chmod o+r /etc/perfsonar/lsregistrationdaemon.conf
chmod o+r %{config_base}/administrative_info
chmod o+r %{config_base}/ntp_known_servers
chmod o+r /etc/bwctl-server/bwctl-server.limits 2> /dev/null
chmod o+r /etc/bwctl-server/bwctl-server.keys 2> /dev/null
chmod o+r /etc/owamp-server/owamp-server.limits 2> /dev/null
chmod o+r /etc/owamp-server/owamp-server.pfs 2> /dev/null

chkconfig --add %{init_script_1}
chkconfig --add %{init_script_2}
chkconfig --add %{init_script_3}
chkconfig --add %{init_script_4}

chkconfig %{init_script_1} on
chkconfig %{init_script_2} on
chkconfig %{init_script_3} on
chkconfig %{init_script_4} on

# apache needs to be on for the toolkit to work
chkconfig --level 2345 httpd on

#adding cassandra and postgres for esmond
chkconfig --add cassandra
chkconfig cassandra on
chkconfig postgresql on

#Restart config_daemon and fix nic parameters
/etc/init.d/%{init_script_1} restart &>/dev/null || :
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
cat >> /root/.bashrc <<EOF
# Run the add_psadmin_user script to ensure that a psadmin user has been created
%{install_base}/scripts/add_psadmin_user --auto
# Run the add_pssudo_user script to encourage disabling root ssh
%{install_base}/scripts/add_pssudo_user --auto
EOF


#########################################################################
# The system environment scripts monkey with the apache configuration, so
# reload apache when we're done. We use reload here so that we don't start
# Apache if the administrator has shut it down for some reason
#########################################################################
service httpd reload || :

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
chkconfig iptables on
chkconfig ip6tables on
chkconfig fail2ban on

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
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/*
%{install_base}/web/*
%{install_base}/web-ng/*
%config(noreplace) %{install_base}/web/root/gui/services/etc/web_admin.conf
/etc/httpd/conf.d/*
%attr(0640,root,root) /etc/sudoers.d/*
%attr(0644,root,root) /etc/cron.d/%{crontab_3}
# Make sure the cgi scripts are all executable
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/services/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/reverse_traceroute.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/gui/psTracerouteViewer/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/regular_testing/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/ntp/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/administrative_info/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/enabled_services/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/log_view/bwctl.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/log_view/ndt.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web/root/admin/log_view/owamp.cgi
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
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/gui/psTracerouteViewer/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/gui/reverse_traceroute.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/gui/services/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/services/host.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/services/communities.cgi
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_1}
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
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/update_administrative_info.pl
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/upgrade/*

%files systemenv
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/system_environment/*

%files security
%config %{config_base}/default_system_firewall_settings.conf
%config %{config_base}/old_firewall_settings.conf
%config %{config_base}/perfsonar_firewall_settings.conf
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_firewall

%files install
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/nptoolkit-configure.py
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/install-optional-packages.py

%files sysctl
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_sysctl

%files ntp
%config %{config_base}/ntp_known_servers
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/autoselect_ntp_servers
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_ntpd
%{config_base}/templates/ntp_conf.tmpl

%files library
%{install_base}/lib/*
%{install_base}/python_lib/*
%doc %{install_base}/doc/*

%files servicewatcher
%config(noreplace) %{config_base}/servicewatcher.conf
%config(noreplace) %{config_base}/servicewatcher-logger.conf
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/service_watcher
%attr(0644,root,root) /etc/cron.d/%{crontab_1}

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
