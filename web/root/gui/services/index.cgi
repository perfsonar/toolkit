#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use Log::Log4perl qw(get_logger :easy :levels);
use Template;
use POSIX;
use Data::Dumper;

use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../../../../lib";

use RPM2;

use perfSONAR_PS::NPToolkit::Config::Version;
use perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;

use perfSONAR_PS::Utils::Host qw( discover_primary_address );
use perfSONAR_PS::Utils::LookupService qw( is_host_registered );

use perfSONAR_PS::NPToolkit::Services::ServicesMap qw(get_service_object);

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

my $external_addresses = discover_primary_address({
                                                    interface => $conf{primary_interface},
                                                    allow_rfc1918 => $conf{allow_internal_addresses},
                                                    disable_ipv4_reverse_lookup => $conf{disable_ipv4_reverse_lookup},
                                                    disable_ipv6_reverse_lookup => $conf{disable_ipv6_reverse_lookup},
                                                 });
my $external_address;
my $external_address_mtu;
my $is_registered = 0;
if ($external_addresses) {
    $external_address = $external_addresses->{primary_address};
    $external_address_mtu = $external_addresses->{primary_iface_mtu};
    $is_registered = is_host_registered($external_address);
}

my $administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new();
$administrative_info_conf->init( { administrative_info_file => $conf{administrative_info_file} } );

my $owamp = get_service_object("owamp");
my $bwctl = get_service_object("bwctl");
my $npad = get_service_object("npad");
my $ndt = get_service_object("ndt");
my $regular_testing = get_service_object("regular_testing");
my $ntp = get_service_object("ntp");

my %services = ();

foreach my $service_name ( "owamp", "bwctl", "npad", "ndt", "regular_testing", "esmond" ) {
    my $service = get_service_object($service_name);

    $logger->debug("Checking ".$service_name);
    my $is_running = $service->check_running();
   
    my @addresses = ();
    if ($service->can("get_addresses")) {
        my $addr_list = $service->get_addresses();
        foreach my $addr (@$addr_list) {
            my $is_url;

            my $uri = URI->new($addr);
            if ($uri->scheme eq "http" or $uri->scheme eq "https") {
                $is_url = 1;
            }

            push @addresses, { value => $addr, is_url => $is_url };

        }
    }

    my $is_running_output = ($is_running)?"yes":"no";
    
    if ($service->disabled) {
        $is_running_output = "disabled" unless ($is_running);
    }
    
    my %service_info = ();
    $service_info{"name"}       = $service_name;
    $service_info{"is_running"} = $is_running_output;
    $service_info{"addresses"}  = \@addresses;
    $service_info{"version"}    = $service->package_version;

    $services{$service_name} = \%service_info;
}

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
$vars{external_address}     = $external_address;
$logger->debug("Grabbing MTU of primary address");
$vars{mtu}     = $external_address_mtu;
$logger->debug("Checking if NTP is synced");
$vars{ntp_sync_status}     = $ntp->is_synced();
$logger->debug("Checking if globally registered");
$vars{global_reg} 		= $is_registered;
set_sidebar_vars( { vars => \%vars } );
$logger->debug("Building index page");

$tt->process( "status.tmpl", \%vars, \$html ) or die $tt->error();

my $cgi = CGI->new();
print $cgi->header;
print $html;

exit 0;
# vim: expandtab shiftwidth=4 tabstop=4

