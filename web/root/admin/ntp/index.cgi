#!/usr/bin/perl -w

use strict;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Ajax;
use CGI::Session;
use Template;
use Data::Dumper;
use Config::General;
use Log::Log4perl qw(get_logger :easy :levels);
use Net::IP;
use Params::Validate;
use Storable qw(store retrieve freeze thaw dclone);

use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../../../../lib";

use perfSONAR_PS::NPToolkit::Config::NTP;
use perfSONAR_PS::Utils::NTP qw( ping );
use perfSONAR_PS::Utils::DNS qw( reverse_dns resolve_address );
use perfSONAR_PS::Web::Sidebar qw(set_sidebar_vars);
use perfSONAR_PS::HostInfo::Base;

use Data::Validate::IP qw(is_ipv4);
use Net::IP;

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

$conf{sessions_directory} = "/tmp" unless ( $conf{sessions_directory} );
$conf{sessions_directory} = $basedir . "/" . $conf{sessions_directory} unless ( $conf{sessions_directory} =~ /^\// );

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

our $logger = get_logger( "perfSONAR_PS::WebAdmin::NTP" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

$logger->info( "templates dir: $conf{template_directory}" );

my $cgi = CGI->new();
our $session;

if ( $cgi->param( "session_id" ) ) {
    $session = CGI::Session->new( "driver:File;serializer:Storable", $cgi->param( "session_id" ), { Directory => $conf{sessions_directory} } );
}
else {
    $session = CGI::Session->new( "driver:File;serializer:Storable", $cgi, { Directory => $conf{sessions_directory} } );
}

die( "Couldn't instantiate session: " . CGI::Session->errstr() ) unless ( $session );

our ( $ntp_conf, $status_msg, $warning_msg, $error_msg, $failed_connect, $is_modified, $initial_state_time, $ntpinfo );

if ( $session and not $session->is_expired and $session->param( "ntp_conf" ) ) {
    $logger->debug( "Restoring ntp conf object" );
    $ntp_conf = perfSONAR_PS::NPToolkit::Config::NTP->new( { saved_state => $session->param( "ntp_conf" ) } );
    $failed_connect = thaw( $session->param("failed_connect") );
    $is_modified   = $session->param( "is_modified" );
    $initial_state_time = $session->param( "initial_state_time" );
    unless ($failed_connect) {
    	$failed_connect = {};
    }
}
else {
    $logger->debug( "Reverting ntp conf object" );
    reset_state();
    save_state();
}

if ($ntp_conf->last_modified() > $initial_state_time) {
	reset_state();
	save_state();
	$status_msg = "The on-disk configuration has changed. Any changes you made have been lost.";

	my $html = display_body();

	print "Content-Type: text/html\n\n";
	print $html;
	exit 0;
}

$ntpinfo = perfSONAR_PS::HostInfo::NTP->new();
$warning_msg = "NTP is not syncronized" unless $ntpinfo->is_synced();

my $ajax = CGI::Ajax->new(
    'save_config'  => \&save_config,
    'reset_config' => \&reset_config,

    'add_server'         => \&add_server,
    'delete_server'      => \&delete_server,
    'toggle_server'      => \&toggle_server,
    'select_closest'     => \&select_closest,
    'download_ntp_conf'  => \&generate_ntp_conf,
);

my ( $header, $footer );
my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

#$tt->process( "header.tmpl", \%vars, \$header ) or die $tt->error();
#$tt->process( "footer.tmpl", \%vars, \$footer ) or die $tt->error();

my %vars = ();
$vars{self_url}   = $cgi->self_url();
$vars{session_id} = $session->id();
fill_variables( \%vars );
set_sidebar_vars( { vars => \%vars } );

my $html;

$tt->process( "full_page.tmpl", \%vars, \$html ) or die $tt->error();

print $ajax->build_html( $cgi, $html, { '-Expires' => '1d' } );

sub fill_variables {
    my $vars = shift;

    my @vars_servers = ();

    my $ntp_servers = $ntp_conf->get_servers();
    foreach my $key ( sort { $ntp_servers->{$a}->{description} cmp $ntp_servers->{$b}->{description} } keys %{$ntp_servers} ) {
        my $ntp_server = $ntp_servers->{$key};

        my $display_address = $ntp_server->{address};
        if ( is_ipv4( $display_address ) or &Net::IP::ip_is_ipv6( $display_address ) ) {
            my $new_addr = reverse_dns( $display_address );
	    $display_address = $new_addr if ($new_addr);
        }

        my %server_info = (
            address         => $ntp_server->{address},
            display_address => $display_address,
            description     => $ntp_server->{description},
            selected        => $ntp_server->{selected},
	    failed_connect  => $failed_connect->{$ntp_server->{address}},
        );

        push @vars_servers, \%server_info;
    }

    $vars->{servers}               = \@vars_servers;
    $vars->{enable_select_closest} = 1 if $conf{enable_select_closest};
    $vars->{is_modified}           = $is_modified;
    $vars->{status_message}        = $status_msg;
    $vars->{error_message}         = $error_msg;
    $vars->{warning_message}        = $warning_msg;

    return 0;
}

sub display_body {
    my %vars = ();

    fill_variables( \%vars );

    my $html;

    my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );
    $tt->process( "body.tmpl", \%vars, \$html ) or die $tt->error();

    return $html;
}

sub save_config {
    my ($status, $res) = $ntp_conf->save( { restart_services => 1 } );
    if ($status != 0) {
        $error_msg = "Problem saving configuration: $res";
    } else {
        $status_msg = "Configuration Saved And Services Restarted";
        $is_modified = 0;
	$initial_state_time = $ntp_conf->last_modified();
    }
 
    save_state();

    return display_body();
}

sub reset_config {
    reset_state();
    save_state();
    $status_msg = "Configuration Reset";
    return display_body();
}

sub add_server {
    my ( $address, $description, $selected ) = @_;

    if ( $ntp_conf->lookup_server( { address => $address } ) ) {
    	$error_msg = "Server $address already exists";
        return display_body();
    }

    $ntp_conf->add_server(
        {
            address     => $address,
            description => $description,
            selected    => 1,
        }
    );
    $is_modified = 1;

    save_state();

    $logger->info( "Server $address added" );

    $status_msg = "Server $address added";
    return display_body();
}

sub delete_server {
    my ( $address ) = @_;
    $logger->info( "Deleting Server: $address" );

    $ntp_conf->delete_server( { address => $address } );

    $is_modified = 1;

    save_state();

    $status_msg = "Server $address deleted";
    return display_body();
}

sub toggle_server {
    my ( $address, $value ) = @_;

    $logger->info( "Toggling server $address" );

    return unless ( $ntp_conf->lookup_server( { address => $address } ) );

    if ( $value and $value eq "on" ) {
        $logger->info( "Enabling server $address: '$value'" );
        $ntp_conf->update_server( { address => $address, selected => 1 } );
    }
    else {
        $logger->info( "Disabling server $address: '$value'" );
        $ntp_conf->update_server( { address => $address, selected => 0 } );
    }

    $is_modified = 1;

    save_state();

    return "";
}

sub reset_state {
    $ntp_conf = perfSONAR_PS::NPToolkit::Config::NTP->new();
    my $res = $ntp_conf->init( { ntp_conf => $conf{ntp_conf}, ntp_conf_template => $conf{ntp_conf_template}, known_servers => $conf{known_servers} } );
    if ( $res != 0 ) {
        die( "Couldn't initialize NTP Configuration" );
    }

    $is_modified = 0;
    $initial_state_time = $ntp_conf->last_modified();

    $failed_connect = {};
}

sub save_state {
    my $state = $ntp_conf->save_state();
    $session->param( "ntp_conf", $state );

    $session->param( "initial_state_time", $initial_state_time );
    $session->param("failed_connect", freeze($failed_connect));
    $logger->debug( "Saved State: " . $session->param( "ntp_conf" ) );
}

sub select_closest {
    my ( $count ) = @_;

    my @servers = ();

    my $ntp_servers = $ntp_conf->get_servers();

    foreach my $key ( keys %{$ntp_servers} ) {
        my $ntp_server = $ntp_servers->{$key};

        push @servers, $ntp_server->{address};
    }

    my ( $status, $res1, $res2 ) = find_closest_servers( { servers => \@servers, maximum_number => $count } );
    if ( $status != 0 ) {
        $error_msg = "Error finding closest servers";
        return display_body();
    }

    foreach my $key ( keys %{$ntp_servers} ) {
        my $ntp_server = $ntp_servers->{$key};

        $ntp_conf->update_server( { address => $ntp_server->{address}, selected => 0 } );
    }

    foreach my $address ( @$res1 ) {
        $ntp_conf->update_server( { address => $address->{address}, selected => 1 } );
    }

    my %new_failed_connect = ();
    foreach my $address ( @$res2 ) {
        $new_failed_connect{$address} = 1;
    }
    $failed_connect = \%new_failed_connect;

    $is_modified = 1;

    save_state();

    $status_msg = "Selected Closest";
    return display_body();
}

sub find_closest_servers {
    my $parameters = validate(
        @_,
        {
            servers        => 1,
            maximum_number => 0,
        }
    );

    my @results = ();
    my @failed_results = ();

    foreach my $server ( @{ $parameters->{servers} } ) {
	$logger->debug("Pinging $server");

        my ( $ret, $duration ) = ping({ hostname => $server, timeout => 2 });
        unless ( $ret == 0 ) {
            $logger->debug("Didn't receive response from $server");
	    push @failed_results, $server;
            next;
	}
	$logger->debug("Server $server took $duration seconds");
        push @results, { address => $server, rtt => $duration };
    }

    $logger->debug("Out of find_closest_servers loop");

    @results = sort { $a->{rtt} <=> $b->{rtt} } @results;

    # make sure we only grab the maximum number

    unless ( $parameters->{maximum_number} ) {
        $logger->debug("Returning all results");
        return ( 0, \@results, \@failed_results );
    }
    else {
        $logger->debug("Returning subset of results");

        my @retval = ();

        for ( my $i = 0; $i < $parameters->{maximum_number} and $i < scalar( @results ); $i++ ) {
            push @retval, $results[$i];
        }

        return ( 0, \@retval, \@failed_results );
    }
}

1;
