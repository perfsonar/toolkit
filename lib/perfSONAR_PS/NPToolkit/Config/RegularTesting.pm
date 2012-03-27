package perfSONAR_PS::NPToolkit::Config::RegularTesting;

use strict;
use warnings;

our $VERSION = 3.2;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::RegularTesting

=head1 DESCRIPTION

Module is a catch-all for configuring with PingER and perfSONAR-BUOY tests.
Longer term, this should probably be split into separate modules, but for now
it's one. The test description model used is a combination of the semantics of
the PingER and pSB models.

In this model, there are only tests. These tests can them have members added to
them. These members can either be hostnames, IPv4 or IPv6 addresses. The module
then takes care to make sure that these concepts can be done using the PingER
and pSB model. The model currently assumes that in star configuration, the
center is always the local host.

=cut

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'LOCAL_ADDRS', 'LOCAL_PORT_RANGES', 'TESTS', 'PERFSONARBUOY_CONF_TEMPLATE', 'PERFSONARBUOY_CONF_FILE', 'PINGER_LANDMARKS_CONF_FILE', 'OWMESH_PARAMETERS';

use POSIX;
use File::Basename qw(dirname basename);
use Data::Dumper;
use Params::Validate qw(:all);
use Storable qw(store retrieve freeze thaw dclone);
use Template;
use File::Basename;

use Data::Validate::IP qw(is_ipv4);
use Data::Validate::Domain qw(is_hostname);
use Net::IP;

use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology::Domain';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology::Domain::Node';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Name';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Comments';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::HostName';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Description';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmwg::Topology::Domain::Node::Parameters';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmwg::Topology::Domain::Node::Parameters::Parameter';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtl3::Topology::Domain::Node::Port';

use OWP::Conf;

use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file restart_service stop_service );
use perfSONAR_PS::Utils::DNS qw( reverse_dns resolve_address );
use perfSONAR_PS::Common qw(genuid);
use perfSONAR_PS::NPToolkit::Config::ExternalAddress;

# These are the defaults for the current NPToolkit
my %defaults = (
    perfsonarbuoy_conf_template => "/opt/perfsonar_ps/toolkit/templates/config/owmesh_conf.tmpl",
    perfsonarbuoy_conf_file     => "/opt/perfsonar_ps/perfsonarbuoy_ma/etc/owmesh.conf",
    pinger_landmarks_file       => "/opt/perfsonar_ps/PingER/etc/pinger-landmarks.xml",
);

=head2 init({ perfsonarbuoy_conf_template => 0, perfsonarbuoy_conf_file => 0, pinger_landmarks_file => 0 })

Initializes the client. Returns 0 on success and -1 on failure. The parameters
can be specified to set which files the module should use for reading/writing
the configuration.

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            perfsonarbuoy_conf_template => 0,
            perfsonarbuoy_conf_file     => 0,
            pinger_landmarks_file       => 0,
        }
    );

    my ( $status, $res );

    ( $status, $res ) = $self->SUPER::init();
    if ( $status != 0 ) {
        return ( $status, $res );
    }

    # Initialize the defaults
    $self->{PERFSONARBUOY_CONF_TEMPLATE} = $defaults{perfsonarbuoy_conf_template};
    $self->{PERFSONARBUOY_CONF_FILE}     = $defaults{perfsonarbuoy_conf_file};
    $self->{PINGER_LANDMARKS_CONF_FILE}  = $defaults{pinger_landmarks_file};

    $self->{PERFSONARBUOY_CONF_TEMPLATE} = $parameters->{perfsonarbuoy_conf_template} if ( $parameters->{perfsonarbuoy_conf_template} );
    $self->{PERFSONARBUOY_CONF_FILE}     = $parameters->{perfsonarbuoy_conf_file}     if ( $parameters->{perfsonarbuoy_conf_file} );
    $self->{PINGER_LANDMARKS_CONF_FILE}  = $parameters->{pinger_landmarks_file}       if ( $parameters->{pinger_landmarks_file} );

    ( $status, $res ) = $self->reset_state();
    if ( $status != 0 ) {
        return ( $status, $res );
    }

    return ( 0, "" );
}

=head2 save({ restart_services => 0 })
    Saves the configuration to disk. The PingER/pSB services can be restarted
    by specifying the "restart_services" parameter as 1. 
=cut

sub save {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { restart_services => 0, } );

    my ($status, $res);

    my @pinger_tests = ();
    my @psb_tests    = ();

    my $pinger_tests = 0;
    my $psb_owamp_tests = 0;
    my $psb_bwctl_tests = 0;
    my $traceroute_tests = 0;
    
    foreach my $key ( keys %{ $self->{TESTS} } ) {
        if ( $self->{TESTS}->{$key}->{type} eq "pinger" ) {
            push @pinger_tests, $self->{TESTS}->{$key};
            $pinger_tests++;
        }
        else {
            push @psb_tests, $self->{TESTS}->{$key};
            if ($self->{TESTS}->{$key}->{type} eq "owamp") {
                $psb_owamp_tests++;
            }elsif ($self->{TESTS}->{$key}->{type} eq "traceroute") {
                $traceroute_tests++;
            } else {
                $psb_bwctl_tests++;
            }
        }
    }

    my $pinger_conf_output = $self->generate_pinger_landmarks_file( { tests => \@pinger_tests } );

    $res = save_file( { file => $self->{PINGER_LANDMARKS_CONF_FILE}, content => $pinger_conf_output } );
    if ( $res == -1 ) {
        return ( -1, "Couldn't save PingER configuration" );
    }

    ($status, $res) = $self->generate_owmesh_conf( { tests => \@psb_tests, owmesh_parameters => $self->{OWMESH_PARAMETERS} } );
    if ( $status != 0 ) {
        return ( -1, "Couldn't save perfSONAR-BUOY configuration" );
    }
    my $perfsonarbuoy_conf_output = $res;

    $status = save_file( { file => $self->{PERFSONARBUOY_CONF_FILE}, content => $perfsonarbuoy_conf_output } );
    if ( $status != 0 ) {
        return ( -1, "Couldn't save perfSONAR-BUOY configuration" );
    }

    if ( $parameters->{restart_services} ) {
        if ($psb_bwctl_tests) {
            $status = restart_service( { name => "perfsonarbuoy_bwctl" } );
            if ( $status != 0 ) {
                return ( -1, "Couldn't restart perfSONAR-BUOY Throughput Collector" );
            }
        }
        else {
            $status = stop_service( { name => "perfsonarbuoy_bwctl" } );
        }
        
        if ($psb_owamp_tests) {
            $status = restart_service( { name => "perfsonarbuoy_owamp" } );
            if ( $status != 0 ) {
                return ( -1, "Couldn't restart perfSONAR-BUOY Latency Collector" );
            }
        }
        else {
            $status = stop_service( { name => "perfsonarbuoy_owamp" } );
        }
        
        if ( $traceroute_tests ) {
            $status = restart_service( { name => "traceroute_scheduler" } ); 
            if ( $status != 0 ) {
                return ( -1, "Couldn't restart traceroute scheduler" );
            }
            $status = restart_service( { name => "traceroute_ma" } ); 
            if ( $status != 0 ) {
                return ( -1, "Couldn't restart traceroute MA" );
            }
        }
        else {
            $status = stop_service( { name => "traceroute_scheduler" } );
            $status = stop_service( { name => "traceroute_ma" } );
        }

        $status = restart_service( { name => "perfsonarbuoy_ma" } );
        if ( $status != 0 ) {
            return ( -1, "Couldn't restart perfSONAR-BUOY Measurement Archive" );
        }

        # PingER is both the collector and the MA, so we have to restart it, even if there are no tests.
        $status = restart_service( { name => "pinger" } );
        if ( $status != 0 ) {
            return ( -1, "Couldn't restart PingER" );
        }
    }

    return ( 0, "" );
}

=head2 last_modified()
    Returns when the site information was last saved.
=cut

sub last_modified {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ($mtime1) = (stat ( $self->{PINGER_LANDMARKS_CONF_FILE} ) )[9];
    my ($mtime2) = (stat ( $self->{PERFSONARBUOY_CONF_FILE} ) )[9];

    my $mtime = ($mtime1 > $mtime2)?$mtime1:$mtime2;

    return $mtime;
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
=cut

sub reset_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    # Reset the tests
    $self->{TESTS} = ();

    my ( $status, $res );

    ( $status, $res ) = $self->parse_owmesh_conf( { file => $self->{PERFSONARBUOY_CONF_FILE} } );
    if ( $status != 0 ) {
        $self->{TESTS} = ();
        $self->{LOGGER}->error( "$res" );
        return ( -1, "Problem reading perfSONAR-BUOY Configuration" );
    }

    ( $status, $res ) = $self->parse_pinger_landmarks_file( { file => $self->{PINGER_LANDMARKS_CONF_FILE} } );
    if ( $status != 0 ) {
        $self->{TESTS} = ();
        $self->{LOGGER}->error( "$res" );
        return ( -1, "Problem reading PingER Configuration" );
    }

    return ( 0, "" );
}

sub add_local_address {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { address => 1, } );

    my $address = $parameters->{address};

    $self->{LOCAL_ADDRS}->{$address} = 1;

    return ( 0, "" );
}

sub remove_local_address {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { address => 1, } );

    my $address = $parameters->{address};

    delete( $self->{LOCAL_ADDRS}->{$address} );

    return ( 0, "" );
}

sub set_local_port_range {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { test_type => 1, min_port => 1, max_port => 1 } );

    my $test_type = $parameters->{test_type};
    my $min_port  = $parameters->{min_port};
    my $max_port  = $parameters->{max_port};

    unless ($test_type eq "pinger" or $test_type eq "owamp" or $test_type eq "bwctl_throughput") {
        return (-1, "Unknown test type: $test_type");
    }

    if ($test_type eq "owamp") {
        if ($max_port - $min_port < 3) {
            return (-1, "Invalid port range: must have at least 3 ports for owamp tests");
        }
    }

    if ($max_port < $min_port) {
        return (-1, "Invalid port range: min port < max port");
    }

    $self->{LOCAL_PORT_RANGES}->{$test_type}->{min_port} = $min_port;
    $self->{LOCAL_PORT_RANGES}->{$test_type}->{max_port} = $max_port;

    return (0, "");
}

sub get_local_port_range {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { test_type => 1 } );

    my $test_type = $parameters->{test_type};

    unless ($test_type eq "pinger" or $test_type eq "owamp" or $test_type eq "bwctl_throughput") {
        return (-1, "Unknown test type: $test_type");
    }

    return (0, $self->{LOCAL_PORT_RANGES}->{$test_type});
}

