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
use lib "/usr/local/perfSONAR-PS/perfSONAR_PS-PingER/lib";

use perfSONAR_PS::Utils::DNS qw( reverse_dns resolve_address reverse_dns_multi resolve_address_multi );
use perfSONAR_PS::Client::gLS::Keywords;
use perfSONAR_PS::Client::Parallel::gLS;
use perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;
use perfSONAR_PS::NPToolkit::Config::BWCTL;
use perfSONAR_PS::NPToolkit::Config::RegularTesting;
use perfSONAR_PS::NPToolkit::Config::Services;
use perfSONAR_PS::NPToolkit::Config::ExternalAddress;
use perfSONAR_PS::NPToolkit::Config::HostsFile;
use perfSONAR_PS::Common qw(find findvalue extract genuid);

use Data::Validate::IP qw(is_ipv4);
use Data::Validate::Domain qw(is_hostname);
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

our $logger = get_logger( "perfSONAR_PS::WebAdmin::RegularTesting" );
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

our ( $testing_conf, $bwctl_conf, $lookup_info, $status_msg, $error_msg, $current_test, $dns_cache, $is_modified, $initial_state_time );
if ( $session and not $session->is_expired and $session->param( "testing_conf" ) ) {
    $testing_conf = perfSONAR_PS::NPToolkit::Config::RegularTesting->new( { saved_state => $session->param( "testing_conf" ) } );
    $bwctl_conf   = perfSONAR_PS::NPToolkit::Config::BWCTL->new( { saved_state => $session->param( "bwctl_conf" ) } );
    $lookup_info  = thaw( $session->param( "lookup_info" ) );
    $dns_cache    = thaw( $session->param( "dns_cache" ) );
    $current_test = $session->param( "current_test" );
    $is_modified  = $session->param( "is_modified" );
    $initial_state_time = $session->param( "initial_state_time" );
}
else {
    my ($status, $res) = reset_state();
    if ($status != 0) {
        $error_msg = $res;
    }

    save_state();
}

my $external_address;
my $external_address_config = perfSONAR_PS::NPToolkit::Config::ExternalAddress->new();
if ( $external_address_config->init() == 0 ) {
    $external_address = $external_address_config->get_primary_address({});
}

unless ($external_address) {
	reset_state();
	save_state();
	$error_msg = "There is no external address configured. No changes can be made until one is.";

        my $html;
        if ( $cgi->param( "session_id" ) ) {
	    $html = display_body();
        }
        else {
            my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

            my %full_page_vars = ();

            fill_variables( \%full_page_vars );

            $tt->process( "full_page.tmpl", \%full_page_vars, \$html ) or die $tt->error();
        }

	print "Content-Type: text/html\n\n";
	print $html;
	exit 0;
}

if ($testing_conf->last_modified() > $initial_state_time) {
	reset_state();
	save_state();
	$status_msg = "The on-disk configuration has changed. Any changes you made have been lost.";

	my $html = display_body();

	print "Content-Type: text/html\n\n";
	print $html;
	exit 0;
}

my $ajax = CGI::Ajax->new(
    'save_config'  => \&save_config,
    'reset_config' => \&reset_config,

    'show_test' => \&show_test,
    'update_owamp_test_port_range' => \&update_owamp_test_port_range,
    'update_bwctl_test_port_range' => \&update_bwctl_test_port_range,

    'add_pinger_test'    => \&add_pinger_test,
    'update_pinger_test' => \&update_pinger_test,

    'add_owamp_test'    => \&add_owamp_test,
    'update_owamp_test' => \&update_owamp_test,

    'add_traceroute_test'    => \&add_traceroute_test,
    'update_traceroute_test' => \&update_traceroute_test,
    
    'add_bwctl_throughput_test'    => \&add_bwctl_throughput_test,
    'update_bwctl_throughput_test' => \&update_bwctl_throughput_test,

    'add_member_to_test'      => \&add_member_to_test,
    'remove_member_from_test' => \&remove_member_from_test,

    'delete_test' => \&delete_test,

    'lookup_servers' => \&lookup_servers,
    'repair_hosts_file' => \&repair_hosts_file,
);

my ( $header, $footer );
my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

my %full_page_vars = ();

fill_variables( \%full_page_vars );

$logger->debug( "Using variables: " . Dumper( \%full_page_vars ) );

my $html;

$tt->process( "full_page.tmpl", \%full_page_vars, \$html ) or die $tt->error();

print $ajax->build_html( $cgi, $html, { '-Expires' => '1d' } );

exit 0;

sub save_config {
    my ( $status, $res ) = $testing_conf->save( { restart_services => 1 } );
    if ($status != 0) {
        $error_msg = "Problem saving configuration: $res";
    } else {
        ( $status, $res ) = $bwctl_conf->save( { restart_services => 1 } );
        if ($status != 0) {
            $error_msg = "Problem saving configuration: $res";
        } else {
            $status_msg = "Configuration Saved And Services Restarted";
            $is_modified = 0;
            $initial_state_time = $testing_conf->last_modified();
        }
    }

    save_state();

    return display_body();
}

