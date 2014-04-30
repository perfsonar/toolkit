#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use Log::Log4perl qw(get_logger :easy :levels);
use Template;
use POSIX;

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

use perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;
use perfSONAR_PS::NPToolkit::Config::Services;
use perfSONAR_PS::NPToolkit::Config::Version;
use perfSONAR_PS::NPToolkit::Config::ExternalAddress;

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

$logger->debug("Building index page");

$tt->process( "status.tmpl", \%vars, \$html ) or die $tt->error();

my $cgi = CGI->new();
print $cgi->header;
print $html;

exit 0;

package perfSONAR_PS::HostInfo::Base;

sub new{
	my ( $package ) = @_;

    my $self = fields::new( $package );

    return $self;
}

# TODO: use this for drawing the nav and doing checks on the NTP page
package perfSONAR_PS::HostInfo::NTP;
use Net::NTP;
use base 'perfSONAR_PS::HostInfo::Base';

sub is_synced {
    my %response;
    eval {
        %response = get_ntp_response("localhost");
    };
    return if ($@);

    return ($response{'Reference Clock Identifier'} and $response{'Reference Clock Identifier'} ne "INIT");
}



package perfSONAR_PS::ServiceInfo::Base;

use IO::Interface qw(:flags);
use Log::Log4perl qw(get_logger);
use perfSONAR_PS::Utils::Host qw(get_ips);
use perfSONAR_PS::Utils::DNS  qw(reverse_dns_multi);

use fields 'PID_FILES', 'CONF_FILE', 'LOGGER', 'SERVICE_NAME', 'PROCESS_NAMES';

sub new {
    my ( $package ) = @_;

    my $self = fields::new( $package );

    return $self;
}

sub init {
    my $self   = shift;
    my %params = @_;

    if ( $params{pid_files} and ref( $params{pid_files} ) ne "ARRAY" ) {
        my @tmp = ();
        push @tmp, $params{pid_files};
        $params{pid_files} = \@tmp;
    }
    if ( ref( $params{process_names} ) ne "ARRAY" ) {
        my @tmp = ();
        push @tmp, $params{process_names};
        $params{process_names} = \@tmp;
    }
    $self->{PID_FILES} = $params{pid_files};
    $self->{CONF_FILE} = $params{conf_file};
    $self->{PROCESS_NAMES} = $params{process_names};

    return 0;
}

sub check_running {
    my $self = shift;
    
    $self->{LOGGER}->debug("Checking if running via pid files"); 

    #$i tracks index to associate $self->{PID_FILES}[$i] with $self->{PROCESS_NAMES}[$i]
    unless ($self->{PID_FILES}) {
        foreach my $pname ( @{ $self->{PROCESS_NAMES} } ) {
            my $results = `pgrep -f $pname`;
            chomp($results);
            return 0 unless ($results);
        }
    }
    else {
        my $i = 0;
        foreach my $pid_file ( @{ $self->{PID_FILES} } ) {
            open( PIDFILE, $pid_file ) or return 0;
            my $p_id = <PIDFILE>;
            close( PIDFILE );

            chomp( $p_id ) if ( defined $p_id );
            if ( $p_id ) {
                open( PSVIEW, "ps -p " . $p_id . " | grep " . $self->{PROCESS_NAMES}[$i] . " |" );
                my @output = <PSVIEW>;
                close( PSVIEW );
                if ( $? != 0 ) {
                    return 0;
                }
            }
            else {
                return 0;
            }
            $i++;
        }
    }

    return 1;
}

sub lookup_interfaces {
    my ( $self ) = @_;

    my @ips = get_ips();

    my $resolved_addresses = reverse_dns_multi({ addresses => \@ips, timeout => 2 });

    my %ret_addresses = ();
    foreach my $ip (@ips) {
        if ($resolved_addresses->{$ip} and scalar(@{ $resolved_addresses->{$ip} }) > 0) {
            foreach my $addr (@{ $resolved_addresses->{$ip} }) {
                $ret_addresses{$addr} = 1;
            }
        } else {
            $ret_addresses{$ip} = 1;
        }
    }

    my @ret_addrs = keys %ret_addresses;

    return @ret_addrs;
}

