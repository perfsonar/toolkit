%define _unpackaged_files_terminate_build 0

%define install_base /usr/lib/perfsonar
%define config_base /etc/perfsonar/toolkit
%define graphs_base %{install_base}/graphs

%define webng_config /usr/lib/perfsonar/web-ng/etc

%define apacheconf apache-toolkit_web_gui.conf
%define apacheconf_webservices apache-toolkit_web_services.conf
%define sudoerconf perfsonar_sudo

%define init_script_1 perfsonar-configdaemon
%define init_script_2 perfsonar-generate_motd
%define init_script_3 perfsonar-configure_nic_parameters

%define crontab_1     cron-service_watcher

%define perfsonar_auto_version 5.0.3
%define perfsonar_auto_relnum 1

Name:           perfsonar-toolkit
Version:        %{perfsonar_auto_version}
Release:        %{perfsonar_auto_relnum}%{?dist}
Summary:        perfSONAR Toolkit
License:        ASL 2.0
Group:          Applications/Communications
URL:            http://www.perfsonar.net/
Source0:        perfsonar-toolkit-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-root-%(%{__id_u} -n)
BuildArch:      noarch
Requires:       perl
Requires:       perl(CGI)
Requires:       perl(CGI::Ajax)
Requires:       perl(CGI::Carp)
Requires:       perl(CGI::Session)
Requires:       perl(Class::Accessor)
Requires:       perl(Config::General)
Requires:       perl(Cwd)
Requires:       perl(Data::Dumper)
Requires:       perl(Data::UUID)
Requires:       perl(Data::Validate::Domain)
Requires:       perl(Data::Validate::IP)
Requires:       perl(Date::Manip)
Requires:       perl(Digest::MD5)
Requires:       perl(English)
Requires:       perl(Exporter)
Requires:       perl(Fcntl)
Requires:       perl(File::Basename)
Requires:       perl(File::Spec)
Requires:       perl(FindBin)
Requires:       perl(Getopt::Long)
Requires:       perl(IO::File)
Requires:       perl(IO::Socket)
Requires:       perl-JSON-XS
Requires:       perl(LWP::Simple)
Requires:       perl(LWP::UserAgent)
Requires:       perl(Log::Log4perl)
Requires:       perl(Net::DNS)
Requires:       perl(Net::IP)
Requires:       perl(Net::IP)
Requires:       perl(Net::Ping)
Requires:       perl(Net::Server)
Requires:       perl(NetAddr::IP)
Requires:       perl(POSIX)
Requires:       perl(Params::Validate)
Requires:       perl(RPC::XML::Client)
Requires:       perl(RPC::XML::Server)
Requires:       perl(RPM2)
Requires:       perl(Regexp::Common)
Requires:       perl(Scalar::Util)
Requires:       perl(Socket)
Requires:       perl(Storable)
Requires:       perl(Sys::Hostname)
Requires:       perl(Sys::Statistics::Linux)
Requires:       perl(Template)
Requires:       perl(Term::ReadLine)
Requires:       perl(Time::HiRes)
Requires:       perl(Time::Local)
Requires:       perl(XML::LibXML) >= 1.60
Requires:       perl(XML::Simple)
Requires:       perl(XML::Twig)
Requires:       perl(aliased)
Requires:       perl(base)
Requires:       perl(lib)
Requires:       perl(utf8)
Requires:       perl(vars)
Requires:       perl(version)
Requires:       perl(warnings)
Patch0:         remove_host_admin_gui.patch
Patch1:         remove_ntp_configdaemon.patch

#perfSONAR packages
Requires:       perfsonar-common
Requires:       perfsonar-core
Requires:       perfsonar-lscachedaemon
Requires:       perfsonar-graphs
Requires:       perfsonar-psconfig-publisher
Requires:       perfsonar-traceroute-viewer
Requires:       libperfsonar-perl
Requires:       libperfsonar-regulartesting-perl
Requires:       libperfsonar-sls-perl
Requires:       libperfsonar-toolkit-perl
Requires:       perfsonar-toolkit-install
Requires:       perfsonar-toolkit-systemenv
Requires:       perfsonar-toolkit-web-services
Requires:       perfsonar-archive