sub reset_local_port_range {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { test_type => 1 } );

    my $test_type = $parameters->{test_type};

    unless ($test_type eq "pinger" or $test_type eq "owamp" or $test_type eq "bwctl_throughput") {
        return (-1, "Unknown test type: $test_type");
    }

    delete($self->{LOCAL_PORT_RANGES}->{$test_type}) if ($self->{LOCAL_PORT_RANGES}->{$test_type});

    return (0, "");
}

=head2 get_tests({})
    Returns the set of tests as an array of hashes. Returns (0, \@tests) on success.
=cut

sub get_tests {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my @tests = ();
    foreach my $key ( sort keys %{ $self->{TESTS} } ) {
        my ( $status, $res ) = $self->lookup_test( { test_id => $key } );

        push @tests, $res;
    }
    return ( 0, \@tests );
}

=head2 lookup_test({ test_id => 1 })
    Returns the test with the specified test identifier. Returns (-1,
    $error_msg) on failure and (0, \%test_info) on success. \%test_info is a
    hash containing the test properties (description, parameters, members,
    etc).
=cut

sub lookup_test {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { test_id => 1, } );

    my $test_id = $parameters->{test_id};

    my $test = $self->{TESTS}->{$test_id};

    return ( -1, "Invalid test specified" ) unless ( $test );

    my %test_info = ();
    $test_info{id}          = $test->{id};
    $test_info{type}        = $test->{type};
    $test_info{description} = $test->{description};
    $test_info{mesh_type}   = $test->{mesh_type};
    $test_info{parameters}  = $test->{parameters};

    my @members = ();
    foreach my $member_id ( keys %{ $test->{members} } ) {
        push @members, $test->{members}->{$member_id};
    }

    $test_info{members} = \@members;

    return ( 0, \%test_info );
}

=head2 add_test_owamp({ mesh_type => 1, name => 0, description => 1, packet_padding => 1, packet_interval => 1, bucket_width => 1, loss_threshold => 1, session_duration => 1 })
    Adds a new OWAMP test to the list. mesh_type must be "star" as mesh tests
    aren't currently supported. 'name' can be used to give the test the name
    that will be used in the owmesh file which would be autogenerated
    otherwise. packet_padding, packet_interval, bucket_width, loss_threshold and
    session_duration correspond to the pSB powstream test parameters. Returns (-1, $error_msg)
    on failure and (0, $test_id) on success.
=cut 

sub add_test_owamp {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            mesh_type        => 1,
            name             => 0,
            description      => 1,
            packet_interval  => 1,
            loss_threshold   => 1,
            session_count    => 1,
            sample_count     => 1,
            packet_padding   => 1,
            bucket_width     => 1,
        }
    );

    $self->{LOGGER}->debug( "Adding owamp test" );

    my $test_id;
    do {
        $test_id = "test." . genuid();
    } while ( $self->{TESTS}->{$test_id} );

    my %test = ();
    $test{id}          = $test_id;
    $test{type}        = "owamp";
    $test{mesh_type}   = $parameters->{mesh_type};
    $test{name}        = $parameters->{name};
    $test{description} = $parameters->{description} if ( defined $parameters->{description} );

    my %test_parameters = ();
    $test_parameters{packet_interval}  = $parameters->{packet_interval}  if ( defined $parameters->{packet_interval} );
    $test_parameters{loss_threshold}   = $parameters->{loss_threshold}   if ( defined $parameters->{loss_threshold} );
    $test_parameters{session_count}    = $parameters->{session_count}    if ( defined $parameters->{session_count} );
    $test_parameters{sample_count}     = $parameters->{sample_count}     if ( defined $parameters->{sample_count} );
    $test_parameters{packet_padding}   = $parameters->{packet_padding}   if ( defined $parameters->{packet_padding} );
    $test_parameters{bucket_width}     = $parameters->{bucket_width}     if ( defined $parameters->{bucket_width} );

    $test{parameters} = \%test_parameters;

    my %tmp = ();
    $test{members} = \%tmp;

    $self->{TESTS}->{$test_id} = \%test;

    return ( 0, $test_id );
}

=head2 update_test_owamp({ test_id => 1, name => 0, description => 0, packet_padding => 0, packet_interval => 0, bucket_width => 0, loss_threshold => 0, session_duration => 0 })
    Updates a existing OWAMP test. 'name' can be used to give the test the name
    that will be used in the owmesh file which would be autogenerated
    otherwise. packet_padding, packet_interval, bucket_width, loss_threshold and
    session_duration correspond to the pSB powstream test parameters. Returns
    (-1, $error_msg) on failure and (0, "") on success.
=cut

sub update_test_owamp {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            test_id          => 1,
            name             => 0,
            description      => 0,
            bucket_width     => 0,
            packet_padding   => 0,
            loss_threshold   => 0,
            packet_interval  => 0,
            session_count    => 0,
            sample_count     => 0,
        }
    );

    $self->{LOGGER}->debug( "Updating owamp test " . $parameters->{test_id} );

    my $test = $self->{TESTS}->{ $parameters->{test_id} };

    return ( -1, "Test does not exist" ) unless ( $test );
    return ( -1, "Test is not owamp" ) unless ( $test->{type} eq "owamp" );

    $test->{name}                           = $parameters->{name}             if ( defined $parameters->{name} );
    $test->{description}                    = $parameters->{description}      if ( defined $parameters->{description} );
    $test->{parameters}->{packet_interval}  = $parameters->{packet_interval}  if ( defined $parameters->{packet_interval} );
    $test->{parameters}->{loss_threshold}   = $parameters->{loss_threshold}   if ( defined $parameters->{loss_threshold} );
    $test->{parameters}->{session_count}    = $parameters->{session_count}    if ( defined $parameters->{session_count} );
    $test->{parameters}->{sample_count}     = $parameters->{sample_count}     if ( defined $parameters->{sample_count} );
    $test->{parameters}->{packet_padding}   = $parameters->{packet_padding}   if ( defined $parameters->{packet_padding} );
    $test->{parameters}->{bucket_width}     = $parameters->{bucket_width}     if ( defined $parameters->{bucket_width} );

    return ( 0, "" );
}

=head2 add_test_bwctl_throughput({ mesh_type => 1, name => 0, description => 1, tool => 1, test_interval => 1, duration => 1, protocol => 1, udp_bandwidth => 0, buffer_length => 0, window_size => 0, report_interval => 0, test_interval_start_alpha => 0 })
    Adds a new BWCTL throughput test to the list. mesh_type must be "star" as mesh tests
    aren't currently supported. 'name' can be used to give the test the name
    that will be used in the owmesh file which would be autogenerated
    otherwise. tool, test_interval, duration, protocol, udp_bandwidth,
    buffer_length, window_size, report_interval, test_interval_start_alpha all
    correspond to the pSB throughput test parameters. Returns (-1, $error_msg)
    on failure and (0, $test_id) on success.
=cut

sub add_test_bwctl_throughput {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            mesh_type                 => 1,
            name                      => 0,
            description               => 1,
            tool                      => 1,
            test_interval             => 1,
            duration                  => 1,
            protocol                  => 1,
            udp_bandwidth             => 0,
            buffer_length             => 0,
            window_size               => 0,
            report_interval           => 0,
            test_interval_start_alpha => 0,
        }
    );

    $self->{LOGGER}->debug( "Add: " . Dumper( $parameters ) );

    my $test_id;
    do {
        $test_id = "test." . genuid();
    } while ( $self->{TESTS}->{$test_id} );

    my %test = ();
    $test{id}          = $test_id;
    $test{name}        = $parameters->{name};
    $test{description} = $parameters->{description};
    $test{type}        = "bwctl/throughput";
    $test{mesh_type}   = $parameters->{mesh_type};

    my %test_parameters = ();
    $test_parameters{tool}                      = $parameters->{tool}                      if ( defined $parameters->{tool} );
    $test_parameters{test_interval}             = $parameters->{test_interval}             if ( defined $parameters->{test_interval} );
    $test_parameters{duration}                  = $parameters->{duration}                  if ( defined $parameters->{duration} );
    $test_parameters{protocol}                  = $parameters->{protocol}                  if ( defined $parameters->{protocol} );
    $test_parameters{udp_bandwidth}             = $parameters->{udp_bandwidth}             if ( defined $parameters->{udp_bandwidth} );
    $test_parameters{buffer_length}             = $parameters->{buffer_length}             if ( defined $parameters->{buffer_length} );
    $test_parameters{window_size}               = $parameters->{window_size}               if ( defined $parameters->{window_size} );
    $test_parameters{report_interval}           = $parameters->{report_interval}           if ( defined $parameters->{report_interval} );
    $test_parameters{test_interval_start_alpha} = $parameters->{test_interval_start_alpha} if ( defined $parameters->{test_interval_start_alpha} );

    $test{parameters} = \%test_parameters;

    my %tmp = ();
    $test{members} = \%tmp;

    $self->{TESTS}->{$test_id} = \%test;

    return ( 0, $test_id );
}

=head2 update_test_bwctl_throughput({ test_id => 1, name => 0, description => 0, tool => 0, test_interval => 0, duration => 0, protocol => 0, udp_bandwidth => 0, buffer_length => 0, window_size => 0, report_interval => 0, test_interval_start_alpha => 0 })
    Updates an existing BWCTL throughput test. mesh_type must be "star" as mesh tests
    aren't currently supported. 'name' can be used to give the test the name
    that will be used in the owmesh file which would be autogenerated
    otherwise. tool, test_interval, duration, protocol, udp_bandwidth,
    buffer_length, window_size, report_interval, test_interval_start_alpha all
    correspond to the pSB throughput test parameters. Returns (-1, $error_msg)
    on failure and (0, "") on success.
=cut