sub reset_config {
    my ( $status, $res );

    ( $status, $res ) = reset_state();
    if ( $status != 0 ) {
        $error_msg = $res;
        return display_body();
    }

    save_state();

    $status_msg = "Configuration Reset";
    return display_body();
}

sub reset_state {
    my ( $status, $res );

    $lookup_info = undef;
    $dns_cache   = {};

    $bwctl_conf = perfSONAR_PS::NPToolkit::Config::BWCTL->new();
    ( $status, $res ) = $bwctl_conf->init( { bwctld_limits => $conf{bwctld_limits}, bwctld_conf => $conf{bwctld_conf}, bwctld_keys => $conf{bwctld_keys} } );
    if ( $status != 0 ) {
        return ( $status, "Problem reading testing configuration: $res" );
    }

    $testing_conf = perfSONAR_PS::NPToolkit::Config::RegularTesting->new();
    ( $status, $res ) = $testing_conf->init( { perfsonarbuoy_conf_template => $conf{perfsonarbuoy_conf_template}, perfsonarbuoy_conf_file => $conf{perfsonarbuoy_conf_file}, pinger_landmarks_file => $conf{pinger_landmarks_file} } );
    if ( $status != 0 ) {
        return ( $status, "Problem reading testing configuration: $res" );
    }

    $is_modified = 0;
    $initial_state_time = $testing_conf->last_modified();
}

sub save_state {
    $session->param( "testing_conf", $testing_conf->save_state() );
    $session->param( "bwctl_conf", $bwctl_conf->save_state() );
    $session->param( "lookup_info",  freeze( $lookup_info ) ) if ( $lookup_info );
    $session->param( "dns_cache",    freeze( $dns_cache ) );
    $session->param( "current_test", $current_test );
    $session->param( "is_modified",   $is_modified );
    $session->param( "initial_state_time", $initial_state_time );
}

sub fill_variables {
    my ( $vars ) = @_;

    fill_variables_tests( $vars );
    fill_variables_keywords( $vars );
    fill_variables_hosts( $vars );
    fill_variables_status( $vars );

    $vars->{is_modified}    = $is_modified;
    $vars->{error_message}  = $error_msg;
    $vars->{status_message} = $status_msg;
    $vars->{self_url}       = $cgi->self_url();
    $vars->{session_id}     = $session->id();

    return 0;
}

sub fill_variables_tests {
    my ( $vars ) = @_;

    my ( $status, $res ) = $testing_conf->get_tests();

    my $tests;
    if ( $status == 0 ) {
        $tests = $res;
    }
    else {
        my @tests = ();
        $tests = \@tests;
    }

    my @sorted_tests = sort { $a->{id} cmp $b->{id} } @$tests;
    $tests = \@sorted_tests;

    $vars->{tests} = $tests;

    if ( $current_test ) {
        my ( $status, $res ) = $testing_conf->lookup_test( { test_id => $current_test } );

        unless ( $status == 0 ) {
            $logger->info( "Failed to lookup test " . $current_test ) unless ( $status == 0 );
        }
        else {
            $vars->{current_test} = $res;
        }
    }

    return 0;
}