sub __boote_read_app_config {
    my ( $self, $file ) = @_;

    my %conf = ();

    open( FILE, $file ) or return %conf;
    while ( my $line = <FILE> ) {
        $line =~ s/#.*//;     # get rid of any comment on the line
        $line =~ s/^\S+//;    # get rid of any leading whitespace
        $line =~ s/\S+$//;    # get rid of any trailing whitespace

        my ( $key, $value ) = split( /\S+/, $line );
        if ( not $key ) {
            next;
        }

        if ( $value ) {
            $conf{$key} = $value;
        }
        else {
            $conf{$key} = 1;
        }
    }

    return %conf;
}

sub name {
    my $self = shift;

    return $self->{SERVICE_NAME};
}

package perfSONAR_PS::ServiceInfo::RegularTesting;

use base 'perfSONAR_PS::ServiceInfo::Base';
use Log::Log4perl qw(get_logger);

sub init {
    my ( $self, %conf ) = @_;

    $self->{LOGGER}       = get_logger( "perfSONAR_PS::Agent::LS::Registration::RegularTesting" );
    $self->{SERVICE_NAME} = "regular_testing";
    $self->SUPER::init( %conf );
    return 0;
}

sub get_addresses {
    return undef;
}

package perfSONAR_PS::ServiceInfo::BWCTL;

use base 'perfSONAR_PS::ServiceInfo::Base';
use Log::Log4perl qw(get_logger);

sub get_addresses {
    my ( $self ) = @_;

    my %res = $self->read_app_config( $self->{CONF_FILE} );

    my $port = 4823;
    if ( $res{port} ) {
        $port = $res{port};
    }

    my @addresses;
    if ( not $res{addr} ) {

        # Grab the list of address from the server
        @addresses = $self->lookup_interfaces();
    }
    else {
        @addresses = ();
        push @addresses, $res{addr};
    }

    my @serv_addrs = ();

    foreach my $address ( @addresses ) {
        my %addr = ();
        $addr{"is_url"} = 0;
        if ( $address =~ /:/ ) {
            $addr{"value"} = "tcp://[$address]:$port";
        }
        else {
            $addr{"value"} = "tcp://$address:$port";
        }
        push @serv_addrs, \%addr;
    }

    return \@serv_addrs;
}

sub read_app_config {
    my ( $self, $file ) = @_;

    my %conf = $self->__boote_read_app_config( $file );
    my $addr_to_parse;

    if ( $conf{"srcnode"} ) {
        $addr_to_parse = $conf{"srcnode"};
    }
    elsif ( $conf{"src_node"} ) {
        $addr_to_parse = $conf{"src_node"};
    }

    my ( $addr, $port );

    if ( $addr_to_parse and $addr_to_parse =~ /(.*):(.*)/ ) {
        $addr = $1;
        $port = $2;
    }

    return ( addr => $addr, port => $port );
}

sub init {
    my ( $self, %conf ) = @_;

    $self->{LOGGER}       = get_logger( "perfSONAR_PS::Agent::LS::Registration::BWCTL" );
    $self->{SERVICE_NAME} = "bwctl";

    $self->SUPER::init( %conf );

    return 0;
}

package perfSONAR_PS::ServiceInfo::OWAMP;

use base 'perfSONAR_PS::ServiceInfo::Base';
use Log::Log4perl qw(get_logger);