# Misc performance/performance-related tools
Requires:       coreutils
Requires:       httpd
Requires:       mod_ssl
Requires:       nagios-plugins-all
BuildRequires:  systemd
%{?systemd_requires: %systemd_requires}

# SELinux support
BuildRequires: selinux-policy-devel
Requires: policycoreutils, libselinux-utils
Requires(post): selinux-policy-targeted, policycoreutils
Requires(postun): policycoreutils

# Unit test mock library
BuildRequires: perl-Test-MockObject

# Deep object comparision
BuildRequires: perl-Test-Deep

Obsoletes:      perl-perfSONAR_PS-TopologyService
Obsoletes:      perl-perfSONAR_PS-Toolkit
Provides:       perl-perfSONAR_PS-Toolkit

Requires(pre):  rpm
# Anaconda requires a Requires(post) to ensure that packages are installed before the %post section is run...
Requires(post): perl
Requires(post): perfsonar-lscachedaemon
Requires(post): perfsonar-lsregistrationdaemon
Requires(post): perfsonar-graphs
Requires(post): perfsonar-psconfig-pscheduler

Requires(post): perfsonar-common
Requires(post): perfsonar-archive
Requires(post): owamp-client    >= 3.5.0
Requires(post): owamp-server    >= 3.5.0
Requires(post): coreutils
Requires(post): httpd
Requires(post): iperf
Requires(post): mod_ssl
Requires(post): nscd


%description
The perfSONAR Toolkit web GUI and associated services.

%package systemenv-testpoint
Summary:        perfSONAR Testpoint System Configuration
Group:          Development/Tools
Requires:       perfsonar-psconfig-pscheduler
Requires:       nscd
%if 0%{?el7}
Requires:       yum-cron
%else
Requires:       dnf-automatic
%endif
Requires:       python3
Requires(post): owamp-server    >= 3.5.0
Requires(post): chkconfig
Requires(post): rsyslog
Provides:       perl-perfSONAR_PS-Toolkit-SystemEnvironment-Testpoint

%description systemenv-testpoint
Tunes and configures a testpoint system according to performance and
security best practices.


%package systemenv
Summary:        perfSONAR Toolkit System Configuration
Group:          Development/Tools
Requires:       perfsonar-toolkit-security
Requires:       perfsonar-toolkit-sysctl
Requires:       perfsonar-toolkit-servicewatcher
#TODO: Revisit this
%if 0%{?el7}
Requires:       perfsonar-toolkit-ntp
%else
Requires:       chrony
%endif
Requires:       perfsonar-toolkit-library
Requires:       perfsonar-toolkit-systemenv-testpoint
Requires:       python3
Requires(post): perfsonar-common
Requires(post): acpid
Requires(post): avahi
Requires(post): chkconfig
Requires(post): cups
Requires(post): httpd
Requires(post): irqbalance
Requires(post): mdadm
Requires(post): nfs-utils
Requires(post): pcsc-lite
Requires(post): rootfiles
Requires(post): drop-in
Requires(pre):  rpm
Requires(post): rsyslog
Requires(post): setup
Requires(post): smartmontools
Requires(post): sudo
Obsoletes:      perfsonar-toolkit-systemenv < 4.0
Obsoletes:      perl-perfSONAR_PS-Toolkit-SystemEnvironment
Provides:       perl-perfSONAR_PS-Toolkit-SystemEnvironment

%description systemenv
Tunes and configures the system according to performance and security best
practices.

%package archive-utils
Summary:        perfSONAR Archive configuration
Group:          Development/Tools
Requires:       perfsonar-archive

%description archive-utils
Configures pscheduler and logstash on perfSONAR hosts.

%package library
Summary:                perfSONAR Toolkit library
Group:                  Development/Tools
Requires:               perfsonar-common
Requires:               libperfsonar-toolkit-perl
Requires:               python3
Obsoletes:              perl-perfSONAR_PS-Toolkit-Library
Provides:               perl-perfSONAR_PS-Toolkit-Library

%description library
Installs the library files

%package web-services
Summary:        perfSONAR Toolkit Web Services
Group:          Development/Tools

# Needed for SELinux to configure properly
Requires:       perfsonar-lsregistrationdaemon
Requires:       owamp-server
Requires:       twamp-server