sub fill_variables_status {
    my ( $vars ) = @_;

    my ($status, $res);

    my ( $psb_owamp_enabled, $psb_bwctl_enabled, $psb_ma_enabled, $pinger_enabled, $hosts_file_matches_dns );

    my $services_conf = perfSONAR_PS::NPToolkit::Config::Services->new();
    $res = $services_conf->init( { enabled_services_file => $conf{enabled_services_file} } );
    if ( $res == 0 ) {
        my $service_info;

        $service_info = $services_conf->lookup_service( { name => "pinger" } );
        if ( $service_info and $service_info->{enabled} ) {
            $pinger_enabled = 1;
        }

        $service_info = $services_conf->lookup_service( { name => "perfsonarbuoy_bwctl" } );
        if ( $service_info and $service_info->{enabled} ) {
            $psb_bwctl_enabled = 1;
        }

        $service_info = $services_conf->lookup_service( { name => "perfsonarbuoy_owamp" } );
        if ( $service_info and $service_info->{enabled} ) {
            $psb_owamp_enabled = 1;
        }

        $service_info = $services_conf->lookup_service( { name => "perfsonarbuoy_ma" } );
        if ( $service_info and $service_info->{enabled} ) {
            $psb_ma_enabled = 1;
        }
    }
    
    #make sure /etc/hosts matches DNS
    my $hosts_file_config = perfSONAR_PS::NPToolkit::Config::HostsFile->new();
    if($hosts_file_config->init() == 0){
        $hosts_file_matches_dns = $hosts_file_config->compare_to_dns();
    }

    # Calculate whether or not they have a "good" configuration
    ( $status, $res ) = $testing_conf->get_tests();

    my $psb_throughput_tests = 0;
    my $pinger_tests         = 0;
    my $psb_owamp_tests      = 0;
    my $network_usage        = 0;
    my $owamp_port_usage     = 0;
    my $bwctl_port_usage     = 0;
    my $traceroute_tests     = 0;
    
    if ( $status == 0 ) {
        my $tests = $res;
        foreach my $test ( @{$tests} ) {
            if ( $test->{type} eq "bwctl/throughput" ) {
                $psb_throughput_tests++;
            }
            elsif ( $test->{type} eq "pinger" ) {
                $pinger_tests++;
            }
            elsif ( $test->{type} eq "owamp" ) {
                $psb_owamp_tests++;
            }
            elsif ( $test->{type} eq "traceroute" ) {
                $traceroute_tests++;
            }
            
            if ( $test->{type} eq "owamp" ) {
                foreach my $member ( @{ $test->{members} } ) {
                    if ( $member->{sender} ) {
                        $owamp_port_usage += 2;
                    }
                    if ( $member->{receiver} ) {
                        $owamp_port_usage += 2;
                    }
                }
            }

            if ( $test->{type} eq "bwctl/throughput" ) {
                my $test_duration = $test->{parameters}->{duration};
                my $test_interval = $test->{parameters}->{test_interval};

                my $num_tests = 0;
                foreach my $member ( @{ $test->{members} } ) {
                    if ( $member->{sender} ) {
                        $bwctl_port_usage += 2;
                        $num_tests++;
                    }
                    if ( $member->{receiver} ) {
                        $bwctl_port_usage += 2;
                        $num_tests++;
                    }
                }

                # Add 15 seconds onto the duration to account for synchronization issues
                $test_duration += 15;

                $network_usage += ( $num_tests * $test_duration ) / $test_interval if ($test_interval > 0);
            }
        }
    }

    # "merge" the two bwctl port ranges
    my %bwctl_ports = ();
    my $bwctl_port_range;

    ($status, $res) = $bwctl_conf->get_port_range({ port_type => "peer" });
    if ($status == 0) {
        if ($res->{min_port} and $res->{max_port}) {
            $bwctl_ports{min_port} = $res->{min_port};
            $bwctl_ports{max_port} = $res->{max_port};
        }
    }

    ($status, $res) = $bwctl_conf->get_port_range({ port_type => "iperf" });
    if ($status == 0) {
        if ($res->{min_port} and $res->{max_port}) {
            $bwctl_ports{min_port} = ($bwctl_ports{min_port} and $bwctl_ports{min_port} < $res->{min_port})?$bwctl_ports{min_port}:$res->{min_port};
            $bwctl_ports{max_port} = ($bwctl_ports{max_port} and $bwctl_ports{max_port} > $res->{max_port})?$bwctl_ports{max_port}:$res->{max_port};
        }
    }

    if (defined $bwctl_ports{min_port} and defined $bwctl_ports{max_port}) {
        $bwctl_port_range = $bwctl_ports{max_port} - $bwctl_ports{min_port} + 1;
    }

    my %owamp_ports = ();
    my $owamp_port_range;

    ($status, $res) = $testing_conf->get_local_port_range({ test_type => "owamp" });
    if ($status == 0) {
        if ($res) {
            $owamp_ports{min_port} = $res->{min_port};
            $owamp_ports{max_port} = $res->{max_port};
        }
    }

    if (defined $owamp_ports{min_port} and defined $owamp_ports{max_port}) {
        $owamp_port_range = $owamp_ports{max_port} - $owamp_ports{min_port} + 1;
    }

    $vars->{network_percent_used} = sprintf "%.1d", $network_usage * 100;
    $vars->{bwctl_ports}          = \%bwctl_ports;
    $vars->{bwctl_port_range}     = $bwctl_port_range;
    $vars->{bwctl_port_usage}     = $bwctl_port_usage;
    $vars->{hosts_file_matches_dns} = $hosts_file_matches_dns;
    $vars->{owamp_ports}          = \%owamp_ports;
    $vars->{owamp_port_range}     = $owamp_port_range;
    $vars->{owamp_port_usage}     = $owamp_port_usage;
    $vars->{owamp_tests}          = $psb_owamp_tests;
    $vars->{pinger_tests}         = $pinger_tests;
    $vars->{throughput_tests}     = $psb_throughput_tests;
    $vars->{psb_bwctl_enabled}    = $psb_bwctl_enabled;
    $vars->{psb_ma_enabled}       = $psb_ma_enabled;
    $vars->{psb_owamp_enabled}    = $psb_owamp_enabled;
    $vars->{pinger_enabled}       = $pinger_enabled;
    $vars->{traceroute_tests}     = $traceroute_tests;
    $vars->{external_address}     = $external_address ? $external_address : '';
    
    return 0;
}