sub get_addresses {
    my ( $self ) = @_;

    my %res = $self->read_app_config( $self->{CONF_FILE} );

    my $port = 861;
    if ( $res{port} ) {
        $port = $res{port};
    }

    my @addresses;
    if ( not $res{addr} ) {

        # Grab the list of address from the server
        @addresses = $self->lookup_interfaces();
    }
    else {
        @addresses = ();
        push @addresses, $res{addr};
    }

    my @serv_addrs = ();

    foreach my $address ( @addresses ) {
        my %addr = ();
        $addr{"is_url"} = 0;
        if ( $address =~ /:/ ) {
            $addr{"value"} = "tcp://[$address]:$port";
        }
        else {
            $addr{"value"} = "tcp://$address:$port";
        }
        push @serv_addrs, \%addr;
    }

    return \@serv_addrs;
}

sub read_app_config {
    my ( $self, $file ) = @_;

    my %conf = $self->__boote_read_app_config( $file );
    my $addr_to_parse;

    if ( $conf{"srcnode"} ) {
        $addr_to_parse = $conf{"srcnode"};
    }
    elsif ( $conf{"src_node"} ) {
        $addr_to_parse = $conf{"src_node"};
    }

    my ( $addr, $port );

    if ( $addr_to_parse and $addr_to_parse =~ /(.*):(.*)/ ) {
        $addr = $1;
        $port = $2;
    }

    return ( addr => $addr, port => $port );
}

sub init {
    my ( $self, %conf ) = @_;

    $self->{LOGGER}       = get_logger( "perfSONAR_PS::Agent::LS::Registration::OWAMP" );
    $self->{SERVICE_NAME} = "owamp";

    $self->SUPER::init( %conf );

    return 0;
}

package perfSONAR_PS::ServiceInfo::NDT;

use base 'perfSONAR_PS::ServiceInfo::Base';
use Log::Log4perl qw(get_logger);

sub get_addresses {
    my ( $self ) = @_;

    my @addresses = $self->lookup_interfaces();
    my $web_port  = 7123;
    my $ctrl_port = 3001;

    my @serv_addrs = ();

    foreach my $address ( @addresses ) {
        my %ctrl_addr = ();
        $ctrl_addr{"is_url"} = 0;
        if ( $address =~ /:/ ) {
            $ctrl_addr{"value"} = "tcp://[$address]:$ctrl_port";
        }
        else {
            $ctrl_addr{"value"} = "tcp://$address:$ctrl_port";
        }

        push @serv_addrs, \%ctrl_addr;

        my %web_addr = ();
        $web_addr{"is_url"} = 1;
        if ( $address =~ /:/ ) {
            $web_addr{"value"} = "http://[$address]:$web_port";
        }
        else {
            $web_addr{"value"} = "http://$address:$web_port";
        }

        push @serv_addrs, \%web_addr;
    }

    return \@serv_addrs;
}

sub read_app_config {
    my ( $self, $file ) = @_;

    my %conf = $self->__boote_read_app_config( $file );
    my $addr_to_parse;

    if ( $conf{"srcnode"} ) {
        $addr_to_parse = $conf{"srcnode"};
    }
    elsif ( $conf{"src_node"} ) {
        $addr_to_parse = $conf{"src_node"};
    }

    my ( $addr, $port );

    if ( $addr_to_parse and $addr_to_parse =~ /(.*):(.*)/ ) {
        $addr = $1;
        $port = $2;
    }

    return ( addr => $addr, port => $port );
}

sub init {
    my ( $self, %conf ) = @_;

    $self->{LOGGER}       = get_logger( "perfSONAR_PS::Agent::LS::Registration::NDT" );
    $self->{SERVICE_NAME} = "ndt";

    $self->SUPER::init( %conf );

    return 0;
}

package perfSONAR_PS::ServiceInfo::NPAD;

use base 'perfSONAR_PS::ServiceInfo::Base';
use Log::Log4perl qw(get_logger);

