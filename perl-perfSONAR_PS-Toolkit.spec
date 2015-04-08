%define _unpackaged_files_terminate_build 0
%define install_base /opt/perfsonar_ps/toolkit-ng

%define apacheconf apache-toolkit-ng_web_gui.conf

%define init_script_1 config_daemon
%define init_script_2 generate_motd
%define init_script_3 configure_nic_parameters
%define init_script_4 psb_to_esmond

%define crontab_1     cron-service_watcher
%define crontab_3     cron-clean_esmond_db

%define cron_hourly_1 logscraper.cron

%define relnum  12 
%define disttag pSPS

Name:			perl-perfSONAR_PS-Toolkit-ng
Version:		3.4.2
Release:		%{relnum}.%{disttag}
Summary:		perfSONAR_PS Toolkit (Next Generation)
License:		Distributable, see LICENSE
Group:			Applications/Communications
URL:			http://www.perfsonar.net/
Source0:		perfSONAR_PS-Toolkit-ng-%{version}.%{relnum}.tar.gz
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
Requires:               perl(File::Spec)
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

Requires:		esmond
Requires:		perl-perfSONAR_PS-LSCacheDaemon
Requires:		perl-perfSONAR_PS-LSRegistrationDaemon
Requires:		perl-perfSONAR_PS-serviceTest
Requires:		perl-perfSONAR_PS-RegularTesting
Requires:		perl-perfSONAR_PS-MeshConfig-JSONBuilder
Requires:       perl-perfSONAR-OPPD-MP-BWCTL
Requires:       perl-perfSONAR-OPPD-MP-OWAMP

Requires:		bwctl-client
Requires:		bwctl-server
Requires:		ndt
Requires:		npad
Requires:		owamp-client
Requires:		owamp-server

# Misc performance/performance-related tools
Requires:		nuttcp
Requires:		iperf
Requires:		tcptrace

Requires:		coreutils
Requires:		httpd
Requires:		mod_auth_shadow
Requires:		mod_ssl
Requires:               nagios-plugins-all
Requires:		nscd
Requires:		ntp
Requires:		fail2ban
Requires:		iptables
Requires:		iptables-ipv6
Requires:		yum-cron

Obsoletes:		perl-perfSONAR_PS-TopologyService

# Anaconda requires a Requires(post) to ensure that packages are installed before the %post section is run...
Requires(post):	perl
Requires(post):	perl-perfSONAR_PS-LSCacheDaemon
Requires(post):	perl-perfSONAR_PS-LSRegistrationDaemon
Requires(post):	perl-perfSONAR_PS-serviceTest
Requires(post):	esmond
Requires(post):	perl-perfSONAR_PS-RegularTesting

Requires(post):	bwctl-client
Requires(post):	bwctl-server
Requires(post):	ndt
Requires(post):	npad
Requires(post):	owamp-client
Requires(post):	owamp-server

Requires(post):	coreutils
Requires(post):	httpd
Requires(post):	iperf
Requires(post):	mod_auth_shadow
Requires(post):	mod_ssl
Requires(post):	nscd
Requires(post):	ntp

%description
The pS-Performance Toolkit Next Generation web GUI and associated services.

%package SystemEnvironment
Summary:		pS-Performance Toolkit NetInstall System Configuration
Group:			Development/Tools
Requires:		perl-perfSONAR_PS-Toolkit-ng
Requires(post):	Internet2-repo
Requires(post):	bwctl-server
Requires(post):	owamp-server

Requires(post):	acpid
Requires(post):	avahi
Requires(post):	bluez-utils
Requires(post): cpuspeed
Requires(post):	cups
Requires(post):	hal
Requires(post):	httpd
Requires(post):	irda-utils
Requires(post):	irqbalance
Requires(post):	mdadm
Requires(post):	mysql
Requires(post):	mysql-server
Requires(post):	nfs-utils
Requires(post):	ntp
Requires(post):	pcsc-lite
Requires(post):	php-common
Requires(post):	readahead
Requires(post):	rootfiles
Requires(post):	rsyslog
Requires(post):	setup
Requires(post):	smartmontools
Requires(post):	sudo
Requires(post): system-config-firewall-base