sub fill_variables_hosts {
    my ( $vars ) = @_;

    my @display_hosts = ();

    my %used_addresses = ();

    $logger->info( "display_found_hosts()" );

    return 0 unless ( $current_test and $lookup_info->{$current_test} );

    my ( $status, $res ) = $testing_conf->lookup_test( { test_id => $current_test } );
    if ( $status == 0 ) {
        my @addresses = ();

        foreach my $member ( @{ $res->{members} } ) {
            push @addresses, $member->{address};
        }

        lookup_addresses(\@addresses, $dns_cache);

        $logger->debug("DNS cache: ".Dumper($dns_cache));

        foreach my $member ( @{ $res->{members} } ) {
            $logger->debug( "Used Address: " . $member->{address} );
            $used_addresses{ $member->{address} } = 1;
            if ($dns_cache->{$member->{address}}) {
                foreach my $addr (@{ $dns_cache->{$member->{address}} }) {
                    $used_addresses{ $addr } = 1;
                    $logger->debug( "Used Address: " . $addr );
                }
            }
        }
    }

    foreach my $host ( @{ $lookup_info->{$current_test}->{hosts} } ) {
        my $exists;

        foreach my $addr ( @{ $host->{"addresses"} } ) {
            $logger->info( "Checking Address: " . $addr->{address} );
            if ( $used_addresses{ $addr->{address} } ) {
                $exists = 1;
                last;
            }
        }

        next if ( $exists );

        my %service_info = ();
        $service_info{"description"} = $host->{description};
        $service_info{"addresses"}   = $host->{addresses};

        push @display_hosts, \%service_info;
    }

    $vars->{hosts}   = \@display_hosts;
    $vars->{keyword} = $lookup_info->{$current_test}->{keyword};
    $vars->{check_time} = $lookup_info->{$current_test}->{check_time};

    return 0;
}

sub fill_variables_keywords {
    my ( $vars ) = @_;

    my $keyword_client = perfSONAR_PS::Client::gLS::Keywords->new( { cache_directory => $conf{cache_directory} } );

    my ($status, $res);

    my @member_keywords          = ();
    my $administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new();
    $res                      = $administrative_info_conf->init( {} );
    if ( $res == 0 ) {
        my $keywords = $administrative_info_conf->get_keywords();
        $logger->info( Dumper( $keywords ) );
        foreach my $keyword ( sort @$keywords ) {
            push @member_keywords, $keyword;
        }
    }

    my @other_keywords = ();
    my $other_keywords_age;

    ($status, $res) = $keyword_client->get_keywords();
    if ( $status == 0) {
        $other_keywords_age = $res->{time};

        my $popular_keywords = $res->{keywords};

        my $keywords = $administrative_info_conf->get_keywords();

        foreach my $keyword ( @$keywords ) {
            # Get rid of any used keywords
            $keyword = "project:" . $keyword unless ( $keyword =~ /^project:/ );

            delete( $popular_keywords->{$keyword} ) if ( $popular_keywords->{$keyword} );
        }

        my @frequencies = sort { $popular_keywords->{$b} <=> $popular_keywords->{$a} } keys %$popular_keywords;

        my $max = $popular_keywords->{ $frequencies[0] };
        my $min = $popular_keywords->{ $frequencies[$#frequencies] };

        foreach my $keyword ( sort { lc($a) cmp lc($b) } keys %$popular_keywords ) {
            next unless ( $keyword =~ /^project:/ );

            my $class;

            if ( $max == $min ) {
                $class = 1;
            }
            else {

                # 10 steps maximum
                $class = 1 + int( 9 * ( $popular_keywords->{$keyword} - $min ) / ( $max - $min ) );
            }

            my $display_keyword = $keyword;
            $display_keyword =~ s/^project://g;

            my %keyword_info = ();
            $keyword_info{keyword} = $display_keyword;
            $keyword_info{class}   = $class;
            push @other_keywords, \%keyword_info;
        }
    }

    $vars->{member_keywords} = \@member_keywords;
    $vars->{known_keywords}  = \@other_keywords;
    $vars->{known_keywords_check_time}  = $other_keywords_age;

    return 0;
}

sub display_body {

    my %vars = ();

    fill_variables( \%vars );

    my $html;

    $logger->info( "Using variables: " . Dumper( \%vars ) );

    my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or return ( "Couldn't initialize template toolkit" );
    $tt->process( "body.tmpl", \%vars, \$html ) or return $tt->error();

    save_state();

    $logger->debug( "Returning: " . $html );

    return $html;
}

sub show_test {
    my ( $test_id ) = @_;

    my ( $status, $res ) = $testing_conf->lookup_test( { test_id => $test_id } );
    if ( $status != 0 ) {
        $error_msg = "Error looking up test: $res";
        return display_body();
    }

    $current_test = $test_id;

    save_state();

    return display_body();
}

sub add_bwctl_throughput_test {
    my ($description, $duration, $test_interval, $tool, $protocol, $window_size, $udp_bandwidth) = @_;

    # Add the new group
    my ( $status, $res ) = $testing_conf->add_test_bwctl_throughput(
        {
            mesh_type     => "star",
            description   => $description,
            tool          => $tool,
            protocol      => $protocol,
            test_interval => $test_interval,
            duration      => $duration,
            window_size   => $window_size,
            udp_bandwidth => $udp_bandwidth,
        }
    );

    if ( $status != 0 ) {
        $error_msg = "Failed to add test: $res";
        return display_body();
    }

    $is_modified = 1;

    $current_test = $res;

    save_state();

    $status_msg = "Test ".$description." Added";
    return display_body();
}

sub update_owamp_test_port_range {
    my ($min_port, $max_port) = @_;

    my ($status, $res);

    if ($min_port eq "NaN" or $max_port eq "NaN") {
        ( $status, $res ) = $testing_conf->reset_local_port_range({ test_type => "owamp" });
    } else {
        ( $status, $res ) = $testing_conf->set_local_port_range( { test_type => "owamp", min_port => $min_port, max_port => $max_port } );
    }

    if ( $status != 0 ) {
        $error_msg = "Port range update failed: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    return display_body();
}

sub update_bwctl_test_port_range {
    my ($min_port, $max_port) = @_;

    if ($min_port eq "NaN" or $max_port eq "NaN") {
        $min_port = 0;
        $max_port = 0;
    }

    unless ($min_port <= $max_port) {
        $error_msg = "Minimum port must be less than maximum port";
        return display_body();
    }

    unless (($min_port == 0 and $max_port == 0) or ($max_port - $min_port) > 0) {
        $error_msg = "Must specify at least two ports";
        return display_body();
    }

    my ($test_min_port, $test_max_port, $iperf_min_port, $iperf_max_port);

    # Divide the range into the "iperf" ports, and the "peer" ports.
    $test_min_port = $min_port;
    $test_max_port = int(($max_port - $min_port)/2) + $min_port;
    $iperf_min_port = int(($max_port - $min_port)/2) + 1 + $min_port;
    $iperf_max_port = $max_port;

    my ($status, $res);

    ( $status, $res ) = $bwctl_conf->set_port_range({ port_type => "peer", min_port => $test_min_port, max_port => $test_max_port });
    if ( $status != 0 ) {
        $error_msg = "Port range update failed: $res";
        return display_body();
    }

    ( $status, $res ) = $bwctl_conf->set_port_range({ port_type => "iperf", min_port => $iperf_min_port, max_port => $iperf_max_port });
    if ( $status != 0 ) {
        $error_msg = "Port range update failed: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    return display_body();
}

sub update_bwctl_throughput_test {
    my ($id, $description, $duration, $test_interval, $tool, $protocol, $window_size, $udp_bandwidth) = @_;

    my ( $status, $res );

    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, description => $description } );
    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, test_interval => $test_interval } );
    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, tool => $tool } );
    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, duration => $duration } );
    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, protocol => $protocol } );
    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, udp_bandwidth => $udp_bandwidth } );
    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, window_size => $window_size } );

    if ( $status != 0 ) {
        $error_msg = "Test update failed: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    $status_msg = "Test updated";
    return display_body();
}