sub get_addresses {
    my ( $self ) = @_;

    my %res = $self->read_app_config( $self->{CONF_FILE} );

    my $ctrl_port = 8001;
    my $web_port  = 8000;

    if ( $res{port} ) {
        $ctrl_port = $res{port};
    }

    my @addresses;
    if ( not $res{addr} ) {

        # Grab the list of address from the server
        @addresses = $self->lookup_interfaces();
    }
    else {
        @addresses = ();
        push @addresses, $res{addr};
    }

    my @serv_addrs = ();

    foreach my $address ( @addresses ) {
        my %ctrl_addr = ();
        $ctrl_addr{"is_url"} = 0;
        if ( $address =~ /:/ ) {
            $ctrl_addr{"value"} = "tcp://[$address]:$ctrl_port";
        }
        else {
            $ctrl_addr{"value"} = "tcp://$address:$ctrl_port";
        }

        push @serv_addrs, \%ctrl_addr;

        my %web_addr = ();
        $web_addr{"is_url"} = 1;
        if ( $address =~ /:/ ) {
            $web_addr{"value"} = "http://[$address]:$web_port";
        }
        else {
            $web_addr{"value"} = "http://$address:$web_port";
        }

        push @serv_addrs, \%web_addr;
    }

    return \@serv_addrs;
}

sub read_app_config {
    my ( $self, $file ) = @_;

    my ( $control_addr, $control_port );

    open( NPAD_CONFIG, $file ) or return ();
    while ( <NPAD_CONFIG> ) {
        if ( /CONTROL_ADDR = (.*)/ ) {
            $control_addr = $1;
        }
        elsif ( /CONTROL_PORT = (.*)/ ) {
            $control_port = $1;
        }
    }

    return ( addr => $control_addr, port => $control_port );
}

sub init {
    my ( $self, %conf ) = @_;

    $self->{LOGGER}       = get_logger( "perfSONAR_PS::Agent::LS::Registration::NPAD" );
    $self->{SERVICE_NAME} = "npad";

    $self->SUPER::init( %conf );

    return 0;
}

package perfSONAR_PS::ServiceInfo::perfSONAR_PS;

use base 'perfSONAR_PS::ServiceInfo::Base';
use fields 'VALID_MODULE';

use Log::Log4perl qw(get_logger);
use Config::General;
use IO::Socket;

sub get_addresses {
    my ( $self ) = @_;

    my @serv_addrs = ();

    my %res = $self->read_app_config( $self->{CONF_FILE} );

    my $actual_endpoint;
    foreach my $endpoint ( keys %{ $res{endpoints} } ) {
        if ( $res{endpoints}->{$endpoint} eq $self->{VALID_MODULE} ) {
            $actual_endpoint = $endpoint;
            last;
        }
    }

    if ( not $actual_endpoint ) {
        return \@serv_addrs;
    }

    my @addresses;
#    if ( $res{address} ) {
#        @addresses = ();
#        push @addresses, $res{address};
#    }
#    else {

        # Grab the list of address from the server
        @addresses = $self->lookup_interfaces();
#    }

    foreach my $address ( @addresses ) {
        my %ctrl_addr = ();
        $ctrl_addr{"is_url"} = 0;
        if ( $address =~ /:/ ) {
            $ctrl_addr{"value"} = "http://[$address]:$actual_endpoint";
        }
        else {
            $ctrl_addr{"value"} = "http://$address:$actual_endpoint";
        }

        push @serv_addrs, \%ctrl_addr;
    }

    return \@serv_addrs;
}

sub read_app_config {
    my ( $self, $file ) = @_;

    my $config = new Config::General( $file );
    my %conf   = $config->getall;

    my %endpoints = ();
    my @ports = ();
    
    my $external_address = $conf{"external_address"};

    if ( $conf{"port"} ) {
        foreach my $port ( keys %{ $conf{"port"} } ) {
            push @ports, $port;
            if ( not defined $conf{"port"}->{$port}->{"endpoint"} ) {
                next;
            }
            if ( $conf{"port"}->{$port}->{"endpoint"} ) {
                foreach my $endpoint ( keys %{ $conf{"port"}->{$port}->{"endpoint"} } ) {
                    $endpoints{ $port . $endpoint } = $conf{"port"}->{$port}->{"endpoint"}->{$endpoint}->{"module"};
                }
            }
        }
    }

    my %res = ();
    $res{endpoints} = \%endpoints;
    $res{address}   = $external_address;
    $res{ports}     = \@ports;
    
    return %res;
}

