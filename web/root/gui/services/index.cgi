#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use Log::Log4perl qw(get_logger :easy :levels);
use Template;
use POSIX;
use Data::Dumper;

######################
# Configuration
######################
my $owamp_cfg               = "/etc/owampd/owampd.conf";
my $owamp_pid               = "/var/run/owampd.pid";
my $owamp_pname             = "owampd";
my $bwctl_cfg               = "/etc/bwctld/bwctld.conf";
my $bwctl_pid               = "/var/run/bwctld.pid";
my $bwctl_pname             = "bwctld";
my $npad_cfg                = "/opt/npad/config.xml";
my $npad_pid                = "/var/run/npad.pid";
my $npad_pname              = "DiagServer.py";
my $ndt_pid                 = undef;
my $ndt_pname               = [ "web100srv", "fakewww" ];
my $PingER_cfg              = "/opt/perfsonar_ps/PingER/etc/daemon.conf";
my $PingER_pid              = "/var/run/pinger.pid";
my $PingER_pname            = "daemon.pl";
my $SNMP_MA_cfg             = "/opt/perfsonar_ps/snmp_ma/etc/daemon.conf";
my $SNMP_MA_pid             = "/var/run/snmp_ma.pid";
my $SNMP_MA_pname           = "daemon.pl";
my $pSB_MA_cfg              = "/opt/perfsonar_ps/perfsonarbuoy_ma/etc/daemon.conf";
my $pSB_MA_pid              = "/var/run/perfsonarbuoy_ma.pid";
my $pSB_MA_pname            = "daemon.pl";
my $regular_testing_pid     = "/var/run/regular_testing.pid";
my $regular_testing_pname   = "daemon";
my $traceroute_MA_cfg           = "/opt/perfsonar_ps/traceroute_ma/etc/daemon.conf";
my $traceroute_MA_pid           = "/var/run/traceroute_ma.pid";
my $traceroute_MA_pname         = "daemon.pl";
######################
# End Configuration
######################

use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../../../../lib";

use perfSONAR_PS::HostInfo::Base;

use perfSONAR_PS::Web::Sidebar qw(set_sidebar_vars);

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