sub update_test_bwctl_throughput {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            test_id       => 1,
            name          => 0,
            description   => 0,
            test_interval => 0,
            tool          => 0,
            duration      => 0,
            protocol      => 0,
            udp_bandwidth => 0,
            buffer_length => 0,
            window_size   => 0,
        }
    );

    $self->{LOGGER}->debug( "Updating bwctl test " . $parameters->{test_id} );

    my $test = $self->{TESTS}->{ $parameters->{test_id} };

    return ( -1, "Test does not exist" ) unless ( $test );
    return ( -1, "Test is not bwctl/throughput" ) unless ( $test->{type} eq "bwctl/throughput" );

    $test->{name}                                    = $parameters->{name}                      if ( defined $parameters->{name} );
    $test->{description}                             = $parameters->{description}               if ( defined $parameters->{description} );
    $test->{parameters}->{tool}                      = $parameters->{tool}                      if ( defined $parameters->{tool} );
    $test->{parameters}->{test_interval}             = $parameters->{test_interval}             if ( defined $parameters->{test_interval} );
    $test->{parameters}->{duration}                  = $parameters->{duration}                  if ( defined $parameters->{duration} );
    $test->{parameters}->{protocol}                  = $parameters->{protocol}                  if ( defined $parameters->{protocol} );
    $test->{parameters}->{udp_bandwidth}             = $parameters->{udp_bandwidth}             if ( exists $parameters->{udp_bandwidth} );
    $test->{parameters}->{buffer_length}             = $parameters->{buffer_length}             if ( exists $parameters->{buffer_length} );
    $test->{parameters}->{window_size}               = $parameters->{window_size}               if ( exists $parameters->{window_size} );
    $test->{parameters}->{report_interval}           = $parameters->{report_interval}           if ( exists $parameters->{report_interval} );
    $test->{parameters}->{test_interval_start_alpha} = $parameters->{test_interval_start_alpha} if ( exists $parameters->{test_interval_start_alpha} );

    return ( 0, "" );
}

=head2 add_test_pinger({ description => 0, packet_size => 1, packet_count => 1, packet_interval => 1, test_interval => 1, test_offset => 1, ttl => 1 })

    Adds a new PingER test to the list. packet_size, packet_count,
    packet_interval, test_interval, test_offset, ttl all correspond to PingER
    test parameters. Returns (-1, $error_msg) on failure and (0, $test_id) on
    success.

=cut

sub add_test_pinger {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            description     => 0,
            packet_size     => 1,
            packet_count    => 1,
            packet_interval => 1,
            test_interval   => 1,
            test_offset     => 1,
            ttl             => 1,
        }
    );

    my $description     = $parameters->{description};
    my $packet_interval = $parameters->{packet_interval};
    my $packet_count    = $parameters->{packet_count};
    my $packet_size     = $parameters->{packet_size};
    my $test_interval   = $parameters->{test_interval};
    my $test_offset     = $parameters->{test_offset};
    my $ttl             = $parameters->{ttl};

    my $test_id;

    # Find an empty domain
    do {
        $test_id = "test." . genuid();
    } while ( $self->{TESTS}->{$test_id} );

    my %members   = ();
    my %test_info = (
        id          => $test_id,
        type        => "pinger",
        mesh_type   => "star",
        description => $description,
        parameters  => {
            packet_interval => $packet_interval,
            packet_count    => $packet_count,
            packet_size     => $packet_size,
            test_interval   => $test_interval,
            test_offset     => $test_offset,
            ttl             => $ttl,
        },
        members => \%members,
    );

    #    Not currently applicable to PingER
    #    # Set the default addresses:
    #    my $external_address_config = perfSONAR_PS::NPToolkit::Config::ExternalAddress->new();
    #    if ($external_address_config->init() == 0) {
    #        $test_info{center}->{ipv4_address} = $external_address_config->get_primary_ipv4();
    #        $test_info{center}->{ipv6_address} = $external_address_config->get_primary_ipv6();
    #
    #        return (-1, "No known external ipv4 or ipv6 addresses") unless ($test_info{center}->{ipv4_address} or $test_info{center}->{ipv6_address});
    #    }

    $self->{TESTS}->{$test_id} = \%test_info;

    return ( 0, $test_id );
}

=head2 update_test_pinger({ description => 0, packet_size => 0, packet_count => 0, packet_interval => 0, test_interval => 0, test_offset => 0, ttl => 0 })

    Updates an existing PingER test. packet_size, packet_count,
    packet_interval, test_interval, test_offset, ttl all correspond to PingER
    test parameters. Returns (-1, $error_msg) on failure and (0, $test_id) on
    success.

=cut

sub update_test_pinger {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            test_id => 1,

            description     => 0,
            packet_interval => 0,
            packet_count    => 0,
            packet_size     => 0,
            test_interval   => 0,
            test_offset     => 0,
            ttl             => 0,
        }
    );

    my $test_id = $parameters->{test_id};

    my $test = $self->{TESTS}->{$test_id};

    return ( -1, "Invalid test specified" ) unless ( $test );

    $test->{description} = $parameters->{description} if ( defined $parameters->{description} );

    $test->{parameters}->{packet_interval} = $parameters->{packet_interval} if ( defined $parameters->{packet_interval} );
    $test->{parameters}->{packet_count}    = $parameters->{packet_count}    if ( defined $parameters->{packet_count} );
    $test->{parameters}->{packet_size}     = $parameters->{packet_size}     if ( defined $parameters->{packet_size} );
    $test->{parameters}->{test_interval}   = $parameters->{test_interval}   if ( defined $parameters->{test_interval} );
    $test->{parameters}->{test_offset}     = $parameters->{test_offset}     if ( defined $parameters->{test_offset} );
    $test->{parameters}->{ttl}             = $parameters->{ttl}             if ( defined $parameters->{ttl} );

    return ( 0, "" );
}

=head2 add_test_traceroute({ mesh_type => 1, name => 0, description => 1, test_interval => 1, packet_size => 0, timeout => 0, waittime => 0, first_ttl => 0, max_ttl => 0, pause => 0, protocol => 0 })
    Add a new traceroute test of type STAR to the owmesh file. All parameters correspond
    to test parameters. Returns (-1, error_msg)  on failure and (0, $test_id) on success.
=cut

sub add_test_traceroute {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            mesh_type     => 1,
            name          => 0,
            description   => 1,
            test_interval => 1,
            packet_size   => 0,
            timeout       => 0,
            waittime      => 0,
            first_ttl     => 0,
            max_ttl       => 0,
            pause         => 0,
            protocol      => 0,
        }
    );

    $self->{LOGGER}->debug( "Add: " . Dumper( $parameters ) );

    my $test_id;
    do {
        $test_id = "test." . genuid();
    } while ( $self->{TESTS}->{$test_id} );

    my %test = ();
    $test{id}          = $test_id;
    $test{name}        = $parameters->{name};
    $test{description} = $parameters->{description};
    $test{type}        = "traceroute";
    $test{mesh_type}   = $parameters->{mesh_type};

    my %test_parameters = ();
    $test_parameters{test_interval}             = $parameters->{test_interval}             if ( defined $parameters->{test_interval} );
    $test_parameters{packet_size}               = $parameters->{packet_size}               if ( defined $parameters->{packet_size} );
    $test_parameters{timeout}                   = $parameters->{timeout}                   if ( defined $parameters->{timeout} );
    $test_parameters{waittime}                  = $parameters->{waittime}                  if ( defined $parameters->{waittime} );
    $test_parameters{first_ttl}                 = $parameters->{first_ttl}                 if ( defined $parameters->{first_ttl} );
    $test_parameters{max_ttl}                   = $parameters->{max_ttl}                   if ( defined $parameters->{max_ttl} );
    $test_parameters{pause}                     = $parameters->{pause}                     if ( defined $parameters->{pause} );
    $test_parameters{protocol}                  = $parameters->{protocol}                  if ( defined $parameters->{protocol} );
    

    $test{parameters} = \%test_parameters;

    my %tmp = ();
    $test{members} = \%tmp;

    $self->{TESTS}->{$test_id} = \%test;

    return ( 0, $test_id );
}

=head2 update_test_traceroute({ mesh_type => 1, name => 0, description => 1, test_interval => 1, packet_size => 0, timeout => 0, waittime => 0, first_ttl => 0, max_ttl => 0, pause => 0, protocol => 0 })
    Updates an existing traceroute test. mesh_type must be "star" as mesh tests
    aren't currently supported. All other parameters corresponf to test parameters.
    Returns (-1, $error_msg) on failure and (0, "") on success.
=cut

sub update_test_traceroute {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            test_id       => 1,
            name          => 0,
            description   => 0,
            test_interval => 0,
            packet_size   => 0,
            timeout       => 0,
            waittime      => 0,
            first_ttl     => 0,
            max_ttl       => 0,
            pause         => 0,
            protocol      => 0,
        }
    );

    $self->{LOGGER}->debug( "Updating traceroute test " . $parameters->{test_id} );

    my $test = $self->{TESTS}->{ $parameters->{test_id} };

    return ( -1, "Test does not exist" ) unless ( $test );
    return ( -1, "Test is not traceroute" ) unless ( $test->{type} eq "traceroute" );

    $test->{name}                                    = $parameters->{name}                      if ( defined $parameters->{name} );
    $test->{description}                             = $parameters->{description}               if ( defined $parameters->{description} );
    $test->{parameters}->{test_interval}             = $parameters->{test_interval}             if ( defined $parameters->{test_interval} );
    $test->{parameters}->{packet_size}               = $parameters->{packet_size}               if ( defined $parameters->{packet_size} );
    $test->{parameters}->{timeout}                   = $parameters->{timeout}                   if ( defined $parameters->{timeout} );
    $test->{parameters}->{waittime}                  = $parameters->{waittime}                  if ( defined $parameters->{waittime} );
    $test->{parameters}->{first_ttl}                 = $parameters->{first_ttl}                 if ( defined $parameters->{first_ttl} );
    $test->{parameters}->{max_ttl}                   = $parameters->{max_ttl}                   if ( defined $parameters->{max_ttl} );
    $test->{parameters}->{pause}                     = $parameters->{pause}                     if ( defined $parameters->{pause} );
    $test->{parameters}->{protocol}                  = $parameters->{protocol}                  if ( defined $parameters->{protocol} );
    
    return ( 0, "" );
}

=head2 delete_test ({ test_id => 1 })
    Removes the test with the "test_id" identifier from the list. Returns (0,
    "") if the test no longer is in the least, even if it never was.
=cut

sub delete_test {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { test_id => 1, } );

    delete( $self->{TESTS}->{ $parameters->{test_id} } );

    return ( 0, "" );
}

=head2 add_test_member ({ test_id => 1, address => 1, port => 0, name => 0, description => 0, sender => 0, receiver => 0 })
    Adds a new address to the test. Address can be either hostname/ipv4/ipv6
    except for PingER where the address must be an ipv4 or ipv6 adress. Port
    specifies which port should be connected to, this is ignored in PingER
    tests. The sender/receiver fields can be set to 1 or 0 and specify whether
    that test member should do a send or receive test, inapplicable for PingER
    tests. Returns (0, $member_id) on success and (-1, $error_msg) on failure.
=cut