sub add_owamp_test {
    my ($description, $packet_interval, $packet_padding, $session_packets, $sample_packets, $bucket_width, $loss_threshold) = @_;

    my ( $status, $res ) = $testing_conf->add_test_owamp(
        {
            mesh_type        => "star",
            description      => $description,
            packet_interval  => $packet_interval,
            loss_threshold   => $loss_threshold,
            session_count    => $session_packets,
            sample_count     => $sample_packets,
            packet_padding   => $packet_padding,
            bucket_width     => $bucket_width,
        }
    );

    if ( $status != 0 ) {
        $error_msg = "Failed to add test: $res";
        return display_body();
    }

    $current_test = $res;

    $is_modified = 1;

    save_state();

    $status_msg = "Test ".$description." Added";
    return display_body();
}

sub update_owamp_test {
    my ($id, $description, $packet_interval, $packet_padding, $session_packets, $sample_packets, $bucket_width, $loss_threshold) = @_;

    my ( $status, $res );

    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, description => $description } );
    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, packet_interval => $packet_interval } );
    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, packet_padding => $packet_padding } );
    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, bucket_width => $bucket_width } );
    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, loss_threshold => $loss_threshold } );
    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, session_count  => $session_packets } );
    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, sample_count => $sample_packets } );

    if ( $status != 0 ) {
        $error_msg = "Test update failed: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    $status_msg = "Test updated";
    return display_body();
}

sub add_traceroute_test {
    my ($description, $test_interval, $packet_size, $timeout, $waittime, $first_ttl, $max_ttl, $pause, $protocol) = @_;

    # Add the new group
    my ( $status, $res ) = $testing_conf->add_test_traceroute(
        {
            mesh_type     => "star",
            description   => $description,
            test_interval => $test_interval,
            packet_size   => $packet_size,
            timeout       => $timeout,
            waittime      => $waittime,
            first_ttl     => $first_ttl,
            max_ttl       => $max_ttl,
            pause       => $pause,
            protocol      => $protocol,
        }
    );

    if ( $status != 0 ) {
        $error_msg = "Failed to add test: $res";
        return display_body();
    }

    $is_modified = 1;

    $current_test = $res;

    save_state();

    $status_msg = "Test ".$description." Added";
    return display_body();
}

