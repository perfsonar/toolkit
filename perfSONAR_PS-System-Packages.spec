%define install_base /opt/perfsonar_ps/toolkit

%define relnum 1
%define disttag pSPS

Name:			perl-perfSONAR_PS-System
Version:		3.4.1
Release:		%{relnum}.%{disttag}
Summary:		perfSONAR_PS System
License:		Distributable, see LICENSE
Group:			Development/Libraries
Source0:		perfSONAR_PS-Toolkit-%{version}.%{relnum}.tar.gz
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:		noarch

%description
The perfSONAR_PS System Package installs system related packages

%package ps-security
Summary:		Install security packages for perfsonar
Group:			Development/Libraries
Requires:               fail2ban
Requires:               iptables
Requires:		coreutils
Requires:		shadow-utils
Requires:		chkconfig

%description ps-security
Package for installing security related packages for perfsonar

%pre
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%pre ps-security
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfSONAR_PS-System-%{version}.%{relnum}

%build

%install
rm -rf %{buildroot}

make ROOTPATH=%{buildroot}/%{install_base} rpminstall

%post ps-security
mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar

%clean
rm -rf %{buildroot}

%files ps-security
%defattr(-,perfsonar,perfsonar,-)
%config %{install_base}/etc/default_system_firewall_settings.conf
%config %{install_base}/etc/old_firewall_settings.conf
%config %{install_base}/etc/perfsonar_firewall_settings.conf
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/system_environment/configure_firewall
%{install_base}/dependencies
%{install_base}/doc/*

%changelog
* Thu Feb 4 2015 sowmya@es.net 3.5
- Initial RPM build