sub add_test_member {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            test_id     => 1,
            address     => 1,
            port        => 0,
            name        => 0,
            description => 0,
            sender      => 0,
            receiver    => 0,
        }
    );

    $self->{LOGGER}->debug( "Adding address " . $parameters->{address} . " to test " . $parameters->{test_id} );

    my $test = $self->{TESTS}->{ $parameters->{test_id} };

    return ( -1, "Test does not exist" ) unless ( $test );

    my $name    = $parameters->{name};
    my $address = $parameters->{address};

    $address = $1 if ($address =~ /^\[(.*)\]$/);

    if ( $test->{type} eq "pinger" ) {

        # PingER tests are specified using the IP address...
        if ( is_ipv4( $address ) or &Net::IP::ip_is_ipv6( $address ) ) {
            my $hostname = reverse_dns( $address );

            if ($hostname) {
                $name = $hostname unless ($name);

                $self->{LOGGER}->debug( "Resolved(reverse): $address -> $name" );
            }
            else {
                $self->{LOGGER}->warn( "No hostname for $address, specifying $address as the hostname" );
                $name = $address;
            }
        }
        elsif ( is_hostname( $address ) ) {
            my $hostname = $address;
            my @addresses = resolve_address( $address );
            unless ( $addresses[0] ) {
                return ( -1, "Can't resolve $address" );
            }
 
            $name = $hostname unless ($name);
            $address = $addresses[0];

            $self->{LOGGER}->debug( "Resolved(resolve): $name -> $address" );
        }
        else {
            return ( -1, "Unknown address type" );
        }
    }
    else {
        unless ( is_hostname( $address ) or is_ipv4( $address ) or &Net::IP::ip_is_ipv6( $address ) ) {
            return ( -1, "Unknown address type" );
        }
    }

    my $id;
    do {
        $id = "member." . genuid();
    } while ( $test->{members}->{$id} );

    my %member = ();
    $member{id}          = $id;
    $member{address}     = $address;
    $member{name}        = $name;
    $member{port}        = $parameters->{port};
    $member{description} = $parameters->{description};
    $member{sender}      = $parameters->{sender};
    $member{receiver}    = $parameters->{receiver};

    $test->{members}->{$id} = \%member;

    $self->{LOGGER}->debug("Added new test member: ".Dumper(\%member));

    return ( 0, $id );
}

=head2 update_test_member ({ test_id => 1, member_id => 1, port => 0, name => 0, description => 0, sender => 0, receiver => 0 })
    Updates an existing member in a test.  Port specifies which port should be
    connected to, this is ignored in PingER tests. The sender/receiver fields
    can be set to 1 or 0 and specify whether that test member should do a send
    or receive test, inapplicable for PingER tests. The name field is used to
    make sure that pSB node names stay consistent across re-configurations
    since pSB uses node names to differentiate new elements.
=cut

sub update_test_member {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            test_id     => 1,
            member_id   => 1,
            port        => 0,
            description => 0,
            sender      => 0,
            receiver    => 0,
        }
    );

    $self->{LOGGER}->debug( "Updating test member " . $parameters->{member_id} . " in test " . $parameters->{test_id} );

    my $test = $self->{TESTS}->{ $parameters->{test_id} };

    return ( -1, "Test does not exist" ) unless ( $test );

    my $member = $self->{TESTS}->{members}->{ $parameters->{member_id} };

    return ( -1, "Test member does not exist" ) unless ( $member );

    $member->{port}        = $parameters->{port}        if ( defined $parameters->{port} );
    $member->{description} = $parameters->{description} if ( defined $parameters->{description} );
    $member->{sender}      = $parameters->{sender}      if ( defined $parameters->{sender} );
    $member->{receiver}    = $parameters->{receiver}    if ( defined $parameters->{receiver} );

    return ( 0, "" );
}

=head2 remove_test_member ( { test_id => 1, member_id => 1 })
    Removes the specified member from the test. Returns (-1, $error_msg) if an
    error occurs and (0, "") if the test no longer contains the specified
    member.
=cut

sub remove_test_member {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            test_id   => 1,
            member_id => 1,
        }
    );

    $self->{LOGGER}->debug( "Removing test member " . $parameters->{member_id} . " from test " . $parameters->{test_id} );

    my $test = $self->{TESTS}->{ $parameters->{test_id} };

    return ( -1, "Test does not exist" ) unless ( $test );

    delete( $test->{members}->{ $parameters->{member_id} } );

    return ( 0, "" );
}

=head2 set_test_center ({ test_id => 1, ipv4_address => 0, ipv6_address => 0 })
    Sets the IPv4 and IPv6 addresses that will be the center for the test.
    These address will be used by pSB (not PingER) to specify which interface
    to bind to when making connections.
=cut

sub set_test_center {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            test_id      => 1,
            ipv4_address => 0,
            ipv6_address => 0,
        }
    );

    my $test = $self->{TESTS}->{ $parameters->{test_id} };

    return ( -1, "Test does not exist" ) unless ( $test );

    $test->{center}->{ipv4_address} = $parameters->{ipv4_address} if ( exists $parameters->{ipv4_address} );
    $test->{center}->{ipv6_address} = $parameters->{ipv6_address} if ( exists $parameters->{ipv6_address} );

    return ( 0, "" );
}

=head2 save_state()
    Saves the current state of the module as a string. This state allows the
    module to be recreated later.
=cut

sub save_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %state = (
        tests                       => $self->{TESTS},
        local_addrs                 => $self->{LOCAL_ADDRS},
        local_port_ranges           => $self->{LOCAL_PORT_RANGES},
        perfsonarbuoy_conf_template => $self->{PERFSONARBUOY_CONF_TEMPLATE},
        perfsonarbuoy_conf_file     => $self->{PERFSONARBUOY_CONF_FILE},
        pinger_landmarks_file       => $self->{PINGER_LANDMARKS_CONF_FILE},
        owmesh_parameters           => $self->{OWMESH_PARAMETERS},
    );

    my $str = freeze( \%state );

    return $str;
}

=head2 restore_state({ state => \$state })
    Restores the modules state based on a string provided by the "save_state"
    function above.
=cut

sub restore_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { state => 1, } );

    my $state = thaw( $parameters->{state} );

    $self->{TESTS}                       = $state->{tests};
    $self->{LOCAL_ADDRS}                 = $state->{local_addrs};
    $self->{LOCAL_PORT_RANGES}           = $state->{local_port_ranges};
    $self->{PERFSONARBUOY_CONF_TEMPLATE} = $state->{perfsonarbuoy_conf_template};
    $self->{PERFSONARBUOY_CONF_FILE}     = $state->{perfsonarbuoy_conf_file};
    $self->{PINGER_LANDMARKS_CONF_FILE}  = $state->{pinger_landmarks_file};
    $self->{OWMESH_PARAMETERS}           = $state->{owmesh_parameters};

    return;
}

=head2 parse_pinger_landmarks_file ({ file => 1 })
    Reads in the PingER landmarks file, converts it into a normalized form and
    loads it into this object's configuration.  Returns (0, "") on success and
    (-1, $error_msg) on failure.
    
    In the PingER model, every address is a separate test. To get the model
    into this module's test model , the module makes use of the fact that
    PingER's config file expects domain, node and port elements, but doesn't
    actually use that information.  Each test is modelled as a domain with a
    random identifier associated with it.  There's a node element
    "profile_node" which contains the test profile (description, packet size,
    etc). It has no port, so PingER ignores it. The rest of the members are
    added as 'node' elements like normal. The parameters for them, when parsed
    by this module, will be replaced with the "profile_node" parameters. For an
    existing PingER configuration, the various elements will be merged into new
    tests. A new test is added for each unique set of test properties (i.e. all
    PingER test members with the same parameters will end up in the same new
    test).
=cut