Requires:       perfsonar-toolkit-library
Requires:       httpd
Requires:       mod_ssl
Requires:       perl(CGI)
Requires:       perl(Log::Log4perl)
Requires:       perl(Log::Dispatch)
Requires:       perl(POSIX)
Requires:       perl(Data::Dumper)
Requires:       perl-JSON-XS
Requires:       perl(XML::Simple)
Requires:       perl(Config::General)
Requires:       perl(Time::HiRes)
Requires(post): httpd
Requires(post): perfsonar-lsregistrationdaemon
Requires(post): owamp-server
Requires(post): twamp-server
BuildRequires:  systemd

%description web-services
Contains web service for information used in monitoring a perfSONAR host

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
Requires:               firewalld
Requires:               fail2ban
Requires:               perfsonar-common
Requires:               httpd
Requires:               mod_ssl
Requires(pre):          rpm
Requires(post):         perfsonar-common
Requires(post):         coreutils
%if 0%{?el7}
Requires(post):         system-config-firewall-base
%endif
Requires(post):         kernel-devel
Requires(post):         kernel
Requires(post):         kernel-headers
Requires(post):         module-init-tools
Requires(post):         httpd
Requires(post):         mod_ssl
Obsoletes:              perl-perfSONAR_PS-Toolkit-security
Provides:               perl-perfSONAR_PS-Toolkit-security

%description security
Configures IPTables rules, installs fail2ban and secures apache for perfSONAR Toolkit

%package sysctl
Summary:                perfSONAR Toolkit sysctl configuration
Group:                  Development/Tools
Requires:               coreutils
Requires:               perfsonar-common
Requires:               libperfsonar-perl
Requires:               initscripts
%if 0%{?el7}
%else
#The following are needed to get htcp cc algorithm
Requires:               kernel-modules-extra
Requires(post):         kernel-modules-extra
%endif
Requires(pre):          rpm
Requires(post):         coreutils
Requires(post):         perfsonar-common
Requires(post):         libperfsonar-perl
Requires(post):         initscripts
Obsoletes:              perl-perfSONAR_PS-Toolkit-sysctl
Provides:               perl-perfSONAR_PS-Toolkit-sysctl

%description sysctl
Configures sysctl for the Toolkit

%package ntp
Summary:                perfSONAR Toolkit ntp configuration
Group:                  Development/Tools
Requires:               coreutils
#TODO: This will get it to build, but scripts do not yet work with chrony
%if 0%{?el7}
Requires:               ntp
%else
Requires:               chrony
%endif
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
%if 0%{?el7}
Requires:               ntp
%endif
Requires:               perfsonar-toolkit-library
Requires:               libperfsonar-toolkit-perl
Requires(pre):          rpm
Requires(post):         perfsonar-common
Requires(post):         coreutils
Obsoletes:              perl-perfSONAR_PS-Toolkit-service-watcher
Provides:               perl-perfSONAR_PS-Toolkit-service-watcher

%description servicewatcher
Installs the service-watcher package

%pre systemenv-testpoint
rm -rf %{_localstatedir}/lib/rpm-state
mkdir -p %{_localstatedir}/lib/rpm-state
rpm -q --queryformat "%%{RPMTAG_VERSION} %%{RPMTAG_RELEASE} " %{name} > %{_localstatedir}/lib/rpm-state/previous_version || :

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
%setup -q -n perfsonar-toolkit-%{version}
#remove hosts admin page for non-el7
%if 0%{?el7}
%else
%patch0 -p3
%patch1 -p3
%endif


%build
make -f /usr/share/selinux/devel/Makefile -C selinux perfsonar-toolkit.pp

%install
rm -rf %{buildroot}

make ROOTPATH=%{buildroot}/%{install_base} CONFIGPATH=%{buildroot}/%{config_base} install

install -D -m 0600 scripts/%{crontab_1} %{buildroot}/etc/cron.d/%{crontab_1}