sub update_traceroute_test {
    my ($id, $description, $test_interval, $packet_size, $timeout, $waittime, $first_ttl, $max_ttl, $pause, $protocol) = @_;

    my ( $status, $res );

    ( $status, $res ) = $testing_conf->update_test_traceroute( { test_id => $id, description => $description } );
    ( $status, $res ) = $testing_conf->update_test_traceroute( { test_id => $id, test_interval => $test_interval } );
    ( $status, $res ) = $testing_conf->update_test_traceroute( { test_id => $id, packet_size => $packet_size } );
    ( $status, $res ) = $testing_conf->update_test_traceroute( { test_id => $id, timeout => $timeout } );
    ( $status, $res ) = $testing_conf->update_test_traceroute( { test_id => $id, waittime => $waittime } );
    ( $status, $res ) = $testing_conf->update_test_traceroute( { test_id => $id, first_ttl => $first_ttl } );
    ( $status, $res ) = $testing_conf->update_test_traceroute( { test_id => $id, max_ttl => $max_ttl } );
    ( $status, $res ) = $testing_conf->update_test_traceroute( { test_id => $id, pause => $pause } );
    ( $status, $res ) = $testing_conf->update_test_traceroute( { test_id => $id, protocol => $protocol } );

    if ( $status != 0 ) {
        $error_msg = "Test update failed: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    $status_msg = "Test updated";
    return display_body();
}

sub add_pinger_test {
    my ($description, $packet_size, $packet_count, $packet_interval, $test_interval, $test_offset, $ttl) = @_;

    my ( $status, $res ) = $testing_conf->add_test_pinger(
        {
            description     => $description,
            packet_size     => $packet_size,
            packet_count    => $packet_count,
            packet_interval => $packet_interval,
            test_interval   => $test_interval,
            test_offset     => $test_offset,
            ttl             => $ttl,
        }
    );

    if ( $status != 0 ) {
        $error_msg = "Failed to add test: $res";
        return display_body();
    }

    $current_test = $res;

    $is_modified = 1;

    save_state();

    $status_msg = "Test ".$description." Added";
    return display_body();
}

sub update_pinger_test {
    my ($id, $description, $packet_size, $packet_count, $packet_interval, $test_interval, $test_offset, $ttl) = @_;

    my ( $status, $res );

    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, description => $description } );
    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, packet_interval => $packet_interval } );
    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, packet_count => $packet_count } );
    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, packet_size => $packet_size } );
    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, test_interval => $test_interval } );
    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, test_offset => $test_offset } );
    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, ttl => $ttl } );

    if ( $status != 0 ) {
        $error_msg = "Test update failed: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    $status_msg = "Test updated";
    return display_body();
}

sub add_member_to_test {
    $error_msg = "";
    my ( $test_id, $address, $port, $description ) = @_;

    my @addressList = split(',', $address);

    my %hostname;

    foreach my $addr(@addressList){
        $addr = $1 if ($addr =~ /^\[(.*)\]$/);

            if ( is_ipv4( $addr ) ) {
                $hostname{$addr} = reverse_dns( $addr );
         }
        elsif ( &Net::IP::ip_is_ipv6( $addr ) ) {
                 $hostname{$addr} = reverse_dns( $addr );
        }
        elsif ( is_hostname( $addr ) ) {
                $hostname{$addr} = $addr;
         }
        else {
                $error_msg = "Can't parse the specified address";
                return display_body();
        }

    }

   my %status;
   my %res;
   foreach my $addr(@addressList){
            my $new_description = $description;

            $new_description = $hostname{$addr} if ( not $description and $hostname{$addr} );
            $new_description = $addr  if ( not $description and $addr );

            $logger->debug( "Adding address: $addr Port: $port Description: $description" );

            ( $status{$addr}, $res{$addr} ) = $testing_conf->add_test_member(
                {
                        test_id     => $test_id,
                        address     => $addr,
                        port        => $port,
                        description => $description,
                        sender      => 1,
                        receiver    => 1,
                }
             );

   }

   foreach my $addr (@addressList){
        if ( $status{$addr} != 0 ) {
                $error_msg = "Failed to add test: $res{$addr}\n";
                #return display_body();
        }
   }

   if($error_msg ne ""){
        return display_body();
   }

    $is_modified = 1;

    save_state();

    $status_msg = "Host(s) Added To Test";
    return display_body();
}


