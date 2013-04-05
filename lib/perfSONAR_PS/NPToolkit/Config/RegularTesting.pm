package perfSONAR_PS::NPToolkit::Config::RegularTesting;

use strict;
use warnings;

our $VERSION = 3.3;

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

use fields 'LOCAL_ADDRS', 'LOCAL_PORT_RANGES', 'TESTS', 'PERFSONARBUOY_CONF_TEMPLATE', 'PERFSONARBUOY_CONF_FILE', 'PINGER_LANDMARKS_CONF_FILE', 'RAW_OWMESH_CONF', 'OPAQUE_PINGER_DOMAINS';

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

    $self->{LOGGER}->debug("Generating owmesh.conf");

    ($status, $res) = $self->generate_owmesh_conf( { tests => \@psb_tests, raw_owmesh_conf => $self->{RAW_OWMESH_CONF} } );
    if ( $status != 0 ) {
        $self->{LOGGER}->debug("Couldn't save perfSONAR-BUOY configuration: ".$res);
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
        }
        else {
            $status = stop_service( { name => "traceroute_scheduler" } );
            $status = stop_service( { name => "traceroute_ma" } );
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
        use Data::Dumper;
        $self->{LOGGER}->debug("lookup up test: ".$key.": ".Dumper($self->{TESTS}));
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
            added_by_mesh    => 0,
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
    $test{added_by_mesh} = $parameters->{added_by_mesh};

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
    return ( -1, "Test was added by the mesh configuration agent. It can't be updated.") if ($test->{added_by_mesh});

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

=head2 add_test_bwctl_throughput({ mesh_type => 1, name => 0, description => 1, tool => 1, test_interval => 1, duration => 1, protocol => 1, udp_bandwidth => 0, buffer_length => 0, window_size => 0, report_interval => 0, test_interval_start_alpha => 0, tos_bits => 0 })
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
            added_by_mesh             => 0,
            tos_bits                   => 0
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
    $test{added_by_mesh} = $parameters->{added_by_mesh};

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
    $test_parameters{tos_bits} 					= $parameters->{tos_bits} 				   if ( defined $parameters->{tos_bits} );

    $test{parameters} = \%test_parameters;

    my %tmp = ();
    $test{members} = \%tmp;

    $self->{TESTS}->{$test_id} = \%test;

    return ( 0, $test_id );
}