sub parse_pinger_landmarks_file {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { file => 1, } );

    my $file = $parameters->{file};

    return ( 0, "" ) unless ( -e $parameters->{file} );

    eval {
        local ( $/, *FH );
        open( FH, $file ) or die " Failed to open landmarks $file";
        my $text = <FH>;
        my $topology = Topology->new( { xml => $text } );
        close FH;

        my %new_domains = ();

        if ( $topology->get_domain ) {
            # Handle the backward compatibility case where someone has simply
            # selected a group of hosts to monitor using the previous pinger
            # web admin gui, and didn't change any of the settings.

            foreach my $domain ( @{ $topology->get_domain } ) {

                # Skip if it's one of ours
                next if ( $domain->get_id =~ /domain=(group.)?test.[0-9]+$/ );

                $self->{LOGGER}->debug( "Handling domain: " . $domain->get_id );

                next unless ($domain->get_node);

                foreach my $node ( @{ $domain->get_node } ) {

                    next unless ( $node->get_port and $node->get_parameters );

                    $self->{LOGGER}->debug( "Handling node: " . $node->get_id );

                    my $test_params = $node->get_parameters();

                    # We try to merge all the existing tests into a single
                    # one. This will likely work for all PingER installs.

                    my %parameters = ();
                    foreach my $param ( @{ $test_params->get_parameter } ) {
                        $parameters{ $param->get_name } = $param->get_text;
                    }

                    my $key = "";
                    foreach my $parameter ( sort keys %parameters ) {
                        my $value = $parameters{$parameter};
                        $value = "" unless ( $value );

                        $key .= $parameter . "|" . $value;
                    }

                    unless ( $new_domains{$key} ) {

                        # The domain isn't actually used, so we overload it to differentiate test
                        # groups from individual tests.
                        my $urn;
                        my $domain_obj;

                        $self->{LOGGER}->debug( "Finding new domain id" );

                        # Find an empty domain
                        do {
                            $urn        = "urn:ogf:network:domain=test." . genuid();
                            $domain_obj = $topology->getDomainById( $urn );
                        } while ( $domain_obj );

                        # Add the new group
                        $self->{LOGGER}->debug( "Creating new domain" );
                        $topology->addDomain( Domain->new( { id => $urn } ) );
                        $domain_obj = $topology->getDomainById( $urn );

                        $new_domains{$key} = $domain_obj;

                        # Since we start with "empty" tests. we define a junk node to hold our
                        # test's properties (test parameters/description).

                        eval {

                            # Create a new profile node
                            my $profile_urn  = $urn . ":node=profile_node";
                            my $profile_node = Node->new(
                                {
                                    id          => $profile_urn,
                                    description => Description->new( { text => "PingER Test" } ),
                                    parameters  => Parameters->new( { xml => $node->get_parameters->asString } ),
                                }
                            );

                            $domain_obj->addNode( $profile_node );
                        };
                        if ( $@ ) {
                            die( "Failed to add test: $@" );
                        }

                        $self->{LOGGER}->debug( "Finished creating domain" );
                    }

                    my $new_domain = $new_domains{$key};

                    eval {
                        $self->{LOGGER}->debug( "Adding new node " . $node->get_id . " to domain: " . $new_domain->get_id );

                        my $node_urn;
                        do {
                            $node_urn = $domain->get_id . ":node=" . genuid();
                        } while ( $domain->getNodeById( $node_urn ) );

                        my $port_urn = $node_urn . ":port=" . genuid();
                        my $real_node = Node->new( { xml => $node->asString } );

                        # Duplicate the information into the new domain
                        $real_node->set_id( $node_urn );
                        $real_node->set_description( $node->get_description );
                        $real_node->get_port->set_id( $port_urn );
                        $real_node->set_parameters( Parameters->new( { xml => $node->get_parameters->asString } ) );

                        $new_domain->addNode( $real_node );
                    };
                    if ( $@ ) {
                        die( "Failed to add test: $@" );
                    }
                }

                $self->{LOGGER}->debug( "Removing domain: " . $domain->get_id );

                # Get rid of the old version
                $topology->removeDomainById( $domain->get_id );
            }

            # Now, all the domains available should be one of our "test"
            # domains.

            foreach my $domain ( @{ $topology->get_domain } ) {
                my $test_id;

                my @members = ();

                if ( $domain->get_node ) {
                    my $test_description;

                    # maxim forced me to write an address, so now we have two
                    # separate ways that the test parameters might be defined.
                    # If there is no profile node, then the comments in the
                    # Domain field have the description. So search for both.

                    my $profile_node = $domain->getNodeById( $domain->get_id . ":node=profile_node" );
                    if ($profile_node) {
                        $test_description = $profile_node->get_description->get_text;
                    }
                    else {
                        my $domain_comments = $domain->get_comments;
                        if ($domain_comments) {
                            $test_description = $domain_comments->get_text;
                        }
                        else {
                            $test_description = "PingER test";
                        }
                    }

                    foreach my $node ( @{ $domain->get_node } ) {
                        unless ($test_id) {
                            my $packet_size;
                            my $packet_count;
                            my $packet_interval;
                            my $test_interval;
                            my $test_offset;
                            my $ttl;
        
                            my $test_params = $node->get_parameters;

                            foreach my $param ( @{ $test_params->get_parameter } ) {
                                my $param_name;
                                if ( $param->get_name eq "packetSize" ) {
                                    $packet_size = $param->get_text;
                                }
                                elsif ( $param->get_name eq "count" ) {
                                    $packet_count = $param->get_text;
                                }
                                elsif ( $param->get_name eq "packetInterval" ) {
                                    $packet_interval = $param->get_text;
                                }
                                elsif ( $param->get_name eq "measurementPeriod" ) {
                                    $test_interval = $param->get_text;
                                }
                                elsif ( $param->get_name eq "measurementOffset" ) {
                                    $test_offset = $param->get_text;
                                }
                                elsif ( $param->get_name eq "ttl" ) {
                                    $ttl = $param->get_text;
                                }
                            }

                            my ( $status, $res ) = $self->add_test_pinger(
                                {
                                    description     => $test_description,
                                    packet_size     => $packet_size,
                                    packet_count    => $packet_count,
                                    packet_interval => $packet_interval,
                                    test_interval   => $test_interval,
                                    test_offset     => $test_offset,
                                    ttl             => $ttl,
                                }
                            );

                            die( "Couldn't create PingER test: $res" ) unless ( $status == 0 );

                            $test_id = $res;
                        }

                        next if ( $node->get_id =~ /profile_node/ );

                        my $port = $node->get_port;

                        next unless ( $port );

                        my $description = "";

                        $description = $node->get_description->get_text if ( $node->get_description );
                        $description = $node->get_hostName->get_text if ( $node->get_hostName and not $description );

                        my $name = "";
                        $name = $node->get_hostName->get_text if ( $node->get_hostName and $node->get_hostName->get_text );
                        $self->{LOGGER}->debug( "Parsed Name: $name" );
                        unless ($name) {
                            # The node may have already been added to the node table with the ip address as the hostname
                            $name = $node->get_port->get_ipAddress->get_text;
                            $self->{LOGGER}->debug( "Parsed Name2: $name" );
                        }

                        $self->{LOGGER}->debug( "Member: " . $node->asString );
                        $self->{LOGGER}->debug( "Parsed: $description/$name" );

                        my ( $status, $res ) = $self->add_test_member( { test_id => $test_id, name => $name, description => $description, address => $node->get_port->get_ipAddress->get_text, receiver => 1, sender => 1 } );

                        die( "Couldn't add host to PingER test: $res" ) unless ( $status == 0 );
                    }
                }
            }
        }
    };
    if ( $@ ) {
        return ( -1, "Failed to load landmarks file: $@ " );
    }

    return ( 0, "" );
}

=head2 generate_pinger_landmarks_file 
    Generates a string representation of the PingER landmarks file based on the
    passed-in tests. Each test is converted into a domain, containing a node
    "profile_node" that has the test parameters. Each test member is then added
    to the domain.
=cut

sub generate_pinger_landmarks_file {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { tests => 1, } );

    my $content;

    eval {
        my $topology = Topology->new();
        foreach my $test ( @{ $parameters->{tests} } ) {
            $self->{LOGGER}->debug( "Handling: " . $test->{id} );
            my $domain_urn = "urn:ogf:network:domain=" . $test->{id};

            # Add a junk domain defining our test
            $topology->addDomain( Domain->new( { id => $domain_urn } ) );
            my $domain_obj = $topology->getDomainById( $domain_urn );

            $domain_obj->set_comments(Comments->new({ text => $test->{description} }));
            # Since we may have an empty test. we define a junk node to hold
            # our test's properties (test parameters/description).

            my $node_urn = $domain_urn . ":node=profile_node";

            $self->{LOGGER}->debug( "Node urn: " . $node_urn );

            my $packet_size     = $test->{parameters}->{packet_size};
            my $packet_count    = $test->{parameters}->{packet_count};
            my $packet_interval = $test->{parameters}->{packet_interval};
            my $ttl             = $test->{parameters}->{ttl};
            my $test_interval   = $test->{parameters}->{test_interval};
            my $test_offset     = $test->{parameters}->{test_offset};

            $packet_size     = 1000 unless ( defined $packet_size );
            $packet_count    = 10   unless ( defined $packet_count );
            $packet_interval = 1    unless ( defined $packet_interval );
            $ttl             = 255  unless ( defined $ttl );
            $test_interval   = 3600 unless ( defined $test_interval );
            $test_offset     = 0    unless ( defined $test_offset );

            my $profile_node = Node->new(
                {
                    id          => $node_urn,
                    description => Description->new( { text => $test->{description} } ),
                    name        => HostName->new( { text => "localhost" } ),
                    port        => Port->new(
                        {
                            xml => "<nmtl3:port xmlns:nmtl3=\"http://ogf.org/schema/network/topology/l3/20070707/\" id=\"$node_urn:port=127.0.0.1\">
                        <nmtl3:ipAddress type=\"IPv4\">127.0.0.1</nmtl3:ipAddress>
                        </nmtl3:port>"
                        },
                    ),
                    parameters  => Parameters->new(
                        {
                            xml => '<nmwg:parameters xmlns:nmwg="http://ggf.org/ns/nmwg/base/2.0/" id="paramid1">
                        <nmwg:parameter name="packetSize">' . $packet_size . '</nmwg:parameter>
                        <nmwg:parameter name="count">' . $packet_count . '</nmwg:parameter>
                        <nmwg:parameter name="packetInterval">' . $packet_interval . '</nmwg:parameter>
                        <nmwg:parameter name="ttl">' . $ttl . '</nmwg:parameter> 
                        <nmwg:parameter name="measurementPeriod">' . $test_interval . '</nmwg:parameter>  
                        <nmwg:parameter name="measurementOffset">' . $test_offset . '</nmwg:parameter> 
                        </nmwg:parameters>'
                        }
                    ),
                },
            );

            if (scalar keys %{ $test->{members} } == 0) {
                $domain_obj->addNode( $profile_node );
            }

            my %used_urns = ();

            foreach my $member_id ( keys %{ $test->{members} } ) {
                my $member = $test->{members}->{$member_id};

                my $ip_type;

                if ( is_ipv4( $member->{address} ) ) {
                    $ip_type = "IPv4";
                }
                elsif ( &Net::IP::ip_is_ipv6( $member->{address} ) ) {
                    $ip_type = "IPv6";
                }

                my $new_urn;
                do {
                    $new_urn = $domain_urn . ":node=" . genuid();
                } while ( $used_urns{$new_urn} );

                my $node_obj = Node->new(
                    {
                        id          => $new_urn,
                        description => Description->new( { text => $member->{description} } ),
                        name        => HostName->new( { text => $member->{name} } ),
                        port        => Port->new(
                            {
                                xml => "<nmtl3:port xmlns:nmtl3=\"http://ogf.org/schema/network/topology/l3/20070707/\" id=\"$new_urn:port=$member->{address}\">
                            <nmtl3:ipAddress type=\"$ip_type\">$member->{address}</nmtl3:ipAddress>
                            </nmtl3:port>"
                            }
                        ),
                        parameters => Parameters->new( { xml => $profile_node->get_parameters->asString } ),
                    }
                );

                $self->{LOGGER}->debug( "Adding new node: " . $node_obj->asString );
                $domain_obj->addNode( $node_obj );
            }
        }

        $content = $topology->asString;
    };
    if ( $@ ) {
        return ( -1, "Failed to create landmarks file: $@" );
    }

    return ( 0, $content );
}

=head2 parse_owmesh_conf
    Parses the specified owmesh file, and loads the tests into the object's
    configuration.

    In the perfSONAR-BUOY model, the source address must be specified in the
    configuration file and must be either IPv4 or IPv6. This is the reasoning
    behind the "center" having "ipv4_address" and "ipv6_address" options in
    tests.  When written out, each test is written as a new
    group/testspec/measurement set, and each test member is written out as a
    new node. The only exception to this is the center, local, node which is
    written out as a single node no matter how many test groups there are. To
    handle the case where a single test contains both ipv4 and ipv6 addresses,
    two tests will be written out, one for the ipv4 test and one for the ipv6
    test. These tests must be merged when read back in.
=cut