sub remove_member_from_test {
    my ( $test_id, $member_id ) = @_;

    my ( $status, $res ) = $testing_conf->remove_test_member( { test_id => $test_id, member_id => $member_id } );
    if ( $status != 0 ) {
        $error_msg = "Host removal failed: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    $status_msg = "Host removed from test";
    return display_body();
}

sub delete_test {
    my ( $test_id ) = @_;

    $testing_conf->delete_test( { test_id => $test_id } );

    $is_modified = 1;

    save_state();

    $status_msg = "Test deleted";
    return display_body();
}

sub lookup_servers {
    my ( $test_id, $keyword ) = @_;

    my ( $status, $res ) = $testing_conf->lookup_test( { test_id => $test_id } );
    unless ( $status == 0 ) {
        $error_msg = "Invalid test";
        return display_body();
    }

    my $test = $res;

    if ($conf{"use_cache"}) {
        ($status, $res) = lookup_servers_cache($test->{type}, $keyword);
    } else {
        ($status, $res) = lookup_servers_gls($test->{type}, $keyword);
    }

    if ($status != 0) {
        $error_msg = $res;
        return display_body();
    }

    my @addresses = ();

    foreach my $service (@{ $res->{hosts} }) {
        foreach my $full_addr (@{ $service->{addresses} }) {
            my $addr;

            if ( $full_addr =~ /^(tcp|http):\/\/\[[^\]]*\]/ ) {
                $addr = $2;
            }
            elsif ( $full_addr =~ /^(tcp|http):\/\/([^\/:]*)/ ) {
                $addr = $2;
            }
            else {
                $addr = $full_addr;
            }

            push @addresses, $addr;
        }
    }

    lookup_addresses(\@addresses, $dns_cache);

    my @hosts = ();

    foreach my $service (@{ $res->{hosts} }) {
        my @addrs = ();
        my @dns_names = ();
        foreach my $contact (@{ $service->{addresses} }) {

            my ( $addr, $port );
            if ( $test->{type} eq "pinger" ) {
                $addr = $contact;
            }
            else {
                # The addresses here are tcp://ip:port or tcp://[ip]:[port] or similar
                if ( $contact =~ /^tcp:\/\/\[(.*)\]:(\d+)$/ ) {
                    $addr = $1;
                    $port = $2;
                }
                elsif ( $contact =~ /^tcp:\/\/\[(.*)\]$/ ) {
                    $addr = $1;
                }
                elsif ( $contact =~ /^tcp:\/\/(.*):(\d+)$/ ) {
                    $addr = $1;
                    $port = $2;
                }
                elsif ( $contact =~ /^tcp:\/\/(.*)$/ ) {
                    $addr = $1;
                }
                else {
                    $addr = $contact;
                }
            }

            my $cached_dns_info = $dns_cache->{$addr};
            my ($dns_name, $ip);

            $logger->info("Address: ".$addr);

            if (is_ipv4($addr) or &Net::IP::ip_is_ipv6( $addr ) ) {
                if ( $cached_dns_info ) {
                    foreach my $dns_name (@$cached_dns_info) {
                        push @dns_names, $dns_name;
                    }
                    $dns_name = $cached_dns_info->[0];
                }

                $ip = $addr;
            } else {
                push @dns_names, $addr;
                $dns_name = $addr;
                if ( $cached_dns_info ) {
                    $ip = join ', ', @{ $cached_dns_info };
                }
            }

            # XXX improve this

            next if $addr =~ m/^10\./;
            next if $addr =~ m/^192\.168\./;
            next if $addr =~ m/^172\.16/;

            push @addrs, { address => $addr, dns_name => $dns_name, ip => $ip, port => $port };
        }

        my %service_info = ();
        $service_info{"name"} = $service->{name};
        $service_info{"description"} = $service->{description};
        $service_info{"dns_names"}   = \@dns_names;
        $service_info{"addresses"}   = \@addrs;

        push @hosts, \%service_info;
    }

    my %lookup_info = ();
    $lookup_info{hosts}   = \@hosts;
    $lookup_info{keyword} = $keyword;
    $lookup_info{check_time} = $res->{check_time};

    $lookup_info->{$test_id} = \%lookup_info;

    save_state();

    $status_msg = "";
    return display_body();
}

sub lookup_servers_gls {
    my ( $service_type, $keyword ) = @_;

    my @hosts = ();

    my $gls = perfSONAR_PS::Client::Parallel::gLS->new( {} );

    my $parser = XML::LibXML->new();

    $logger->debug( "lookup_servers_gls($service_type, $keyword)" );

    unless ( $gls->{ROOTS} ) {
        $logger->info( "No gLS Roots found!" );
        $error_msg = "Error looking up hosts";
        return display_body();
    }

    my @eventTypes = ();
    if ( $service_type eq "pinger" ) {
        push @eventTypes, "http://ggf.org/ns/nmwg/tools/ping/1.0";
    }
    elsif ( $service_type eq "bwctl/throughput" ) {
        push @eventTypes, "http://ggf.org/ns/nmwg/tools/bwctl/1.0";
    }
    elsif ( $service_type eq "owamp" ) {
        push @eventTypes, "http://ggf.org/ns/nmwg/tools/owamp/1.0";
    }
    else {
        $error_msg = "Unknown server type specified";
        return (-1, $error_msg);
    }

    my @keywords = ( "project:" . $keyword );

    my $result;
    my $start_time = time;
    $result = $gls->getLSLocation( { eventTypes => \@eventTypes, keywords => \@keywords } );
    my $end_time = time;

    unless ( $result ) {
        $lookup_info = undef;
        $error_msg   = "Problem looking up hosts";
        return (-1, $error_msg);
    }

    foreach my $s ( @{$result} ) {
        my $doc = $parser->parse_string( $s );

        my $res;

        my $name = findvalue( $doc->getDocumentElement, ".//*[local-name()='name']", 0 );
        my $description = findvalue( $doc->getDocumentElement, ".//*[local-name()='description']", 0 );

        my @addrs = ();
        $res = find( $doc->getDocumentElement, ".//*[local-name()='address']", 0 );
        foreach my $c ( $res->get_nodelist ) {
            my $contact = extract( $c, 0 );

            $logger->info( "Adding $contact to address list" );

            push @addrs, $contact;
        }

        my %service_info = ();
        $service_info{"name"} = $name;
        $service_info{"description"} = $description;
        $service_info{"addresses"}   = \@addrs;

        push @hosts, \%service_info;
    }

    return (0, { hosts => \@hosts, check_time => time });
}