$conf{template_directory} = "templates" unless ( $conf{template_directory} );
$conf{template_directory} = $basedir . "/" . $conf{template_directory} unless ( $conf{template_directory} =~ /^\// );

if ( $conf{logger_conf} ) {
    unless ( $conf{logger_conf} =~ /^\// ) {
        $conf{logger_conf} = $basedir . "/etc/" . $conf{logger_conf};
    }

    Log::Log4perl->init( $conf{logger_conf} );
}
else {

    # If they've not specified a logger, send it all to /dev/null
    Log::Log4perl->easy_init( { level => $DEBUG, file => "/dev/null" } );
}

our $logger = get_logger( "perfSONAR_PS::WebGUI::ServiceStatus" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $version_conf = perfSONAR_PS::NPToolkit::Config::Version->new();
$version_conf->init();

my $external_address_conf = perfSONAR_PS::NPToolkit::Config::ExternalAddress->new();
$external_address_conf->init();

my $services_conf = perfSONAR_PS::NPToolkit::Config::Services->new();
$services_conf->init( { enabled_services_file => $conf{enabled_services_file} } );

my $administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new();
$administrative_info_conf->init( { administrative_info_file => $conf{administrative_info_file} } );

my $owamp = perfSONAR_PS::ServiceInfo::OWAMP->new();
$owamp->init( conf_file => $owamp_cfg, pid_files => $owamp_pid, process_names => $owamp_pname );
my $bwctl = perfSONAR_PS::ServiceInfo::BWCTL->new();
$bwctl->init( conf_file => $bwctl_cfg, pid_files => $bwctl_pid, process_names => $bwctl_pname );
my $npad = perfSONAR_PS::ServiceInfo::NPAD->new();
$npad->init( conf_file => $npad_cfg, pid_files => $npad_pid, process_names => $npad_pname );
my $ndt = perfSONAR_PS::ServiceInfo::NDT->new();
$ndt->init( pid_files => $ndt_pid, process_names => $ndt_pname );
my $pinger = perfSONAR_PS::ServiceInfo::PingER->new();
$pinger->init( conf_file => $PingER_cfg, pid_files => $PingER_pid, process_names => $PingER_pname );
my $snmp_ma = perfSONAR_PS::ServiceInfo::SNMP_MA->new();
$snmp_ma->init( conf_file => $SNMP_MA_cfg, pid_files => $SNMP_MA_pid, process_names => $SNMP_MA_pname );
my $psb_ma = perfSONAR_PS::ServiceInfo::pSB_MA->new();
$psb_ma->init( conf_file => $pSB_MA_cfg, pid_files => $pSB_MA_pid, process_names => $pSB_MA_pname );
my $traceroute_ma = perfSONAR_PS::ServiceInfo::Traceroute_MA->new();
$traceroute_ma->init( conf_file => $traceroute_MA_cfg, pid_files => $traceroute_MA_pid, process_names => $traceroute_MA_pname );
my $regular_testing = perfSONAR_PS::ServiceInfo::RegularTesting->new();
$regular_testing->init( pid_files => [ $regular_testing_pid ], process_names => [ $regular_testing_pname ] );

my %services = ();

foreach my $service ( $owamp, $bwctl, $npad, $ndt, $psb_ma, $traceroute_ma, $pinger, $snmp_ma, $regular_testing ) {
    $logger->debug("Checking ".$service->name());
    my $is_running = $service->check_running();
    
    my $addresses  = $service->get_addresses();
    my $name       = $service->name();
    my $enabled_service_info = $services_conf->lookup_service({ name => $name });

    my $is_running_output = ($is_running)?"yes":"no";
    
    if ($enabled_service_info) {
        unless ($enabled_service_info->{enabled}) {
            $is_running_output = "disabled" unless ($is_running);
        }
    }
    
    my %service_info = ();
    $service_info{"name"}       = $name;
    $service_info{"is_running"} = $is_running_output;
    $service_info{"addresses"}  = $addresses if ( $addresses );

    $services{$name} = \%service_info;
}

my $ntpinfo = perfSONAR_PS::HostInfo::NTP->new();

my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

my $html;

my %vars = ();
$vars{site_name}       = $administrative_info_conf->get_organization_name();
$vars{site_location}   = $administrative_info_conf->get_location();
$vars{city}   = $administrative_info_conf->get_city();
$vars{state}   = $administrative_info_conf->get_state();
$vars{country}   = $administrative_info_conf->get_country();
$vars{zipcode}   = $administrative_info_conf->get_zipcode();
$vars{latitude}   = $administrative_info_conf->get_latitude();
$vars{longitude}   = $administrative_info_conf->get_longitude();
$vars{keywords}        = $administrative_info_conf->get_keywords();
$vars{toolkit_version} = $version_conf->get_version();
$vars{services}        = \%services;
$vars{admin_name}      = $administrative_info_conf->get_administrator_name();
$vars{admin_email}     = $administrative_info_conf->get_administrator_email();
$logger->debug("Grabbing primary address");
$vars{external_address}     = $external_address_conf->get_primary_address();
$logger->debug("Grabbing MTU of primary address");
$vars{mtu}     = $external_address_conf->get_primary_iface_mtu();
$logger->debug("Checking if NTP is synced");
$vars{ntp_sync_status}     = $ntpinfo->is_synced();
$logger->debug("Checking if globally registered");
$vars{global_reg} 		= $administrative_info_conf->has_admin_info();
set_sidebar_vars( { vars => \%vars } );
$logger->debug("Building index page");

$tt->process( "status.tmpl", \%vars, \$html ) or die $tt->error();

my $cgi = CGI->new();
print $cgi->header;
print $html;

exit 0;
# vim: expandtab shiftwidth=4 tabstop=4