sub check_running(){
    my $self = shift;
     
    my %res = $self->read_app_config( $self->{CONF_FILE} );
   
    #check process is running
    if(!$self->SUPER::check_running()){
        return 0;
    }
    
    #check that can connect to service port
    my @ports = ();
    if ( $res{ports} ) {
        @ports = @{$res{ports}};
    }

    unless (scalar(@ports) > 0) {
        # don't know where to check, assume it's good.
        return 1;
    }

    my @addresses = $self->lookup_interfaces();
    foreach my $address ( @addresses ){
        foreach my $port ( @ports ){
            $self->{LOGGER}->debug("Connecting to $address:$port"); 
            my $sock = new IO::Socket::INET (
                       PeerAddr => $address,
                       PeerPort => $port,
                       Proto => 'tcp'
                   );
            if($sock){
                $self->{LOGGER}->debug("Connected to $address:$port"); 
                return 1;
            }
            $self->{LOGGER}->debug("Couldn't connect to $address:$port"); 
        }
    }
    
    return 0; 
}

sub init {
    my ( $self, %conf ) = @_;

    $self->SUPER::init( %conf );

    return 0;
}

package perfSONAR_PS::ServiceInfo::PingER;

use base 'perfSONAR_PS::ServiceInfo::perfSONAR_PS';
use Log::Log4perl qw(get_logger);

sub init {
    my ( $self, %conf ) = @_;

    $self->{LOGGER}       = get_logger( "perfSONAR_PS::Agent::LS::Registration::PingER" );
    $self->{SERVICE_NAME} = "pinger";
    $self->{VALID_MODULE} = "perfSONAR_PS::Services::MA::PingER";

    $self->SUPER::init( %conf );

    return 0;
}

package perfSONAR_PS::ServiceInfo::pSB_MA;

use base 'perfSONAR_PS::ServiceInfo::perfSONAR_PS';
use Log::Log4perl qw(get_logger);

sub init {
    my ( $self, %conf ) = @_;

    $self->{LOGGER}       = get_logger( "perfSONAR_PS::Agent::LS::Registration::pSB_MA" );
    $self->{SERVICE_NAME} = "perfsonarbuoy_ma";
    $self->{VALID_MODULE} = "perfSONAR_PS::Services::MA::perfSONARBUOY";

    $self->SUPER::init( %conf );

    return 0;
}

package perfSONAR_PS::ServiceInfo::Traceroute_MA;

use base 'perfSONAR_PS::ServiceInfo::perfSONAR_PS';
use Log::Log4perl qw(get_logger);

sub init {
    my ( $self, %conf ) = @_;

    $self->{LOGGER}       = get_logger( "perfSONAR_PS::Agent::LS::Registration::Traceroute_MA" );
    $self->{SERVICE_NAME} = "traceroute_ma";
    $self->{VALID_MODULE} = "perfSONAR_PS::Services::MA::Traceroute";

    $self->SUPER::init( %conf );

    return 0;
}

package perfSONAR_PS::ServiceInfo::SNMP_MA;

use base 'perfSONAR_PS::ServiceInfo::perfSONAR_PS';
use Log::Log4perl qw(get_logger);

sub init {
    my ( $self, %conf ) = @_;

    $self->{LOGGER}       = get_logger( "perfSONAR_PS::Agent::LS::Registration::pSB_MA" );
    $self->{SERVICE_NAME} = "snmp_ma";
    $self->{VALID_MODULE} = "perfSONAR_PS::Services::MA::SNMP";
    $self->SUPER::init( %conf );
    return 0;
}

# vim: expandtab shiftwidth=4 tabstop=4