sub parse_owmesh_conf {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { file => 1, } );

    return ( 0, "" ) unless ( -e $parameters->{file} );

    my @known_prefixes = ( "OWP", "BW", "TRACE" );

    my @known_parameters = (
                        "SessionSuffix",
                        "SummarySuffix",
                        "Cmd",
                        "SessionSumCmd",
                        "DevNull",
                        "ConfigVersion",
                        "SecretNames",   # XXX Special case...
                        "SecretName",
                        "Debug",
                        "Verbose",
                        "SyslogFacility",
                        "BinDir",
                        "DataDir",
                        "OwampdVarDir",
                        "UserName",
                        "GroupName",
                        "VerifyPeerAddr",
                        "CentralHost",
                        "CentralHostTimeout",
                        "CentralDataDir",
                        "CentralArchDir",
                        "CentralDBHost",
                        "CentralDBType",
                        "CentralDBUser",
                        "CentralDBPass",
                        "CentralDBName",
                        "CGIDBUser",
                        "CGIDBPass",
                        "SendTimeout",
                );

    eval {
        $self->{LOGGER}->debug( "Parsing: " . $parameters->{file} );

        # We can't specify the file directly with pSB currently.
        my $confdir = dirname( $parameters->{file} );

        my $conf = OWP::Conf->new( CONFDIR => $confdir );

        my %owmesh_config_opts = ();

        foreach my $parameter (@known_parameters) {
            my $value;
            eval {
                 # use must_get_val so we get whether or not they've been set. If not, it will 'die'.
                 $value = $conf->must_get_val( ATTR => $parameter );
            };

            next if ($@);

            # Things like !Debug default to undefined so we can just leave them
            # out.
            $owmesh_config_opts{$parameter} = $value if (defined $value);

            # The SecretName parameters are special because they tell us other
            # parameters that might exist.
            if ($parameter eq "SecretName") {
                push @known_parameters, $value if ($value);
            }
            elsif ($parameter eq "SecretNames") {
                if ($value) {
                     my @names = split(" ", $value);
                     push @known_parameters, @names;
                }
            }
        }

        foreach my $prefix (@known_prefixes) {
            foreach my $parameter (@known_parameters) {
                my $value;
                eval {
                     # use must_get_val so we get whether or not they've been set. If not, it will 'die'.
                     $value = $conf->must_get_val( ATTR => $parameter, TYPE => $prefix );
                };

                next if ($@);

                next unless (defined $value);

                

                next if (defined $owmesh_config_opts{$parameter} and $owmesh_config_opts{$parameter} eq $value);

                $owmesh_config_opts{$prefix.$parameter} = $value;
            }
        }

        $self->{OWMESH_PARAMETERS} = \%owmesh_config_opts;

        my @measurement_sets = $conf->get_sublist( LIST => 'MEASUREMENTSET' );

        my @localnodes = $conf->get_val( ATTR => 'LOCALNODES' );

        unless ( scalar( @localnodes ) > 0 ) {
            my $me = $conf->get_val( ATTR => 'NODE' );
            @localnodes = ( $me ) if ($me);
        }

        # nothing local...
        unless ( scalar( @localnodes ) > 0 ) {
            @localnodes = ();
        }

        my %localnodes = ();
        foreach my $node ( @localnodes ) {
            $localnodes{$node} = 1;
        }

        # For star configurations, we allow ipv4 and ipv6 sites to co-exist in
        # a single schedule-able test. Since that doesn't work with the owmesh
        # file format, we may name measurement sets something like "[id].IPV4"
        # and "[id].IPV6". When we see those names come up, we add them to the
        # test mapping so that we don't add multiple tests for that case.
        my %test_mapping = ();

        foreach my $measurement_set ( @measurement_sets ) {
            my $group_name = $conf->must_get_val( MEASUREMENTSET => $measurement_set, ATTR => 'GROUP' );
            my $test       = $conf->must_get_val( MEASUREMENTSET => $measurement_set, ATTR => 'TESTSPEC' );
            my $addr_type  = $conf->must_get_val( MEASUREMENTSET => $measurement_set, ATTR => 'ADDRTYPE' );

            my $test_id;
            my $test_name;

            $self->{LOGGER}->debug( "Measuremnet Set Name: $measurement_set" );

            # Handle the test
            if ( $measurement_set =~ /(.*).IPV[46]/ ) {
                $self->{LOGGER}->debug( "Checking if test $1 has previous mapping: " . Dumper(\%test_mapping) );
                $test_id   = $test_mapping{$1};
                $test_name = $1;
            }
            else {
                $test_name = $measurement_set;
            }

            $self->{LOGGER}->debug("Read in tests name: ".$test_name);

            unless ( $test_id ) {
                my $tool = $conf->must_get_val( TESTSPEC => $test, ATTR => 'TOOL' );
                if ( $tool eq "powstream" ) {
                    my $packet_interval           = $conf->must_get_val( TESTSPEC => $test, ATTR => 'OWPINTERVAL' );
                    my $loss_threshold            = $conf->must_get_val( TESTSPEC => $test, ATTR => 'OWPLOSSTHRESH' );
                    my $session_count             = $conf->must_get_val( TESTSPEC => $test, ATTR => 'OWPSESSIONCOUNT' );
                    my $sample_count              = $conf->must_get_val( TESTSPEC => $test, ATTR => 'OWPSAMPLECOUNT' );
                    my $packet_padding            = $conf->get_val( TESTSPEC => $test, ATTR => 'OWPPACKETPADDING' );
                    my $bucket_width              = $conf->must_get_val( TESTSPEC => $test, ATTR => 'OWPBUCKETWIDTH' );

                    my $description = $conf->get_val( TESTSPEC => $test, ATTR => 'DESCRIPTION' );
                    $description = $group_name unless ( $description );

                    my ( $status, $res ) = $self->add_test_owamp(
                        {
                            description               => $description,
                            mesh_type                 => "star",
                            name                      => $test_name,
                            packet_interval           => $packet_interval,
                            loss_threshold            => $loss_threshold,
                            session_count             => $session_count,
                            sample_count              => $sample_count,
                            packet_padding            => $packet_padding,
                            bucket_width              => $bucket_width,
                        }
                    );

                    die( "Couldn't add new test: $res" ) unless ( $status == 0 );

                    $test_id = $res;
                }elsif ( $tool eq "traceroute" ) {
                    my $test_interval = $conf->must_get_val( TESTSPEC => $test, ATTR => 'TRACETESTINTERVAL' );
                    my $packet_size = $conf->get_val( TESTSPEC => $test, ATTR => 'TRACEPACKETSIZE' );
                    my $timeout     = $conf->get_val( TESTSPEC => $test, ATTR => 'TRACETIMEOUT' );
                    my $waittime    = $conf->get_val( TESTSPEC => $test, ATTR => 'TRACEWAITTIME' );
                    my $first_ttl   = $conf->get_val( TESTSPEC => $test, ATTR => 'TRACEFIRSTTTL' );
                    my $max_ttl     = $conf->get_val( TESTSPEC => $test, ATTR => 'TRACEMAXTTL' );
                    my $pause       = $conf->get_val( TESTSPEC => $test, ATTR => 'TRACEPAUSE' );
                    my $icmp        = $conf->get_val( TESTSPEC => $test, ATTR => 'TRACEICMP' );
                    my $description = $conf->get_val( TESTSPEC => $test, ATTR => 'DESCRIPTION' );
                    $description = $group_name unless ( $description );

                    my ( $status, $res ) = $self->add_test_traceroute(
                        {
                            description   => $description,
                            mesh_type     => "star",
                            name          => $test_name,
                            test_interval => $test_interval,
                            packet_size   => $packet_size,
                            timeout       => $timeout,
                            waittime      => $waittime,
                            first_ttl     => $first_ttl,
                            max_ttl       => $max_ttl,
                            pause         => $pause,
                            protocol      => ($icmp ? 'icmp' : 'udp')
                        }
                    );

                    die( "Couldn't add new test: $res" ) unless ( $status == 0 );

                    $test_id = $res;
                }
                elsif ( $tool =~ /bwctl\/(thrulay|nuttcp|iperf)/ ) {
                    my $protocol;
                    if ( $conf->get_val( TESTSPEC => $test, ATTR => 'BWTCP' ) ) {
                        $protocol = "tcp";
                    }
                    elsif ( $conf->get_val( TESTSPEC => $test, ATTR => 'BWUDP' ) ) {
                        $protocol = "udp";
                    }
                    else {
                        die( "No protocol specified" );
                    }

                    my $test_interval             = $conf->must_get_val( TESTSPEC => $test, ATTR => 'BWTestInterval' );
                    my $duration                  = $conf->must_get_val( TESTSPEC => $test, ATTR => 'BWTestDuration' );
                    my $window_size               = $conf->get_val( TESTSPEC      => $test, ATTR => 'BWWindowSize' );
                    my $report_interval           = $conf->get_val( TESTSPEC      => $test, ATTR => 'BWReportInterval' );
                    my $udp_bandwidth             = $conf->get_val( TESTSPEC      => $test, ATTR => 'BWUDPBandwidthLimit' );
                    my $buffer_length             = $conf->get_val( TESTSPEC      => $test, ATTR => 'BWBufferLen' );
                    my $test_interval_start_alpha = $conf->get_val( TESTSPEC      => $test, ATTR => 'BWTestIntervalStartAlpha' );

                    my $description = $conf->get_val( TESTSPEC => $test, ATTR => 'DESCRIPTION' );
                    $description = $group_name unless ( $description );

                    # Convert window size to megabytes and UDP bandwidth to Mbps
                    if ( defined $window_size ) {
                        if ( $window_size =~ /^(\d+)[gG]$/ ) {
                            $window_size = ( $1 * 1024 );
                        }
                        elsif ( $window_size =~ /^(\d+)$/ ) {
                            $window_size = ( $1 / 1024 );
                        }
                        elsif ( $window_size =~ /^(\d+)[mM]$/ ) {
                            $window_size = $1;
                        }
                        else {
                            die( "Invalid window size: $window_size" );
                        }
                    }

                    if ( defined $udp_bandwidth ) {
                        if ( $udp_bandwidth =~ /^(\d+)[gG]$/ ) {
                            $udp_bandwidth = ( $1 * 1000 );
                        }
                        elsif ( $udp_bandwidth =~ /^(\d+)$/ ) {
                            $udp_bandwidth = ( $1 / 1000 );
                        }
                        elsif ( $udp_bandwidth =~ /^(\d+)m$/ ) {
                            $udp_bandwidth = $1;
                        }
                        else {
                            die( "Invalid udp bandwidth: $udp_bandwidth" );
                        }
                    }

                    my ( $status, $res ) = $self->add_test_bwctl_throughput(
                        {
                            description               => $description,
                            mesh_type                 => "star",
                            tool                      => $1,
                            name                      => $test_name,
                            protocol                  => $protocol,
                            test_interval             => $test_interval,
                            duration                  => $duration,
                            window_size               => $window_size,
                            report_interval           => $report_interval,
                            udp_bandwidth             => $udp_bandwidth,
                            buffer_length             => $buffer_length,
                            test_interval_start_alpha => $test_interval_start_alpha,
                        }
                    );

                    die( "Couldn't add new test: $res" ) unless ( $status == 0 );

                    $test_id = $res;
                }
                else {
                    die( "Unknown tool" );
                }

                # Save the unique id so we can correlate the other ipv*
                # measurement set with this one.
                if ( $measurement_set =~ /(.*)\.IPV[46]/ ) {
                    $test_mapping{$1} = $test_id;
                }
            }

            # Handle the group
            my $group_type = $conf->must_get_val( GROUP => $group_name, ATTR => 'GROUPTYPE' );

            if ( $group_type ne "STAR" ) {
                die( "Can only handle 'star' groups currently" );
            }

            my @node_sets = ();

            my @nodes = $conf->get_val( GROUP => $group_name, ATTR => 'NODES' );
            push @node_sets, { type => "include", nodes => \@nodes, sender => 1, receiver => 1 };
            my @include_receivers = $conf->get_val( GROUP => $group_name, ATTR => 'INCLUDE_RECEIVERS' );
            push @node_sets, { type => "include", nodes => \@include_receivers, sender => 0, receiver => 1 };
            my @exclude_receivers = $conf->get_val( GROUP => $group_name, ATTR => 'EXCLUDE_RECEIVERS' );
            push @node_sets, { type => "exclude", nodes => \@exclude_receivers, receiver => 0 };
            my @include_senders = $conf->get_val( GROUP => $group_name, ATTR => 'INCLUDE_SENDERS' );
            push @node_sets, { type => "include", nodes => \@include_senders, sender => 1, receiver => 0 };
            my @exclude_senders = $conf->get_val( GROUP => $group_name, ATTR => 'EXCLUDE_SENDERS' );
            push @node_sets, { type => "exclude", nodes => \@exclude_senders, sender => 0 };

            my %senders   = ();
            my %receivers = ();

            my %member_ids = ();

            foreach my $node_set ( @node_sets ) {
                foreach my $node ( @{ $node_set->{nodes} } ) {
                    my $node_addr = $conf->get_val( NODE => $node, TYPE => $addr_type, ATTR => 'ADDR' );
                    next unless ( $node_addr );

                    my $node_desc = $conf->get_val( NODE => $node, TYPE => $addr_type, ATTR => 'LONGNAME' );
                    $node_desc = $node unless ( $node_desc );

                    my $node_owp_test_ports = $conf->get_val( NODE => $node, ATTR => "OWPTESTPORTS" );

                    $self->{LOGGER}->debug( "Parsing: $node -> $node_addr" );
                    my ( $addr, $port );
                    if ( $node_addr =~ /^[(.*)]:(\d+)$/ ) {
                        $addr = $1;
                        $port = $2;
                    }
                    elsif ( $node_addr =~ /^[(.*)]$/ ) {
                        $addr = $1;
                    }
                    elsif ( $node_addr =~ /^(.*):(\d+)$/ ) {
                        $addr = $1;
                        $port = $2;
                    }
                    else {
                        $addr = $node_addr;
                    }
                    $self->{LOGGER}->debug( "Result: $addr" );

                    if ( $localnodes{$node} ) {
                        if ($node_owp_test_ports) {
                            my ($min_port, $max_port) = split('-', $node_owp_test_ports);

                            $self->set_local_port_range({ test_type => "owamp", min_port => $min_port, max_port => $max_port });
                        }

                        $self->add_local_address( { address => $addr } );
                    }

                    if ( $node_set->{type} eq "include" ) {
                        my ($status, $res) = $self->add_test_member( { test_id => $test_id, name => $node, description => $node_desc, address => $addr, port => $port, receiver => $node_set->{receiver}, sender => $node_set->{sender} } );
                        if ($status == 0) {
                            $member_ids{$addr} = $res;
                        }
                    }
                    else {
                        $self->update_test_member( { test_id => $test_id, name => $node, description => $node_desc, address => $addr, port => $port, receiver => $node_set->{receiver}, sender => $node_set->{sender} } );
                    }
                }
            }

            # Set the center after we've added everything.

            # We should really scan the address to see if it's ipv4 or ipv6.
            my $ip_type = "ipv4";
            if ( $measurement_set =~ /\.IPV6/ ) {
                $ip_type = "ipv6";
            }

            if ( $group_type eq "STAR" ) {
                my $center = $conf->must_get_val( GROUP => $group_name, ATTR => 'HAUPTNODE' );
                my $node_addr = $conf->get_val( NODE => $center, TYPE => $addr_type, ATTR => 'ADDR' );

                die( "Couldn't find address for center node" ) unless ( $node_addr );

                if ( $ip_type eq "ipv4" ) {
                    $self->set_test_center( { test_id => $test_id, ipv4_address => $node_addr } );
                }
                else {
                    $self->set_test_center( { test_id => $test_id, ipv6_address => $node_addr } );
                }

                if ($member_ids{$node_addr}) {
                    $self->remove_test_member({ test_id => $test_id, member_id => $member_ids{$node_addr} });
                }
            }

            $self->{LOGGER}->debug( "Test id: " . $test_id );
        }
    };
    if ( $@ ) {
        return ( -1, $@ );
    }

    return ( 0, "" );
}