sub lookup_servers_cache {
    my ( $service_type, $keyword ) = @_;

    my $service_cache_file;
    if ( $service_type eq "pinger" ) {
        $service_cache_file = "list.ping";
    }
    elsif ( $service_type eq "bwctl/throughput" ) {
        $service_cache_file = "list.bwctl";
    }
    elsif ( $service_type eq "owamp" ) {
        $service_cache_file = "list.owamp";
    }
    elsif ( $service_type eq "traceroute" ) {
        $service_cache_file = "list.traceroute";
    }
    else {
        $error_msg = "Unknown server type specified";
        return (-1, $error_msg);
    }

    my $project_keyword = "project:" . $keyword;

    # Find out which hLSes contain services with the keywords we want (this is,
    # i think, the best we can do with the cache, if a service is in an hLS and
    # that hLS has a certain set of keywords in it, we assume that service has
    # that set of keywords).
    my %hlses = ();

    open(HLS_CACHE_FILE, "<", $conf{cache_directory}."/list.hls") or $logger->debug("Couldn't open ".$conf{cache_directory}."/list.hls");
    while(<HLS_CACHE_FILE>) {
        chomp;

        my ($url, $name, $type, $description, $keywords) = split(/\|/, $_);

        next unless ($keywords);

        #$logger->debug("Found hLS $url/$name/$type/$description/$keywords");
        foreach my $curr_keyword (split(/,/, $keywords)) {
            #$logger->debug("hLS $url has keyword $curr_keyword($project_keyword)");
            if ($curr_keyword eq $project_keyword) {
                #$logger->debug("hLS $url has keyword $keyword. Adding to hlses hash");
                $hlses{$url} = 1;
            }
        }
    }
    close(HLS_CACHE_FILE);

    # Find out which services are contained in the hLSes found above.
    my %services = ();

    open(HLS_MAP_FILE, "<", $conf{cache_directory}."/list.hlsmap");
    while(<HLS_MAP_FILE>) {
        chomp;

        my ($url, $hosts) = split(/\|/, $_);

        #$logger->debug("Checking hLS $url which has hosts '$hosts'");
        next unless $hlses{$url};
        #$logger->debug("hLS $url was found");

        foreach my $curr_addr (split(',', $hosts)) {
            #$logger->debug("hLS $url has service $curr_addr");
            $services{$curr_addr} = 1;
        }
    }
    close(HLS_MAP_FILE);

    # Find out which services are in hLSes that contain the keyword we're
    # looking for.
    my @hosts = ();

    open(SERVICE_FILE, "<", $conf{cache_directory}."/".$service_cache_file);
    while(<SERVICE_FILE>) {
        chomp;

        my ($url, $name, $type, $description) = split(/\|/, $_);

        #$logger->debug("Found service $url");

        next unless $services{$url};

        #$logger->debug("service $url is in the set to return");

        push @hosts, { addresses => [ $url ], name => $name, description => $description };
    }
    close(HLS_MAP_FILE);

    my ( $mtime ) = ( stat( $conf{cache_directory}."/".$service_cache_file ) )[9];

    return (0, { hosts => \@hosts, check_time => $mtime });
}

sub lookup_addresses {
    my ($addresses, $dns_cache) = @_;

    my %addresses_to_lookup = ();
    my %hostnames_to_lookup = ();

    foreach my $addr (@{ $addresses }) {
            $addr = $1 if ($addr =~ /^\[(.*)\]$/);

            next if ($dns_cache->{$addr});

            if (is_ipv4($addr) or &Net::IP::ip_is_ipv6( $addr ) ) {
                $logger->debug("$addr is an IP");
                $addresses_to_lookup{$addr} = 1;
            } elsif (is_hostname($addr)) {
                $hostnames_to_lookup{$addr} = 1;
                $logger->debug("$addr is a hostname");
            } else {
                $logger->debug("$addr is unknown");
            }
    }

    my @addresses_to_lookup = keys %addresses_to_lookup;
    my @hostnames_to_lookup = keys %hostnames_to_lookup;

    my $resolved_hostnames = resolve_address_multi({ addresses => \@hostnames_to_lookup, timeout => 2 });
    foreach my $hostname (keys %{ $resolved_hostnames }) {
        $dns_cache->{$hostname} = $resolved_hostnames->{$hostname};
    }

    my $resolved_addresses = reverse_dns_multi({ addresses => \@addresses_to_lookup, timeout => 2 });

    foreach my $ip (keys %{ $resolved_addresses }) {
        $dns_cache->{$ip} = $resolved_addresses->{$ip};
    }

    return;
}

sub repair_hosts_file{
    my $hosts_file_config = perfSONAR_PS::NPToolkit::Config::HostsFile->new();
    if($hosts_file_config->init() != 0){
        $error_msg = "Unable to initialize hosts file manager";
    }else{
        my ( $status, $res ) = $hosts_file_config->save( { restart_services => 0 } );
        if ($status != 0) {
            $error_msg = "$res";
        }else{
            $status_msg="Hosts file successfully repaired";
        }
    }
    
    return display_body();
}

1;

# vim: expandtab shiftwidth=4 tabstop=4