%description SystemEnvironment
Tunes and configures the system according to performance and security best
practices.

%pre
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%pre SystemEnvironment
rm -rf %{_localstatedir}/lib/rpm-state
mkdir -p %{_localstatedir}/lib/rpm-state
rpm -q --queryformat "%%{RPMTAG_VERSION} %%{RPMTAG_RELEASE} " %{name} > %{_localstatedir}/lib/rpm-state/previous_version || :

%prep
%setup -q -n perfSONAR_PS-Toolkit-%{version}.%{relnum}

%build

%install
rm -rf %{buildroot}

make ROOTPATH=%{buildroot}/%{install_base} rpminstall

install -D -m 0600 scripts/%{crontab_1} %{buildroot}/etc/cron.d/%{crontab_1}
install -D -m 0600 scripts/%{crontab_3} %{buildroot}/etc/cron.d/%{crontab_3}

install -D -m 0600 scripts/%{cron_hourly_1} %{buildroot}/etc/cron.hourly/%{cron_hourly_1}

install -D -m 0644 scripts/%{apacheconf} %{buildroot}/etc/httpd/conf.d/%{apacheconf}

install -D -m 0755 init_scripts/%{init_script_1} %{buildroot}/etc/init.d/%{init_script_1}
install -D -m 0755 init_scripts/%{init_script_2} %{buildroot}/etc/init.d/%{init_script_2}
install -D -m 0755 init_scripts/%{init_script_3} %{buildroot}/etc/init.d/%{init_script_3}
install -D -m 0755 init_scripts/%{init_script_4} %{buildroot}/etc/init.d/%{init_script_4}

# Clean up unnecessary files
rm -rf %{buildroot}/%{install_base}/scripts/%{crontab_1}
rm -rf %{buildroot}/%{install_base}/scripts/%{crontab_3}
rm -rf %{buildroot}/%{install_base}/scripts/%{cron_hourly_1}
rm -rf %{buildroot}/%{install_base}/scripts/%{apacheconf}

%clean
rm -rf %{buildroot}

%post
# Add a group of users who can login to the web ui
/usr/sbin/groupadd psadmin 2> /dev/null || :

mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar
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
fi


mkdir -p /var/run/web_admin_sessions
chown apache /var/run/web_admin_sessions

mkdir -p /var/run/toolkit-ng/

# Modify the perl-perfSONAR_PS-serviceTest CGIs to use the toolkit-ng's header/footer/sidebar
ln -sf /opt/perfsonar_ps/toolkit-ng/web/templates/header.tmpl /opt/perfsonar_ps/serviceTest/templates/
ln -sf /opt/perfsonar_ps/toolkit-ng/web/templates/sidebar.html /opt/perfsonar_ps/serviceTest/templates/
ln -sf /opt/perfsonar_ps/toolkit-ng/web/templates/footer.tmpl /opt/perfsonar_ps/serviceTest/templates/

# Install a link to the logs into the web location
ln -sf /var/log/perfsonar /opt/perfsonar_ps/toolkit-ng/web/root/admin/logs

# Overwrite the existing configuration files for the services with new
# configuration files containing the default settings.
cp -f /opt/perfsonar_ps/toolkit-ng/etc/default_service_configs/ls_registration_daemon.conf /opt/perfsonar_ps/ls_registration_daemon/etc/ls_registration_daemon.conf

#Remove old pS-NPToolkit-* community from admin_info (removal added in version 3.4)
grep -v "site_project=pS-NPToolkit-ng" /opt/perfsonar_ps/toolkit-ng/etc/administrative_info > /opt/perfsonar_ps/toolkit-ng/etc/administrative_info.tmp
mv /opt/perfsonar_ps/toolkit-ng/etc/administrative_info.tmp /opt/perfsonar_ps/toolkit-ng/etc/administrative_info