install -D -m 0644 scripts/%{apacheconf} %{buildroot}/etc/httpd/conf.d/%{apacheconf}
install -D -m 0644 scripts/%{apacheconf_webservices} %{buildroot}/etc/httpd/conf.d/%{apacheconf_webservices}
install -D -m 0644 etc/apache-perfsonar-security.conf %{buildroot}/etc/httpd/conf.d/apache-perfsonar-security.conf
install -D -m 0640 etc/%{sudoerconf} %{buildroot}/etc/sudoers.d/%{sudoerconf}
install -D -m 0644 init_scripts/%{init_script_1}.service %{buildroot}/%{_unitdir}/%{init_script_1}.service
install -D -m 0755 init_scripts/%{init_script_2} %{buildroot}/etc/init.d/%{init_script_2}
install -D -m 0755 init_scripts/%{init_script_3} %{buildroot}/etc/init.d/%{init_script_3}
install -D -m 0644 archive/http_logstash.json %{buildroot}/etc/perfsonar/psconfig/archives.d/http_logstash.json

mkdir -p %{buildroot}/usr/lib/firewalld/services/
mv etc/firewalld/services/* %{buildroot}/usr/lib/firewalld/services/
rm -rf etc/firewalld

mkdir -p %{buildroot}/usr/share/selinux/packages/
mv selinux/*.pp %{buildroot}/usr/share/selinux/packages/
rm -rf %{buildroot}/usr/lib/perfsonar/selinux

mv etc/* %{buildroot}/%{config_base}

# Clean up unnecessary files
rm -rf %{buildroot}/%{install_base}/etc
rm -rf %{buildroot}/%{install_base}/scripts/%{crontab_1}
rm -rf %{buildroot}/%{install_base}/scripts/%{apacheconf}
rm -rf %{buildroot}/%{install_base}/scripts/%{apacheconf_webservices}
rm -rf %{buildroot}/%{install_base}/init_scripts

%clean
rm -rf %{buildroot}

%post
# Add a group of users who can login to the web ui
touch /etc/perfsonar/toolkit/psadmin.htpasswd
chgrp apache /etc/perfsonar/toolkit/psadmin.htpasswd
chmod 0640 /etc/perfsonar/toolkit/psadmin.htpasswd
/usr/sbin/groupadd -r pssudo 2> /dev/null || :

mkdir -p /var/lib/perfsonar/log_view/ndt    
mkdir -p /var/lib/perfsonar/log_view/owamp

if [ $1 -eq 1 ] ; then
    #make sure we trash pre-3.5.1 config_daemon
    /etc/init.d/config_daemon stop &>/dev/null || :
    chkconfig --del config_daemon &>/dev/null || :
fi


mkdir -p /var/run/web_admin_sessions
chown apache /var/run/web_admin_sessions

mkdir -p /var/run/toolkit/

# Install a link to the logs into the web location
ln -sT /var/log/perfsonar %{install_base}/web-ng/root/admin/logs 2> /dev/null

#Set bundle type and version
echo "perfsonar-toolkit" > /var/lib/perfsonar/bundles/bundle_type
echo "%{version}-%{release}" > /var/lib/perfsonar/bundles/bundle_version
chmod 644 /var/lib/perfsonar/bundles/bundle_type
chmod 644 /var/lib/perfsonar/bundles/bundle_version

#symlink to pcheduler logs
chmod 755 /var/log/pscheduler/
touch /var/log/pscheduler/pscheduler.log
chmod 644 /var/log/pscheduler/pscheduler.log
ln -s /var/log/pscheduler/pscheduler.log /var/log/perfsonar/pscheduler.log 2> /dev/null

#symlink to web config files
ln -sT /usr/lib/perfsonar/web-ng/etc /etc/perfsonar/toolkit/web 2> /dev/null

# we need all these things readable the CGIs (XXX: the configuration daemon
# should be how they read these, but that'd require a fair number of changes,
# so we'll put that in the "maybe" category.
chmod o+r /etc/perfsonar/lsregistrationdaemon.conf
%if 0%{?el7}
chmod o+r %{config_base}/ntp_known_servers
%endif
chmod o+r /etc/owamp-server/owamp-server.limits 2> /dev/null
chmod o+r /etc/owamp-server/owamp-server.pfs 2> /dev/null
chkconfig --add %{init_script_2}
chkconfig --add %{init_script_3}
systemctl --quiet enable %{init_script_1}
chkconfig %{init_script_2} on
chkconfig %{init_script_3} on

# apache needs to be on for the toolkit to work
chkconfig --level 2345 httpd on

#Restart pscheduler daemons to make sure they got all tests, tools, and archivers
#also psconfig-pscheduler-agent because it needs pscheduler
systemctl restart httpd &>/dev/null || :
systemctl restart pscheduler-archiver &>/dev/null || :
systemctl restart pscheduler-runner &>/dev/null || :
systemctl restart pscheduler-scheduler &>/dev/null || :
systemctl restart pscheduler-ticker &>/dev/null || :
systemctl restart psconfig-pscheduler-agent &>/dev/null || :

#Restart config_daemon, generate MOTD and fix nic parameters
systemctl restart %{init_script_1} &>/dev/null || :
/etc/init.d/%{init_script_2} start &>/dev/null || :
/etc/init.d/%{init_script_3} start &>/dev/null || :

%post systemenv-testpoint
if [ -f %{_localstatedir}/lib/rpm-state/previous_version ] ; then
    PREV_VERSION=`cat %{_localstatedir}/lib/rpm-state/previous_version`
    rm %{_localstatedir}/lib/rpm-state/previous_version
fi

for script in %{install_base}/scripts/system_environment/testpoint/*; do
    if [ $1 -eq 1 ] ; then
        echo "Running: $script new"
        $script new
    else
        echo "Running: $script upgrade ${PREV_VERSION}"
        $script upgrade ${PREV_VERSION}
    fi
done


%post systemenv
if [ -f %{_localstatedir}/lib/rpm-state/previous_version ] ; then
    PREV_VERSION=`cat %{_localstatedir}/lib/rpm-state/previous_version`
    rm %{_localstatedir}/lib/rpm-state/previous_version
fi

for script in %{install_base}/scripts/system_environment/*; do
    if [ -f $script ]; then
        if [ $1 -eq 1 ] ; then
            echo "Running: $script new"
            $script new
        else
            echo "Running: $script upgrade ${PREV_VERSION}"
            $script upgrade ${PREV_VERSION}
        fi
    fi
done

%post web-services
#Enable selinux
semodule -n -i /usr/share/selinux/packages/perfsonar-toolkit.pp
if /usr/sbin/selinuxenabled; then
    /usr/sbin/load_policy
fi
#log directory
mkdir -p /var/log/perfsonar/web_admin
chown apache:perfsonar /var/log/perfsonar/web_admin

%postun web-services
if [ $1 -eq 0 ]; then
    semodule -n -r perfsonar-toolkit
    if /usr/sbin/selinuxenabled; then
       /usr/sbin/load_policy
    fi
fi

#Create log directory
mkdir -p /var/log/perfsonar/web_admin
chown apache:perfsonar /var/log/perfsonar/web_admin

#Restart apache to pickup config
systemctl restart httpd &>/dev/null || :

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

%post security

#configuring firewall
echo "Running: configure_firewall install"
%{install_base}/scripts/configure_firewall install

#enabling services
systemctl enable firewalld
systemctl enable fail2ban

#configure memcached
%{install_base}/scripts/configure_memcached_security

#configure apache
if [ $1 -eq 1 ] ; then
    %{install_base}/scripts/configure_apache_security new
else
    %{install_base}/scripts/configure_apache_security upgrade
fi
systemctl restart httpd &>/dev/null || :

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


%post archive-utils

#configure http archiver
#Note: This should likely be in a script
if [ -f /etc/perfsonar/logstash/proxy_auth.json ] ; then
    AUTH_HEADER=`cat /etc/perfsonar/logstash/proxy_auth.json`
    HAS_AUTH=$(grep "$AUTH_HEADER" /etc/perfsonar/psconfig/archives.d/http_logstash.json)
    if [ -z $HAS_AUTH ]; then
        sed -i "s|http://localhost:11283|https://{% scheduled_by_address %}/logstash|g" /etc/perfsonar/psconfig/archives.d/http_logstash.json
        sed -i "s|\"content-type\": \"application/json\"|\"content-type\": \"application/json\", ${AUTH_HEADER}|g" /etc/perfsonar/psconfig/archives.d/http_logstash.json
    fi
fi

%files
%defattr(0644,perfsonar,perfsonar,0755)
%license LICENSE
%config(noreplace) %{config_base}/*
%exclude %{config_base}/default_system_firewall_settings.conf
%exclude %{config_base}/perfsonar_firewall_settings.conf
%exclude %{config_base}/perfsonar_firewalld_settings.conf
%exclude %{config_base}/ntp_known_servers
%exclude %{config_base}/servicewatcher.conf
%exclude %{config_base}/servicewatcher-logger.conf
%exclude %{config_base}/templates/ntp_conf.tmpl
%exclude %{config_base}/default_service_configs/pscheduler_limits.conf
%exclude %{config_base}/perfsonar_ulimit.conf
%exclude %{config_base}/perfsonar_ulimit_apache.conf
%exclude /etc/httpd/conf.d/apache-perfsonar-security.conf
%exclude /etc/httpd/conf.d/%{apacheconf_webservices}
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/*
%{install_base}/web-ng/*
%exclude %{install_base}/web-ng/root/services/*
/etc/httpd/conf.d/*
%attr(0640,root,root) /etc/sudoers.d/*
# Make sure the cgi scripts are all executable
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/administrative_info/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/regular_testing/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/host.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/index.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/services/host.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/services/ntp.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/services/communities.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/services/regular_testing.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/tests.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/admin/plot.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/gui/reverse_traceroute.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/index.cgi
%attr(0644,root,root) %{_unitdir}/%{init_script_1}.service
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_2}
%attr(0755,perfsonar,perfsonar) /etc/init.d/%{init_script_3}
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/add_psadmin_user
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/add_pssudo_user
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/find_bwctl_measurements
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/manage_users
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/remove_home_partition

%files systemenv-testpoint
%license LICENSE
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/system_environment/testpoint/*
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/mod_interface_route

%files systemenv
%license LICENSE
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/system_environment/*
%exclude %{install_base}/scripts/system_environment/testpoint

%files security
%license LICENSE
%config %{config_base}/default_system_firewall_settings.conf
%config %{config_base}/perfsonar_firewall_settings.conf
%config %{config_base}/perfsonar_firewalld_settings.conf
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_firewall
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_apache_security
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_memcached_security
/etc/httpd/conf.d/apache-perfsonar-security.conf
/usr/lib/firewalld/services/*.xml

%files install
%license LICENSE
%config(noreplace) %{config_base}/perfsonar_ulimit.conf
%config(noreplace) %{config_base}/perfsonar_ulimit_apache.conf
%attr(0644,root,root) %{config_base}/perfsonar_ulimit.conf
%attr(0644,root,root) %{config_base}/perfsonar_ulimit_apache.conf
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/nptoolkit-configure.py
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/ps-migrate-backup.sh
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/ps-migrate-restore.sh
%attr(0644,root,root) %{config_base}/default_service_configs/pscheduler_limits.conf

%files sysctl
%license LICENSE
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_sysctl

%files ntp
%license LICENSE
%config %{config_base}/ntp_known_servers
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/autoselect_ntp_servers
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/configure_ntpd
%{config_base}/templates/ntp_conf.tmpl

%files library
%license LICENSE
%{install_base}/lib/perfSONAR_PS/*
%{install_base}/lib/OWP/*
%{install_base}/python_lib/*
%doc %{install_base}/doc/*

%files web-services
%defattr(0644,perfsonar,perfsonar,0755)
%config(noreplace) %{webng_config}/*
%attr(0644,root,root) /usr/share/selinux/packages/*
%{install_base}/web-ng/root/services/*
/etc/httpd/conf.d/%{apacheconf_webservices}
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/services/host.cgi
%attr(0755,perfsonar,perfsonar) %{install_base}/web-ng/root/services/communities.cgi

%files servicewatcher
%license LICENSE
%config(noreplace) %{config_base}/servicewatcher.conf
%config(noreplace) %{config_base}/servicewatcher-logger.conf
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/service_watcher
%attr(0644,root,root) /etc/cron.d/%{crontab_1}

%files archive-utils
%license LICENSE
%config(noreplace) /etc/perfsonar/psconfig/archives.d/http_logstash.json

%changelog
* Tue Oct 22 2021 daniel.neto@rnp.br
- Adding archive-utils package

* Tue Sep 21 2021 daniel.neto@rnp.br
- Removing esmond and cassandra references

* Wed Apr 19 2017 andy@es.net
- Adding back NDT firewall ports

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