=head2 update_test_bwctl_throughput({ test_id => 1, name => 0, description => 0, tool => 0, test_interval => 0, duration => 0, protocol => 0, udp_bandwidth => 0, buffer_length => 0, window_size => 0, report_interval => 0, test_interval_start_alpha => 0, tos_bits =>0 })
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
            tos_bits       => 0
        }
    );

    $self->{LOGGER}->debug( "Updating bwctl test " . $parameters->{test_id} );

    my $test = $self->{TESTS}->{ $parameters->{test_id} };

    return ( -1, "Test does not exist" ) unless ( $test );
    return ( -1, "Test is not bwctl/throughput" ) unless ( $test->{type} eq "bwctl/throughput" );
    return ( -1, "Test was added by the mesh configuration agent. It can't be updated.") if ($test->{added_by_mesh});

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
    $test->{parameters}->{tos_bits} 				 = $parameters->{tos_bits} 					if ( exists $parameters->{tos_bits} );

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
            added_by_mesh   => 0,
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
        added_by_mesh => $parameters->{added_by_mesh},
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
    return ( -1, "Test was added by the mesh configuration agent. It can't be updated.") if ($test->{added_by_mesh});

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
            added_by_mesh => 0,
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
    $test{added_by_mesh} = $parameters->{added_by_mesh};

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
    return ( -1, "Test was added by the mesh configuration agent. It can't be updated.") if ($test->{added_by_mesh});

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

    my $test = $self->{TESTS}->{ $parameters->{test_id} };

    return ( -1, "Test was added by the mesh configuration agent. It can't be deleted") if ($test->{added_by_mesh});

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
            added_by_mesh => 0,
        }
    );

    $self->{LOGGER}->debug( "Adding address " . $parameters->{address} . " to test " . $parameters->{test_id} );

    my $test = $self->{TESTS}->{ $parameters->{test_id} };

    return ( -1, "Test does not exist" ) unless ( $test );

    return ( -1, "Test was added by the mesh configuration agent. It can't be updated.") if ($test->{added_by_mesh} and not $parameters->{added_by_mesh});

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

    my $member = $test->{members}->{ $parameters->{member_id} };

    return ( -1, "Test member does not exist" ) unless ( $member );

    return ( -1, "Test was added by the mesh configuration agent. It can't be updated.") if ($test->{added_by_mesh});

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

    return ( -1, "Test was added by the mesh configuration agent. It can't be updated.") if ($test->{added_by_mesh});

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

    return ( -1, "Test was added by the mesh configuration agent. It can't be updated.") if ($test->{added_by_mesh});

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

    my @opaque_domains = ();
    foreach my $domain (@{ $self->{OPAQUE_PINGER_DOMAINS} }) {
        $self->{LOGGER}->debug("Saving domain: ".$domain->asString);
        push @opaque_domains, $domain->asString;
    }

    my %state = (
        tests                       => $self->{TESTS},
        local_addrs                 => $self->{LOCAL_ADDRS},
        local_port_ranges           => $self->{LOCAL_PORT_RANGES},
        perfsonarbuoy_conf_template => $self->{PERFSONARBUOY_CONF_TEMPLATE},
        perfsonarbuoy_conf_file     => $self->{PERFSONARBUOY_CONF_FILE},
        pinger_landmarks_file       => $self->{PINGER_LANDMARKS_CONF_FILE},
        raw_owmesh_conf           => $self->{RAW_OWMESH_CONF},
        opaque_pinger_domains       => \@opaque_domains,
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
    $self->{RAW_OWMESH_CONF}           = $state->{raw_owmesh_conf};

    my @opaque_domains = ();
    foreach my $domain (@{ $state->{opaque_pinger_domains} }) {
        $self->{LOGGER}->debug("Saved domain: ".$domain);
        push @opaque_domains, Domain->new({ xml => $domain });
    }

    $self->{OPAQUE_PINGER_DOMAINS} = \@opaque_domains;

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
        my %opaque_domains = ();

        if ( $topology->get_domain ) {
            # Handle the backward compatibility case where someone has simply
            # selected a group of hosts to monitor using the previous pinger
            # web admin gui, and didn't change any of the settings.

            foreach my $domain ( @{ $topology->get_domain } ) {

                # Skip if it's one of ours
                next if ( $domain->get_id =~ /domain=(group.)?test.[0-9]+$/ );
                next if ( $domain->get_id =~ /domain=mesh_agent_/ );

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

            my @mesh_added_domains = ();

            foreach my $domain ( @{ $topology->get_domain } ) {
                my $test_id;

                my @members = ();

                my $is_mesh_added;
                $is_mesh_added = 1 if ($domain->get_id =~ /domain=mesh_agent_/);

                $self->{LOGGER}->debug("Domain id: ".$domain->get_id);

                if ($is_mesh_added) {
                    $self->{LOGGER}->debug("Adding domain: ".$domain->get_id." to opaque list");
                    push @mesh_added_domains, $domain;
                }

                if ( $domain->get_node ) {
                    my $test_description;

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
                                    added_by_mesh   => $is_mesh_added,
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

                        my ( $status, $res ) = $self->add_test_member( { test_id => $test_id, name => $name, description => $description, address => $node->get_port->get_ipAddress->get_text, receiver => 1, sender => 1, added_by_mesh => $is_mesh_added } );

                        die( "Couldn't add host to PingER test: $res" ) unless ( $status == 0 );
                    }
                }
            }

            $self->{OPAQUE_PINGER_DOMAINS} = \@mesh_added_domains;
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

        foreach my $domain (@{ $self->{OPAQUE_PINGER_DOMAINS} }) {
            $topology->addDomain($domain);
        }

        foreach my $test ( @{ $parameters->{tests} } ) {
            next if ($test->{added_by_mesh});

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
        my $msg = "Failed to create landmarks file: $@";
        $self->{LOGGER}->error($msg);
        return ( -1, $msg);
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

    eval {
        $self->{LOGGER}->debug( "Parsing: " . $parameters->{file} );

        # We can't specify the file directly with pSB currently.
        my $confdir = dirname( $parameters->{file} );

        my $conf = OWP::Conf->new( CONFDIR => $confdir );

        my $owmesh_conf = $self->__parse_owmesh_conf({ existing_configuration => $conf });

        my %localnodes = map { $_ => 1 } @{ $owmesh_conf->{LOCALNODES} };

        use Data::Dumper;

        $self->{LOGGER}->debug("owmesh.conf before removing all the GUI measurement sets: ".Dumper($owmesh_conf));

        # For star configurations, we allow ipv4 and ipv6 sites to co-exist in
        # a single schedule-able test. Since that doesn't work with the owmesh
        # file format, we may name measurement sets something like "[id].IPV4"
        # and "[id].IPV6". When we see those names come up, we add them to the
        # test mapping so that we don't add multiple tests for that case.
        my %test_mapping = ();

        foreach my $measurement_set (keys %{ $owmesh_conf->{MEASUREMENTSET} }) {
            my $measurement_set_desc = $owmesh_conf->{MEASUREMENTSET}->{$measurement_set};

            my $group_name = $measurement_set_desc->{GROUP};
            my $test       = $measurement_set_desc->{TESTSPEC};
            my $addr_type  = $measurement_set_desc->{ADDRTYPE};

            my $test_id;
            my $test_name;

            $self->{LOGGER}->debug( "Measurement Set Name: $measurement_set" );

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
                my $tool = $owmesh_conf->{TESTSPEC}->{$test}->{'TOOL' };
                if ( $tool eq "powstream" ) {
                    my $packet_interval           = $owmesh_conf->{TESTSPEC}->{$test}->{'OWPINTERVAL' };
                    my $loss_threshold            = $owmesh_conf->{TESTSPEC}->{$test}->{'OWPLOSSTHRESH' };
                    my $session_count             = $owmesh_conf->{TESTSPEC}->{$test}->{'OWPSESSIONCOUNT' };
                    my $sample_count              = $owmesh_conf->{TESTSPEC}->{$test}->{'OWPSAMPLECOUNT' };
                    my $packet_padding            = $owmesh_conf->{TESTSPEC}->{$test}->{'OWPPACKETPADDING' };
                    my $bucket_width              = $owmesh_conf->{TESTSPEC}->{$test}->{'OWPBUCKETWIDTH' };

                    my $description = $owmesh_conf->{TESTSPEC}->{$test}->{'DESCRIPTION' };
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
                            added_by_mesh             => $measurement_set_desc->{ADDED_BY_MESH},
                        }
                    );

                    die( "Couldn't add new test: $res" ) unless ( $status == 0 );

                    $test_id = $res;
                }elsif ( $tool eq "traceroute" ) {
                    my $test_interval = $owmesh_conf->{TESTSPEC}->{$test}->{'TRACETESTINTERVAL' };
                    my $packet_size = $owmesh_conf->{TESTSPEC}->{$test}->{'TRACEPACKETSIZE' };
                    my $timeout     = $owmesh_conf->{TESTSPEC}->{$test}->{'TRACETIMEOUT' };
                    my $waittime    = $owmesh_conf->{TESTSPEC}->{$test}->{'TRACEWAITTIME' };
                    my $first_ttl   = $owmesh_conf->{TESTSPEC}->{$test}->{'TRACEFIRSTTTL' };
                    my $max_ttl     = $owmesh_conf->{TESTSPEC}->{$test}->{'TRACEMAXTTL' };
                    my $pause       = $owmesh_conf->{TESTSPEC}->{$test}->{'TRACEPAUSE' };
                    my $icmp        = $owmesh_conf->{TESTSPEC}->{$test}->{'TRACEICMP' };
                    my $description = $owmesh_conf->{TESTSPEC}->{$test}->{'DESCRIPTION' };
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
                            protocol      => ($icmp ? 'icmp' : 'udp'),
                            added_by_mesh => $measurement_set_desc->{ADDED_BY_MESH},
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

                    my $test_interval             = $owmesh_conf->{TESTSPEC}->{$test}->{'BWTestInterval' };
                    my $duration                  = $owmesh_conf->{TESTSPEC}->{$test}->{'BWTestDuration' };
                    my $window_size               = $owmesh_conf->{TESTSPEC}->{$test}->{'BWWindowSize' };
                    my $report_interval           = $owmesh_conf->{TESTSPEC}->{$test}->{'BWReportInterval' };
                    my $udp_bandwidth             = $owmesh_conf->{TESTSPEC}->{$test}->{'BWUDPBandwidthLimit' };
                    my $buffer_length             = $owmesh_conf->{TESTSPEC}->{$test}->{'BWBufferLen' };
                    my $test_interval_start_alpha = $owmesh_conf->{TESTSPEC}->{$test}->{'BWTestIntervalStartAlpha' };
                    my $tos_bits                  = $owmesh_conf->{TESTSPEC}->{$test}->{'BWTosBits' };

                    my $description = $owmesh_conf->{TESTSPEC}->{$test}->{DESCRIPTION};
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
                            tos_bits                  => $tos_bits,
                            added_by_mesh             => $measurement_set_desc->{ADDED_BY_MESH},
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

            my $group_desc = $owmesh_conf->{GROUP}->{$group_name};

            # Handle the group
            my $group_type = $group_desc->{GROUPTYPE};

            if ( $group_type ne "STAR" ) {
                die( "Can only handle 'star' groups currently" );
            }

            my @node_sets = ();

            push @node_sets, { type => "include", nodes => $group_desc->{NODES}, sender => 1, receiver => 1 };
            push @node_sets, { type => "include", nodes => $group_desc->{INCLUDE_RECEIVERS}, sender => 0, receiver => 1 };
            push @node_sets, { type => "exclude", nodes => $group_desc->{EXCLUDE_RECEIVERS}, receiver => 0 };
            push @node_sets, { type => "include", nodes => $group_desc->{INCLUDE_SENDERS}, sender => 1, receiver => 0 };
            push @node_sets, { type => "exclude", nodes => $group_desc->{EXCLUDE_SENDERS}, sender => 0 };

            my %senders   = ();
            my %receivers = ();

            my %member_ids = ();

            foreach my $node_set ( @node_sets ) {
                foreach my $node ( @{ $node_set->{nodes} } ) {
                    my $node_desc = $owmesh_conf->{NODE}->{$node};
                    my $node_addr = $node_desc->{$addr_type.'ADDR'};

                    next unless ( $node_addr );

                    my $node_description = $node_desc->{LONGNAME};
                    $node_description = $node unless ( $node_description );

                    my $node_owp_test_ports = $node_desc->{OWPTESTPORTS};

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
                        my ($status, $res) = $self->add_test_member( { test_id => $test_id, name => $node, description => $node_description, address => $addr, port => $port, receiver => $node_set->{receiver}, sender => $node_set->{sender}, added_by_mesh => $measurement_set_desc->{ADDED_BY_MESH} } );
                        if ($status == 0) {
                            $member_ids{$addr} = $res;
                        }
                    }
                    else {
                        $self->update_test_member( { test_id => $test_id, member_id => $member_ids{$addr}, description => $node_desc, port => $port, receiver => $node_set->{receiver}, sender => $node_set->{sender} } );
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
                my $center = $owmesh_conf->{GROUP}->{$group_name}->{HAUPTNODE};
                my $node_addr = $owmesh_conf->{NODE}->{$center}->{$addr_type.'ADDR'};

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

            unless ($measurement_set_desc->{ADDED_BY_MESH}) {
                $self->__owmesh_conf_delete_measurement_set({ measurement_set => $measurement_set, owmesh_conf => $owmesh_conf });
            }
        }

        $self->{LOGGER}->debug("owmesh.conf after removing all the GUI measurement sets: ".Dumper($owmesh_conf));

        $self->{RAW_OWMESH_CONF} = $owmesh_conf;
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
    my $parameters = validate( @params, { tests => 1, raw_owmesh_conf => 1 } );
    my $tests       = $parameters->{tests};
    my $raw_owmesh_conf = $parameters->{raw_owmesh_conf};

    $self->{LOGGER}->debug("Generating owmesh.conf");
    my ($status, $res) = $self->__add_tests_to_owmesh_conf({ tests => $tests, owmesh_conf => $raw_owmesh_conf });

    unless ($status == 0) {
        my $msg = "Couldn't add tests to owmesh.conf: ".$res;
        $self->{LOGGER}->error($msg);
        return $res;
    }

    $self->{LOGGER}->debug("Added tests to owmesh.conf: ".Dumper($raw_owmesh_conf));

    my $content = $self->__build_owmesh_conf($raw_owmesh_conf);

    $self->{LOGGER}->debug("Built new owmesh.conf: $content");

    return (0, $content);
}

sub __add_tests_to_owmesh_conf {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { tests => 1, owmesh_conf => 1 } );
    my $tests           = $parameters->{tests};
    my $owmesh_conf = $parameters->{owmesh_conf};

    # Convert the internal representation into owmesh concepts.

    my %used_nodenames = ();
    my %node_names_by_addrdesc = ();

    foreach my $test ( @{$tests} ) {
        next if ($test->{added_by_mesh});

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

    my $local_node = $self->__owmesh_conf_get_node({ owmesh_conf => $owmesh_conf, id => "KNOPPIX" });
    unless ($local_node) {
        $local_node = $self->__owmesh_conf_add_node({ owmesh_conf => $owmesh_conf, id => "KNOPPIX" });
    }
    $local_node->{LONGNAME} = "local host";

    if ($self->{LOCAL_PORT_RANGES}->{owamp}) {
        $self->{LOGGER}->info("Saving owamp port range");
        $local_node->{OWPTESTPORTS} = $self->{LOCAL_PORT_RANGES}->{owamp}->{min_port}."-".$self->{LOCAL_PORT_RANGES}->{owamp}->{max_port}
    }

    $self->__owmesh_conf_add_localnode({ owmesh_conf => $owmesh_conf, node => "KNOPPIX" });

    foreach my $test ( @{$tests} ) {
        next if ($test->{added_by_mesh});

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
            next if ( $ip_type eq "IPV4" and not $test->{center}->{ipv4_address} );
            next if ( $ip_type eq "IPV6" and not $test->{center}->{ipv6_address} );

            # At minimum, test_spec has to be upper-case
            my $group           = $self->__owmesh_conf_add_group({ owmesh_conf => $owmesh_conf, id => $test_name . "." . $ip_type });
            my $measurement_set = $self->__owmesh_conf_add_measurement_set({ owmesh_conf => $owmesh_conf, id => $test_name . "." . $ip_type });
            my $test_spec       = $self->__owmesh_conf_add_testspec({ owmesh_conf => $owmesh_conf, id => $test_name . "." . $ip_type });

            $test_spec->{DESCRIPTION} = $test->{description};

            $self->{LOGGER}->debug( "Doing " . Dumper( $test ) );

            if ( $test->{type} eq "bwctl/throughput" ) {
                $test_spec->{TOOL}                      = "bwctl/".$test->{parameters}->{tool};
                $test_spec->{BWUDP}                     = 1 if $test->{parameters}->{protocol} eq "udp";
                $test_spec->{BWTCP}                     = 1 if $test->{parameters}->{protocol} eq "tcp";
                $test_spec->{BWTestInterval}            = $test->{parameters}->{test_interval};
                $test_spec->{BWTestDuration}            = $test->{parameters}->{duration};
                $test_spec->{BWWindowSize}              = $test->{parameters}->{window_size} . "m" if ( $test->{parameters}->{window_size} );                    # Add the 'm' on since it's in Megabytes
                $test_spec->{BWReportInterval}          = $test->{parameters}->{report_interval};
                $test_spec->{BWUDPBandwidthLimit}       = $test->{parameters}->{udp_bandwidth} . "m" if ( $test->{parameters}->{udp_bandwidth} );    # Add the 'm' on since it's in Mbps
                $test_spec->{BWBufferLen}               = $test->{parameters}->{buffer_length};
                $test_spec->{BWTestIntervalStartAlpha}  = $test->{parameters}->{test_interval_start_alpha};
                $test_spec->{BWTosBits}              	= $test->{parameters}->{tos_bits}  if ( $test->{parameters}->{tos_bits} ); 
                $measurement_set->{EXCLUDE_SELF} = 1;
            } elsif ($test->{type} eq "owamp") {
                $test_spec->{TOOL}                      = "powstream";
                $test_spec->{OWPINTERVAL}      = $test->{parameters}->{packet_interval}  if ( defined $test->{parameters}->{packet_interval} );
                $test_spec->{OWPLOSSTHRESH}    = $test->{parameters}->{loss_threshold}   if ( defined $test->{parameters}->{loss_threshold} );
                $test_spec->{OWPSESSIONCOUNT}  = $test->{parameters}->{session_count}    if ( defined $test->{parameters}->{session_count} );
                $test_spec->{OWPSAMPLECOUNT}   = $test->{parameters}->{sample_count}     if ( defined $test->{parameters}->{sample_count} );
                $test_spec->{OWPPACKETPADDING} = $test->{parameters}->{packet_padding}   if ( defined $test->{parameters}->{packet_padding} );
                $test_spec->{OWPBUCKETWIDTH}   = $test->{parameters}->{bucket_width}     if ( defined $test->{parameters}->{bucket_width} );
                $measurement_set->{EXCLUDE_SELF} = 0;
            } elsif ($test->{type} eq "traceroute") {
                $test_spec->{TOOL}                      = "traceroute";
                $test_spec->{TRACETESTINTERVAL}         = $test->{parameters}{test_interval}             if ( defined $test->{parameters}{test_interval} );
                $test_spec->{TRACEPACKETSIZE}           = $test->{parameters}{packet_size}               if ( defined $test->{parameters}{packet_size} );
                $test_spec->{TRACETIMEOUT}              = $test->{parameters}{timeout}                   if ( defined $test->{parameters}{timeout} );
                $test_spec->{TRACEWAITTIME}             = $test->{parameters}{waittime}                  if ( defined $test->{parameters}{waittime} );
                $test_spec->{TRACEFIRSTTTL}             = $test->{parameters}{first_ttl}                 if ( defined $test->{parameters}{first_ttl} );
                $test_spec->{TRACEMAXTTL}               = $test->{parameters}{max_ttl}                   if ( defined $test->{parameters}{max_ttl} );
                $test_spec->{TRACEPAUSE}                = $test->{parameters}{pause}                     if ( defined $test->{parameters}{pause} );
                $test_spec->{TRACEICMP}                 = 1 if ($test->{parameters}{protocol} eq "icmp");
                $measurement_set->{EXCLUDE_SELF} = 0;
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

            $self->__owmesh_conf_add_addrtype({ owmesh_conf => $owmesh_conf, addrtype => $addr_type });

            $measurement_set->{DESCRIPTION}  = $test->{description};
            $measurement_set->{ADDRTYPE}     = $addr_type;
            $measurement_set->{GROUP}        = $group->{ID};
            $measurement_set->{TESTSPEC}     = $test_spec->{ID};
            
            $group->{GROUPTYPE}   = "STAR";

            $self->{LOGGER}->debug( "Outputing group: " . Dumper( $test->{group} ) );

            my %exclude_senders   = ();
            my %exclude_receivers = ();

            foreach my $member_id ( keys %{ $test->{members} } ) {
                my $member = $test->{members}->{$member_id};

                if ( $ip_type eq "IPV6") {
                    # Skip if it's an IPv6 Test, and it's not an IPv6 address
                    unless ( $self->determine_ipv6( $member->{address} ) ) {
                        $self->{LOGGER}->debug( "Test is ipv6, ".$member->{address}." is not IPv6" );
                        next;
                    }
                }
                else { # i.e. this is an IPv4 test
                    unless ( $self->determine_ipv4( $member->{address} ) ) {
                        # To avoid getting rid of hostnames when we can't
                        # lookup addresses (in which case both ipv4 and ipv6
                        # addresses would get thrown away as not being either
                        # ipv4 or ipv6), we put hostnames that don't have AAAA
                        # records into the IPv4 tests.
                        if ( is_hostname( $member->{address} ) and
                             not $self->determine_ipv6( $member->{address}) ) {
                            $self->{LOGGER}->warn( "Test is ipv4, ".$member->{address}." is a hostname, but we can't tell if it's got an IPv4 or IPv6 address. Assuming IPv4.");
                        }
                        else {
                            $self->{LOGGER}->debug( "Test is ipv4, ".$member->{address}." is not IPv4. It is also either not a hostname, or is a hostname, but has an IPv6 address" );
                            next;
                        }
                    }
                }

                next if( $duplicate_test_map{$member_id} );
                $duplicate_test_map{$member_id} = 1;
                
                # The center gets output later
                next if ( $test->{center}->{ipv4_address} and $member->{address} eq $test->{center}->{ipv4_address} );
                next if ( $test->{center}->{ipv6_address} and $member->{address} eq $test->{center}->{ipv6_address} );

                my $new_node;

                if ( $member->{name} ) {
                    $new_node = $self->__owmesh_conf_get_node({ owmesh_conf => $owmesh_conf, id => $member->{name} });
                }

                unless ($new_node) {
                    my $key = "";
                    $key .= $member->{address} if ($member->{address});
                    $key .= "|";
                    $key .= $member->{description} if ($member->{description});

                    $self->{LOGGER}->debug("Looking up key: $key");

                    my $node_name = $node_names_by_addrdesc{$key};

                    $new_node = $self->__owmesh_conf_get_node({ owmesh_conf => $owmesh_conf, id => $node_name });
                }

                unless ($new_node) {
                    my $key = "";
                    $key .= $member->{address} if ($member->{address});
                    $key .= "|";
                    $key .= $member->{description} if ($member->{description});

                    my $node_id;

                    if ($member->{name}) {
                        $node_id = $member->{name};
                    }
                    elsif ($node_names_by_addrdesc{$key}) {
                        $node_id = $node_names_by_addrdesc{$key};
                    }
                    else {

                        $node_id = address_to_id( $member->{address} );
                        my $i = 0;
                        while ($self->__owmesh_conf_get_node({ owmesh_conf => $owmesh_conf, id => $node_id })) {
                            $node_id = address_to_id( $member->{address} );
                            $node_id .= "-".$i;
                            $i++;
                        }
                    }

                    $new_node = $self->__owmesh_conf_add_node({ owmesh_conf => $owmesh_conf, id => $node_id });
                }

                $new_node->{LONGNAME} = $member->{description};

                my $addr = $member->{address};
                $addr = "[".$addr."]" if &Net::IP::ip_is_ipv6( $addr ) and not $addr =~ /\[/;
                $addr .= ":".$member->{port} if ($member->{port});

                $new_node->{$addr_type."ADDR"} = $addr;
                $new_node->{CONTACTADDR} = $member->{address} unless ($new_node->{CONTACTADDR});
                $new_node->{NOAGENT}    = 1 unless ( $self->{LOCAL_ADDRS}->{ $member->{address} } );

                $self->__owmesh_conf_group_add_node({ owmesh_conf => $owmesh_conf, group => $group->{ID}, node => $new_node->{ID} });
                $self->__owmesh_conf_group_add_exclude_senders({ owmesh_conf => $owmesh_conf, group => $group->{ID}, node => $new_node->{ID} }) unless ($member->{sender});
                $self->__owmesh_conf_group_add_exclude_receivers({ owmesh_conf => $owmesh_conf, group => $group->{ID}, node => $new_node->{ID} }) unless ($member->{receiver});

                if ( $self->{LOCAL_ADDRS}->{ $member->{address} } ) {
                    $self->__owmesh_conf_add_localnode({ owmesh_conf => $owmesh_conf, node => $new_node->{ID} });
                }

                my $key = "";
                $key .= $member->{address} if ($member->{address});
                $key .= "|";
                $key .= $member->{description} if ($member->{description});
                $node_names_by_addrdesc{$key} = $new_node->{ID};
                $self->{LOGGER}->debug("Saving node as key: $key");
            }

            # Center Address
            my $center_address = $test->{center}->{ipv4_address};
            $center_address = $test->{center}->{ipv6_address} if ( $ip_type eq "IPV6" );

            my $addr = $center_address;
            $addr = "[".$addr."]" if &Net::IP::ip_is_ipv6( $addr ) and not $addr =~ /\[/;

            $local_node->{$addr_type."ADDR"} = $addr;
            $local_node->{CONTACTADDR}       = $center_address;

            $group->{HAUPTNODE}         = $local_node->{ID};
            $self->__owmesh_conf_group_add_node({ owmesh_conf => $owmesh_conf, group => $group->{ID}, node => $local_node->{ID} });
        }
    }

    return (0, "");
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

sub __parse_owmesh_conf {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { existing_configuration => 1, } );
    my $existing_configuration = $parameters->{existing_configuration};

    my @top_level_prefixes = ("", "BW", "OWP", "TRACE");
    my @top_level_variables = (
           "ConfigVersion", "SyslogFacility", "GroupName", "UserName", "DevNull", # Generic variables applicable to everything
           "CentralDBName", "CentralDBPass", "CentralDBType", "CentralDBUser",  # We don't autogenerate a collector configuration so copy all those variables over
           "SessionSumCmd", "CentralDataDir", "CentralArchDir", # We don't autogenerate a collector configuration so copy all those variables over
           "CentralHost", "CentralHostTimeout", "SendTimeout", # Copy this over since we don't have a better use for it.
           "SecretName", # Copy the SecretName for now, but we need to figure out how to impart this in the future
           "DataDir", "SessionSuffix", "SummarySuffix", "BinDir", "Cmd" # Used by the master, but generic, or specific to the host it's running on.
    );
    my @measurementset_attrs = ('TESTSPEC', 'ADDRTYPE', 'GROUP', 'DESCRIPTION', 'EXCLUDE_SELF', 'ADDED_BY_MESH');
    my @group_attrs = ('GROUPTYPE','NODES','SENDERS','RECEIVERS','INCLUDE_RECEIVERS','EXCLUDE_RECEIVERS','INCLUDE_SENDERS','EXCLUDE_SENDERS','HAUPTNODE');
    my @node_attrs  = ('ADDR', 'LONGNAME', 'OWPTESTPORTS', 'NOAGENT', 'CONTACTADDR');
    my @testspec_attrs  = (
        'TOOL', 'DESCRIPTION',
        'OWPINTERVAL', 'OWPLOSSTHRESH', 'OWPSESSIONCOUNT', 'OWPSAMPLECOUNT', 'OWPPACKETPADDING', 'OWPBUCKETWIDTH',
        'TRACETESTINTERVAL', 'TRACEPACKETSIZE', 'TRACETIMEOUT', 'TRACEWAITTIME', 'TRACEFIRSTTTL', 'TRACEMAXTTL', 'TRACEPAUSE', 'TRACEICMP',
        'BWTCP', 'BWUDP', 'BWTestInterval', 'BWTestDuration', 'BWWindowSize', 'BWReportInterval', 'BWUDPBandwidthLimit', 'BWBufferLen', 'BWTestIntervalStartAlpha', 'BWTosBits'
    );

    my %top_level_variables = ();
    my %nodes            = ();
    my %groups           = ();
    my %testspecs        = ();
    my %measurement_sets = ();
    my @addrtypes        = ();
    my @localnodes       = ();

    eval {
        foreach my $variable_prefix (@top_level_prefixes) {
            my @variables = @top_level_variables;

            foreach my $variable (@variables) {
                $self->{LOGGER}->debug("Checking ".$variable_prefix.$variable);

                my $value = $existing_configuration->get_val(ATTR => $variable, TYPE => $variable_prefix);

                $self->{LOGGER}->debug($variable." is defined: ".$value) if defined $value;
    
                if ($variable_prefix ne "") {
                    my $higher_value = $existing_configuration->get_val(ATTR => $variable);

                    if ($higher_value and $value eq $higher_value) {
                        $self->{LOGGER}->debug("Existing higher value $higher_value for $variable is the same");
                        next;
                    }
                }
    
                # Pull the existing owmesh configuration
                $top_level_variables{$variable_prefix.$variable} = $value if defined $value;

                # SecretName is a special case...
                if ($variable_prefix.$variable eq "SecretName" and $value) {
                    push @variables, $value;
                }
            }
        }

        my %addrtypes        = ();

        # Only include the local nodes that were for tests that we didn't add.
        my @measurement_sets = $existing_configuration->get_sublist( LIST => 'MEASUREMENTSET' );

        foreach my $measurement_set ( @measurement_sets ) {
            next if ($measurement_sets{$measurement_set});

            $measurement_sets{$measurement_set} = {};

            my $measurement_set_desc = $measurement_sets{$measurement_set};

            foreach my $attr (@measurementset_attrs) {
                __get_ref( $existing_configuration, $measurement_set_desc, $attr, { MEASUREMENTSET => $measurement_set });
            }

            my $addrtype = $measurement_set_desc->{ADDRTYPE};

            $addrtypes{$addrtype} = 1;

            my $group    = $measurement_set_desc->{GROUP};

            unless ($groups{$group}) {
                $groups{$group} = {};

                my $group_desc = $groups{$group};

                foreach my $attr (@group_attrs) {
                    __get_ref($existing_configuration, $group_desc, $attr, { GROUP => $group });
                }

                foreach my $node ( @{ $group_desc->{NODES} } ) {
                    $nodes{$node} = {} unless $nodes{$node};

                    my $node_desc = $nodes{$node};

                    foreach my $attr (@node_attrs) {
                        __get_ref($existing_configuration, $node_desc, $attr, { NODE => $node });
                        __get_ref($existing_configuration, $node_desc, $measurement_set_desc->{ADDRTYPE}.$attr, { NODE => $node });
                    }
                }
            }

            my $testspec = $measurement_set_desc->{TESTSPEC};
            unless ($testspecs{$testspec}) {
                $testspecs{$testspec} = {};

                my $testspec_desc = $testspecs{$testspec};

                foreach my $attr (@testspec_attrs) {
                    __get_ref($existing_configuration, $testspec_desc, $attr, { TESTSPEC => $testspec });
                }
            }
        }

        # Only include the local nodes that were for tests that we didn't add.
        my @temp_local_nodes = $existing_configuration->get_val(  ATTR => 'LOCALNODES'  );
        foreach my $node (@temp_local_nodes) {
            push @localnodes, $node if ($nodes{$node});
        }

        @addrtypes = keys %addrtypes;
    };
    if ( $@ ) {
        return ( -1, $@ );
    }

    my %owmesh_config = ();
    %owmesh_config = %top_level_variables; # Copy the top-level variables over

    $owmesh_config{MEASUREMENTSET} = \%measurement_sets;
    $owmesh_config{NODE}           = \%nodes;
    $owmesh_config{GROUP}          = \%groups;
    $owmesh_config{TESTSPEC}       = \%testspecs;
    $owmesh_config{ADDRTYPES}      = \@addrtypes;
    $owmesh_config{LOCALNODES}     = \@localnodes;

    return ( 0, \%owmesh_config );
}

sub __get_ref {
    my ( $conf, $hash, $attr, $params ) = @_;

    my %params = %$params;
    $params{ATTR} = $attr;

    eval {
        my $val = $conf->get_ref( %params );
        $hash->{$attr} = $val if defined ($val);
    };

    return;
}

sub __owmesh_conf_delete_measurement_set {
    my ($self, @params) = @_;
    my $parameters = validate( @params, { measurement_set => 1, owmesh_conf => 1 });
    my $measurement_set = $parameters->{measurement_set};
    my $owmesh_conf     = $parameters->{owmesh_conf};

    my $addrtype = $owmesh_conf->{MEASUREMENTSET}->{$measurement_set}->{ADDRTYPE};
    my $group    = $owmesh_conf->{MEASUREMENTSET}->{$measurement_set}->{GROUP};
    my $testspec = $owmesh_conf->{MEASUREMENTSET}->{$measurement_set}->{TESTSPEC};

    delete($owmesh_conf->{MEASUREMENTSET}->{$measurement_set});

    my ($delete_group, $delete_testspec, $delete_addrtype) = (1, 1, 1);

    foreach my $curr_measurement_set (values %{ $owmesh_conf->{MEASUREMENTSET} }) {
        $delete_addrtype = 0 if ($curr_measurement_set->{ADDRTYPE} eq $addrtype);
        $delete_group    = 0 if ($curr_measurement_set->{GROUP} eq $group);
        $delete_testspec = 0 if ($curr_measurement_set->{TESTSPEC} eq $testspec);
    }

    $self->__owmesh_conf_delete_group({ group => $group, owmesh_conf => $owmesh_conf }) if $delete_group;
    $self->__owmesh_conf_delete_testspec({ testspec => $testspec, owmesh_conf => $owmesh_conf }) if $delete_testspec;
    $self->__owmesh_conf_delete_addrtype({ addrtype => $addrtype, owmesh_conf => $owmesh_conf }) if $delete_addrtype;

    return;
}

sub __owmesh_conf_get_node {
    my ($self, @params) = @_;
    my $parameters  = validate( @params, { id => 1, owmesh_conf => 1 });
    my $id          = $parameters->{id};
    my $owmesh_conf = $parameters->{owmesh_conf};

    return $owmesh_conf->{NODE}->{$id};
}

sub __owmesh_conf_get_group_members {
    my ($self, @params) = @_;
    my $parameters  = validate( @params, { group => 1, owmesh_conf => 1 });
    my $group       = $parameters->{group};
    my $owmesh_conf = $parameters->{owmesh_conf};

    my @referenced_nodes = @{ $owmesh_conf->{GROUP}->{$group}->{NODES} };

    my $hauptnode = $owmesh_conf->{GROUP}->{$group}->{HAUPTNODE};
    push @referenced_nodes, $hauptnode if ($hauptnode);

    return \@referenced_nodes;
}

sub __owmesh_conf_group_add_node {
    my ($self, @params) = @_;
    my $parameters  = validate( @params, { group => 1, node => 1, owmesh_conf => 1 });
    my $group       = $parameters->{group};
    my $node        = $parameters->{node};
    my $owmesh_conf = $parameters->{owmesh_conf};

    my $group_desc = $owmesh_conf->{GROUP}->{$group};
    $group_desc->{NODES} = [] unless $group_desc->{NODES};

    my %existing = map { $_ => 1 } @{ $group_desc->{NODES} };

    push @{ $group_desc->{NODES} }, $node unless $existing{$node};

    return;
}

sub __owmesh_conf_group_add_exclude_senders {
    my ($self, @params) = @_;
    my $parameters  = validate( @params, { group => 1, node => 1, owmesh_conf => 1 });
    my $group       = $parameters->{group};
    my $node        = $parameters->{node};
    my $owmesh_conf = $parameters->{owmesh_conf};

    my $group_desc = $owmesh_conf->{GROUP}->{$group};
    $group_desc->{EXCLUDE_SENDERS} = [] unless $group_desc->{EXCLUDE_SENDERS};

    my %existing = map { $_ => 1 } @{ $group_desc->{EXCLUDE_SENDERS} };

    push @{ $group_desc->{EXCLUDE_SENDERS} }, $node unless $existing{$node};

    return;
}

sub __owmesh_conf_group_add_exclude_receivers {
    my ($self, @params) = @_;
    my $parameters  = validate( @params, { group => 1, node => 1, owmesh_conf => 1 });
    my $group       = $parameters->{group};
    my $node        = $parameters->{node};
    my $owmesh_conf = $parameters->{owmesh_conf};

    my $group_desc = $owmesh_conf->{GROUP}->{$group};
    $group_desc->{EXCLUDE_RECEIVERS} = [] unless $group_desc->{EXCLUDE_RECEIVERS};

    my %existing = map { $_ => 1 } @{ $group_desc->{EXCLUDE_RECEIVERS} };

    push @{ $group_desc->{EXCLUDE_RECEIVERS} }, $node unless $existing{$node};

    return;
}


sub __owmesh_conf_delete_group {
    my ($self, @params) = @_;
    my $parameters  = validate( @params, { group => 1, owmesh_conf => 1 });
    my $group       = $parameters->{group};
    my $owmesh_conf = $parameters->{owmesh_conf};

    my $referenced_nodes = $self->__owmesh_conf_get_group_members({ group => $group, owmesh_conf => $owmesh_conf });

    my %nodes_to_delete = map { $_ => 1 } @$referenced_nodes;

    delete($owmesh_conf->{GROUP}->{$group});

    foreach my $curr_group (keys %{ $owmesh_conf->{GROUP} }) {
        my $curr_group_nodes = $self->__owmesh_conf_get_group_members({ group => $curr_group, owmesh_conf => $owmesh_conf });
        foreach my $node (@$curr_group_nodes) {
            delete($nodes_to_delete{$node});
        }
    }

    foreach my $node (keys %nodes_to_delete) {
        delete($owmesh_conf->{NODE}->{$node});
    }

    my @new_local_nodes = ();
    foreach my $node (@{ $owmesh_conf->{LOCALNODES} }) {
        push @new_local_nodes, $node unless ($nodes_to_delete{$node});
    }

    $owmesh_conf->{LOCALNODES} = \@new_local_nodes;

    return;
}

sub __owmesh_conf_add_node {
    my ($self, @params) = @_;
    my $parameters = validate( @params, { id => 1, owmesh_conf => 1 });
    my $id         = $parameters->{id};
    my $owmesh_conf = $parameters->{owmesh_conf};

    $owmesh_conf->{NODE}->{$id} = { ID => $id };

    return $owmesh_conf->{NODE}->{$id};
}

sub __owmesh_conf_add_group {
    my ($self, @params) = @_;
    my $parameters = validate( @params, { id => 1, owmesh_conf => 1 });
    my $id         = $parameters->{id};
    my $owmesh_conf = $parameters->{owmesh_conf};

    $owmesh_conf->{GROUP}->{$id} = { ID => $id };

    return $owmesh_conf->{GROUP}->{$id};
}

sub __owmesh_conf_add_measurement_set {
    my ($self, @params) = @_;
    my $parameters = validate( @params, { id => 1, owmesh_conf => 1 });
    my $id         = $parameters->{id};
    my $owmesh_conf = $parameters->{owmesh_conf};

    $owmesh_conf->{MEASUREMENTSET}->{$id} = { ID => $id };

    return $owmesh_conf->{MEASUREMENTSET}->{$id};
}

sub __owmesh_conf_add_testspec {
    my ($self, @params) = @_;
    my $parameters = validate( @params, { id => 1, owmesh_conf => 1 });
    my $id         = $parameters->{id};
    my $owmesh_conf = $parameters->{owmesh_conf};

    $owmesh_conf->{TESTSPEC}->{$id} = { ID => $id };

    return $owmesh_conf->{TESTSPEC}->{$id};
}

sub __owmesh_conf_add_localnode {
    my ($self, @params) = @_;
    my $parameters = validate( @params, { node => 1, owmesh_conf => 1 });
    my $node       = $parameters->{node};
    my $owmesh_conf = $parameters->{owmesh_conf};

    my %existing = map { $_ => 1 } @{ $owmesh_conf->{LOCALNODES} };

    push @{ $owmesh_conf->{LOCALNODES} }, $node unless $existing{$node};

    return;
}

sub __owmesh_conf_delete_addrtype {
    my ($self, @params) = @_;
    my $parameters = validate( @params, { addrtype => 1, owmesh_conf => 1 });
    my $addrtype   = $parameters->{addrtype};
    my $owmesh_conf = $parameters->{owmesh_conf};

    my @new_addrtypes = ();

    foreach my $existing_addrtype (@{ $owmesh_conf->{ADDRTYPES} }) {
        push @new_addrtypes, $existing_addrtype if ($existing_addrtype ne $addrtype);
    }

    $owmesh_conf->{ADDRTYPES} = \@new_addrtypes;

    # Get rid of the addresses associated with that addrtype
    foreach my $node (values %{ $owmesh_conf->{NODE} }) {
        delete($node->{$addrtype."ADDR"});
    }

    return;
}

sub __owmesh_conf_delete_testspec {
    my ($self, @params) = @_;
    my $parameters = validate( @params, { testspec => 1, owmesh_conf => 1 });
    my $testspec   = $parameters->{testspec};
    my $owmesh_conf = $parameters->{owmesh_conf};

    delete($owmesh_conf->{TESTSPEC}->{$testspec});

    return;
}


sub __owmesh_conf_add_addrtype {
    my ($self, @params) = @_;
    my $parameters = validate( @params, { addrtype => 1, owmesh_conf => 1 });
    my $addrtype   = $parameters->{addrtype};
    my $owmesh_conf = $parameters->{owmesh_conf};

    my %addrtypes = map { $_ => 1 } @{ $owmesh_conf->{ADDRTYPES} };

    push @{ $owmesh_conf->{ADDRTYPES} }, $addrtype unless $addrtypes{$addrtype};

    return;
}

sub __build_owmesh_conf {
    my ($self, $owmesh_desc) = @_;

    my $text = "";

    foreach my $key (sort keys %$owmesh_desc) {
        if (ref($owmesh_desc->{$key}) eq "ARRAY") {
            $text .= $key."\t";
            $text .= "[[ ".join("  ", @{ $owmesh_desc->{$key} })." ]]";
        }
        elsif (ref($owmesh_desc->{$key}) eq "HASH") {
            foreach my $subkey (sort keys %{ $owmesh_desc->{$key} }) {
                $text .= "<$key=$subkey>\n";
                $text .= $self->__build_owmesh_conf($owmesh_desc->{$key}->{$subkey});
                $text .= "</$key>\n";
            }
        }
        else {
            if (defined $owmesh_desc->{$key}) {
                $text .= $key."\t".$owmesh_desc->{$key};
            }
            else {
                $text .= "!".$key;
            }
        }

        $text .= "\n";
    }

    return $text;
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