#Make sure that the administrator_info file gets reloaded
/opt/perfsonar_ps/toolkit-ng/scripts/update_administrative_info.pl 2> /dev/null

# we need all these things readable the CGIs (XXX: the configuration daemon
# should be how they read these, but that'd require a fair number of changes,
# so we'll put that in the "maybe" category.
chmod o+r /opt/perfsonar_ps/ls_registration_daemon/etc/ls_registration_daemon.conf
chmod o+r /opt/perfsonar_ps/toolkit-ng/etc/administrative_info
chmod o+r /opt/perfsonar_ps/toolkit-ng/etc/enabled_services
chmod o+r /opt/perfsonar_ps/toolkit-ng/etc/ntp_known_servers
chmod o+r /etc/bwctld/bwctld.limits 2> /dev/null
chmod o+r /etc/bwctld/bwctld.keys 2> /dev/null
chmod o+r /etc/owampd/owampd.limits 2> /dev/null
chmod o+r /etc/owampd/owampd.pfs 2> /dev/null

chkconfig --add %{init_script_1}
chkconfig --add %{init_script_2}
chkconfig --add %{init_script_3}
chkconfig --add %{init_script_4}

chkconfig %{init_script_1} on
chkconfig %{init_script_2} on
chkconfig %{init_script_3} on
chkconfig %{init_script_4} on

chkconfig fail2ban on
# apache needs to be on for the toolkit-ng to work
chkconfig --level 2345 httpd on

#starting iptables
chkconfig iptables on
chkconfig ip6tables on

#adding cassandra and postgres for esmond
chkconfig --add cassandra
chkconfig cassandra on
chkconfig postgresql on

%post SystemEnvironment
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

# Add a script to inspire them to create a 'psadmin' user if they don't already have one
if [ $1 -eq 1 ] ; then
cat >> /root/.bashrc <<EOF
# Run the add_psadmin_user script to ensure that a psadmin user has been created
/opt/perfsonar_ps/toolkit-ng/scripts/add_psadmin_user --auto
EOF
fi

#########################################################################
# The system environment scripts monkey with the apache configuration, so
# reload apache when we're done. We use reload here so that we don't start
# Apache if the administrator has shut it down for some reason
#########################################################################
service httpd reload || :

%files
%defattr(0644,perfsonar,perfsonar,0755)
%doc %{install_base}/doc/*
%config(noreplace) %{install_base}/etc/*
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/*
%{install_base}/lib/*
%{install_base}/python_lib/*
%{install_base}/web/*
%config(noreplace) %{install_base}/web/root/gui/services/etc/web_admin.conf
%{install_base}/templates/*
%{install_base}/dependencies
/etc/httpd/conf.d/*
%attr(0644,root,root) /etc/cron.d/%{crontab_1}
%attr(0644,root,root) /etc/cron.d/%{crontab_3}
%attr(0755,root,root) /etc/cron.hourly/%{cron_hourly_1}
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
%attr(0755,perfsonar,perfsonar) %{install_base}/init_scripts/%{init_script_1}
%attr(0755,perfsonar,perfsonar) %{install_base}/init_scripts/%{init_script_2}
%attr(0755,perfsonar,perfsonar) %{install_base}/init_scripts/%{init_script_3}
%attr(0755,perfsonar,perfsonar) %{install_base}/init_scripts/%{init_script_4}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_1}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_2}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_3}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_4}
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/add_psadmin_user
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/autoselect_ntp_servers
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/clean_esmond_db.sh
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_cacti
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/manage_users
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/mod_interface_route
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/nptoolkit-configure.py
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/NPToolkit.version
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/ps-toolkit-migrate-backup.sh
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/ps-toolkit-migrate-restore.sh
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/psb_to_esmond.pl
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/remove_home_partition
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/service_watcher
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/update_administrative_info.pl
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/upgrade/*

%files SystemEnvironment
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/system_environment/*

%changelog
* Wed Apr 8 2015 mj82@grnoc.iu.edu 3.4-5
- Create -ng package

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
- Initial -rc1 RPM release