=head2 generate_owmesh_conf({ tests => 1 })
    Generates a string representation of the perfSONAR-BUOY configuration file
    based on the passed-in tests. A template is used to ensure that much of the
    boiler plate stays the same. This function converts the test
    representations into the representation expected by the template, and
    passes it to Template Toolkit to render.
=cut

sub generate_owmesh_conf {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { tests => 1, owmesh_parameters => 1 } );

    my $tests             = $parameters->{tests};
    my $owmesh_parameters = $parameters->{owmesh_parameters};

    # Convert the internal representation into owmesh concepts.

    my @measurement_sets = ();
    my @groups           = ();
    my @test_specs       = ();
    my @addr_types       = ( "BW4", "BW6", "LAT4", "LAT6", "TRACE4", "TRACE6");
    my %nodes            = ();
    my @localnodes       = ();
    my %local_node       = ();

    my %used_nodenames = ();
    my %node_names_by_addrdesc = ();

    foreach my $test ( @{$tests} ) {
        foreach my $member_id ( keys %{ $test->{members} } ) {
            my $member = $test->{members}->{$member_id};

            my $key = "";
            $key .= $member->{address} if ($member->{address});
            $key .= "|";
            $key .= $member->{description} if ($member->{description});

            $used_nodenames{$member->{name}} = 1 if ($member->{name});
            $node_names_by_addrdesc{$key} = $member->{name};
        }
    }

    $local_node{id}          = "KNOPPIX";      # Backward compatibility....
    $local_node{description} = "local host";
    $local_node{addresses}   = ();

    use Data::Dumper;

    $self->{LOGGER}->info("Port ranges: ".Dumper($self->{LOCAL_PORT_RANGES}));

    if ($self->{LOCAL_PORT_RANGES}->{owamp}) {
        $self->{LOGGER}->info("Saving owamp port range");
        $local_node{owamp_port_range} = $self->{LOCAL_PORT_RANGES}->{owamp}->{min_port}."-".$self->{LOCAL_PORT_RANGES}->{owamp}->{max_port}
    }

    $nodes{$local_node{id}} = \%local_node;
    push @localnodes, $local_node{id};

    foreach my $test ( @{$tests} ) {
        my $test_name;
        if ( $test->{name} ) {
            $test_name = $test->{name};
            $self->{LOGGER}->debug("Test is named: ".$test_name);
        }
        else {
            $test_name = genuid();
            $test->{name} = $test_name;     # need to store the name in case users create a test, and use the same session to create another.
            $self->{LOGGER}->debug("Test is generated: ".$test_name);
        }

        unless ($test->{center}->{ipv4_address} or $test->{center}->{ipv6_address}) {
            # Set the default addresses if there is no test center
            my $external_address_config = perfSONAR_PS::NPToolkit::Config::ExternalAddress->new();
            if ( $external_address_config->init() == 0 ) {
                $test->{center}->{ipv4_address} = $external_address_config->get_primary_ipv4();
                $test->{center}->{ipv6_address} = $external_address_config->get_primary_ipv6();
            }
        }

        return ( -1, "No known external ipv4 or ipv6 addresses" ) unless ( $test->{center}->{ipv4_address} or $test->{center}->{ipv6_address} );
        
        my %duplicate_test_map = ();
        foreach my $ip_type ( "IPV6", "IPV4" ) {
            my %measurement_set = ();
            my %group           = ();
            my %test_spec       = ();
            my %group_nodes     = ();

            next if ( $ip_type eq "IPV4" and not $test->{center}->{ipv4_address} );
            next if ( $ip_type eq "IPV6" and not $test->{center}->{ipv6_address} );

            # At minimum, test_spec has to be upper-case
            $group{id}              = $test_name . "." . $ip_type;
            $measurement_set{id}    = $test_name . "." . $ip_type;
            $test_spec{id}          = $test_name . "." . $ip_type;
            $test_spec{description} = $test->{description};

            $self->{LOGGER}->debug( "Doing " . Dumper( $test ) );

            if ( $test->{type} eq "bwctl/throughput" ) {
                $test_spec{type}                      = "bwctl/throughput";
                $test_spec{tool}                      = "bwctl/".$test->{parameters}->{tool};
                $test_spec{protocol}                  = $test->{parameters}->{protocol};
                $test_spec{test_interval}             = $test->{parameters}->{test_interval};
                $test_spec{test_duration}             = $test->{parameters}->{duration};
                $test_spec{window_size}               = $test->{parameters}->{window_size} . "m" if ( $test->{parameters}->{window_size} );                    # Add the 'm' on since it's in Megabytes
                $test_spec{report_interval}           = $test->{parameters}->{report_interval};
                $test_spec{udp_bandwidth}             = $test->{parameters}->{udp_bandwidth} . "m" if ( $test->{parameters}->{udp_bandwidth} );    # Add the 'm' on since it's in Mbps
                $test_spec{buffer_len}                = $test->{parameters}->{buffer_length};
                $test_spec{test_interval_start_alpha} = $test->{parameters}->{test_interval_start_alpha};
                $measurement_set{exclude_self} = 1;
            } elsif ($test->{type} eq "owamp") {
                $test_spec{type}                      = "owamp";
                $test_spec{tool}                      = "powstream";
                $test_spec{packet_interval}  = $test->{parameters}->{packet_interval}  if ( defined $test->{parameters}->{packet_interval} );
                $test_spec{loss_threshold}   = $test->{parameters}->{loss_threshold}   if ( defined $test->{parameters}->{loss_threshold} );
                $test_spec{session_count}    = $test->{parameters}->{session_count}    if ( defined $test->{parameters}->{session_count} );
                $test_spec{sample_count}     = $test->{parameters}->{sample_count}     if ( defined $test->{parameters}->{sample_count} );
                $test_spec{packet_padding}   = $test->{parameters}->{packet_padding}   if ( defined $test->{parameters}->{packet_padding} );
                $test_spec{bucket_width}     = $test->{parameters}->{bucket_width}     if ( defined $test->{parameters}->{bucket_width} );
                $measurement_set{exclude_self} = 0;
            } elsif ($test->{type} eq "traceroute") {
                $test_spec{type}                      = "traceroute";
                $test_spec{tool}                      = "traceroute";
                $test_spec{test_interval}             = $test->{parameters}{test_interval}             if ( defined $test->{parameters}{test_interval} );
                $test_spec{packet_size}               = $test->{parameters}{packet_size}               if ( defined $test->{parameters}{packet_size} );
                $test_spec{timeout}                   = $test->{parameters}{timeout}                   if ( defined $test->{parameters}{timeout} );
                $test_spec{waittime}                  = $test->{parameters}{waittime}                  if ( defined $test->{parameters}{waittime} );
                $test_spec{first_ttl}                 = $test->{parameters}{first_ttl}                 if ( defined $test->{parameters}{first_ttl} );
                $test_spec{max_ttl}                   = $test->{parameters}{max_ttl}                   if ( defined $test->{parameters}{max_ttl} );
                $test_spec{pause}                     = $test->{parameters}{pause}                     if ( defined $test->{parameters}{pause} );
                $test_spec{protocol}                  = $test->{parameters}{protocol}                  if ( defined $test->{parameters}{protocol} );
    
                $measurement_set{exclude_self} = 0;
            }

            my $addr_type;
            if ($test->{type} eq "owamp") {
                if ($ip_type eq "IPV4") {
                    $addr_type = "LAT4";
                } else {
                    $addr_type = "LAT6";
                }
            } elsif ($test->{type} eq "bwctl/throughput") {
                if ($ip_type eq "IPV4") {
                    $addr_type = "BW4";
                } else {
                    $addr_type = "BW6";
                }
            } elsif ($test->{type} eq "traceroute") {
                if ($ip_type eq "IPV4") {
                    $addr_type = "TRACE4";
                } else {
                    $addr_type = "TRACE6";
                }
            }


            $measurement_set{description}  = $test->{description};
            $measurement_set{address_type} = $addr_type;
            $measurement_set{group}        = $group{id};
            $measurement_set{test_spec}    = $test_spec{id};
            
            $group{type}        = "STAR";
            $group{description} = $test->{group}->{description};

            $self->{LOGGER}->debug( "Outputing group: " . Dumper( $test->{group} ) );

            my %exclude_senders   = ();
            my %exclude_receivers = ();

            foreach my $member_id ( keys %{ $test->{members} } ) {
                my $member = $test->{members}->{$member_id};

                next if ( $ip_type eq "IPV4" and not $self->determine_ipv4( $member->{address}) );
                next if ( $ip_type eq "IPV6" and not $self->determine_ipv6( $member->{address}) );
                next if( $duplicate_test_map{$member_id} );
                $duplicate_test_map{$member_id} = 1;
                
                # The center gets output later
                next if ( $test->{center}->{ipv4_address} and $member->{address} eq $test->{center}->{ipv4_address} );
                next if ( $test->{center}->{ipv6_address} and $member->{address} eq $test->{center}->{ipv6_address} );

                my $new_node;
               
                unless ($new_node) {
                    if ( $member->{name} ) {
                        $new_node = $nodes{$member->{name}};
                    }
                }

                unless ($new_node) {
                    my $key = "";
                    $key .= $member->{address} if ($member->{address});
                    $key .= "|";
                    $key .= $member->{description} if ($member->{description});

                    $self->{LOGGER}->debug("Looking up key: $key");

                    my $node_name = $node_names_by_addrdesc{$key};

                    $new_node = $nodes{$node_name} if ($node_name);
                }

                unless ($new_node) {
                    my %tmp = ();
                    $new_node = \%tmp;

                    my $key = "";
                    $key .= $member->{address} if ($member->{address});
                    $key .= "|";
                    $key .= $member->{description} if ($member->{description});

                    if ($member->{name}) {
                        $new_node->{id} = $member->{name};
                    }
                    elsif ($node_names_by_addrdesc{$key}) {
                        $new_node->{id} = $node_names_by_addrdesc{$key};
                    }
                    else {

                        my $new_id = address_to_id( $member->{address} );
                        my $i = 0;
                        while ($used_nodenames{$new_id}) {
                            $new_id = address_to_id( $member->{address} );
                            $new_id .= "-".$i;
                            $i++;
                        }
                        $new_node->{id} = $new_id;
                        $used_nodenames{$new_id} = 1;
                    }
                }

                $new_node->{description} = $member->{description};

                unless ($new_node->{addresses}) {
                    my @addresses = ();
                    $new_node->{addresses} = \@addresses;
                }

                my $add = 1;
                foreach my $addr (@{ $new_node->{addresses} }) {
                    if ($addr->{address_type} eq $addr_type) {
                        $add = 0;
                        last;
                    }
                }

                if ($add) {
                    my %address = ( address => $member->{address}, address_type => $addr_type, port => $member->{port}, is_ipv6 => &Net::IP::ip_is_ipv6( $member->{address} ) );
                    push @{ $new_node->{addresses} }, \%address;
                    $new_node->{contact_address} = $member->{address};
                }

                $new_node->{noagent} = 1 unless ( $self->{LOCAL_ADDRS}->{ $member->{address} } );

                $group_nodes{ $new_node->{id} }       = 1;
                $exclude_senders{ $new_node->{id} }   = 1 unless ( $member->{sender} );
                $exclude_receivers{ $new_node->{id} } = 1 unless ( $member->{receiver} );

                if ( $self->{LOCAL_ADDRS}->{ $member->{address} } ) {
                    push @localnodes, $new_node->{id};
                }

                $nodes{$new_node->{id}} = $new_node;

                my $key = "";
                $key .= $member->{address} if ($member->{address});
                $key .= "|";
                $key .= $member->{description} if ($member->{description});
                $node_names_by_addrdesc{$key} = $new_node->{id};
                $self->{LOGGER}->debug("Saving node as key: $key");
            }
            # Center Address
            my $center_address = $test->{center}->{ipv4_address};
            $center_address = $test->{center}->{ipv6_address} if ( $ip_type eq "IPV6" );

            my $add = 1;
            foreach my $addr (@{ $local_node{addresses} }) {
                if ($addr->{address_type} eq $addr_type) {
                    $add = 0;
                    last;
                }
            }
 
            if ($add) {
                my %address = ( address => $center_address, address_type => $addr_type, is_ipv6 => &Net::IP::ip_is_ipv6( $center_address ) );
                push @{ $local_node{addresses} }, \%address;
                $local_node{contact_address} = $center_address;
            }

            $group_nodes{ $local_node{id} } = 1;

            my @group_nodes             = keys %group_nodes;
            my @group_exclude_senders   = keys %exclude_senders;
            my @group_exclude_receivers = keys %exclude_receivers;

            $group{center}            = $local_node{id};
            $group{nodes}             = \@group_nodes;
            $group{exclude_senders}   = \@group_exclude_senders;
            $group{exclude_receivers} = \@group_exclude_receivers;

            push @measurement_sets, \%measurement_set;
            push @groups,           \%group;
            push @test_specs,       \%test_spec;
        }
    }

    my @nodes = values %nodes;

    @groups           = sort { $a->{id} cmp $b->{id} } @groups;
    @test_specs       = sort { $a->{id} cmp $b->{id} } @test_specs;
    @measurement_sets = sort { $a->{id} cmp $b->{id} } @measurement_sets;
    @nodes            = sort { $a->{id} cmp $b->{id} } @nodes;

    my $template_directory = dirname( $self->{PERFSONARBUOY_CONF_TEMPLATE} );
    my $template_name      = basename( $self->{PERFSONARBUOY_CONF_TEMPLATE} );

    my $tt = Template->new( INCLUDE_PATH => $template_directory ) or die( "Couldn't initialize template toolkit" );

    my %vars = (
        address_types     => \@addr_types,
        measurement_sets  => \@measurement_sets,
        groups            => \@groups,
        test_specs        => \@test_specs,
        nodes             => \@nodes,
        localnodes        => \@localnodes,
        owmesh_parameters => $owmesh_parameters,
    );

    $self->{LOGGER}->debug( "Adding vars to $self->{PERFSONARBUOY_CONF_TEMPLATE}: " . Dumper( \%vars ) );

    my $output;

    $tt->process( $template_name, \%vars, \$output ) or die $tt->error();

    return (0, $output);
}

