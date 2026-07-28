#
# RPM Spec for perfSONAR Web Front Page
#

%define perfsonar_auto_version 5.3.0
%define perfsonar_auto_relnum 0.a1.0

Name:		perfsonar-web-front-page
Version:        %{perfsonar_auto_version}
Release:        %{perfsonar_auto_relnum}%{?dist}

Summary:	Front page for perfSONAR nodes with web servers

BuildArch:	noarch
License:	Apache 2.0
Group:		Unspecified
Vendor:		perfSONAR Development Team
URL:		http://www.perfsonar.net

Source0:	%{name}-%{version}.tar.gz

Provides:	%{name} = %{version}-%{release}

Requires:	httpd

BuildRequires:	pscheduler-rpm


%description
Front page for perfSONAR nodes with web servers


%define document_root %{_var}/www/html

%prep
%setup -q


%build
make \
     DESTDIR=$RPM_BUILD_ROOT/%{document_root} \
     install


%clean
make clean


%files
%defattr(-,root,root)
%{document_root}/*