=head address_to_id ( $address, $address_type ) 
    Simple function to generate a unique node name for a given address. Only
    used if the node isn't already defined.
=cut

sub address_to_id {
    my ( $address ) = @_;

    my $retval = uc( $address );
    $retval =~ s/\./_/g;
    $retval =~ s/\:/_/g;
    $retval =~ s/\-/_/g;

    return $retval;
}

=head determine_ipv6 ( $address ) 
    Simple function to test if a host is an IPv6 address or has an AAAA record
=cut
sub determine_ipv6 {
    my ($self, $address) = @_;
    
    if( &Net::IP::ip_is_ipv6($address) ){
        return 1;
    }
    
    if( is_ipv4($address) ){
        return 0;
    }
    
    #lookup IPv6 address
    my $res = Net::DNS::Resolver->new;
    my $query = $res->search($address, "AAAA");
    if($query){
        foreach my $rr ($query->answer) {
            if($rr->type eq "AAAA"){
                my $ipv6addr = $rr->address;
                return 1 if($ipv6addr);
            }
        }
    }
    
    return 0;
}

=head determine_ipv4 ( $address ) 
    Simple function to test if a host is an IPv4 address or has an A record
=cut
sub determine_ipv4 {
    my ($self, $address) = @_;
    
    if( is_ipv4($address) ){
        return 1;
    }
    
    if( &Net::IP::ip_is_ipv6($address) ){
        return 0;
    }
    
    #lookup IPv6 address
    my $res = Net::DNS::Resolver->new;
    my $query = $res->search($address, "A");
    if($query){
        foreach my $rr ($query->answer) {
            if($rr->type eq "A"){
                my $ipv4addr = $rr->address;
                return 1 if($ipv4addr);
            }
        }
    }
    
    return 0;
}



1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 COPYRIGHT

Copyright (c) 2008-2010, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
