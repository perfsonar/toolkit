package perfSONAR_PS::NPToolkit::Config::Services;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::Services

=head1 DESCRIPTION

Module for configuring the set of services for the toolkit. Currently, this is
only used to enable/disable services. Longer term, it'd be good to think about
how the enable/disable configuration integrates with the configuration for each
service.

=cut

use Data::Dumper;

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'SERVICES', 'ENABLED_SERVICES_FILE';

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger :nowarn);
use Storable qw(store retrieve freeze thaw dclone);

use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file start_service restart_service stop_service );

# These are the defaults for the current NPToolkit
my %defaults = ( enabled_services_file => "/opt/perfsonar_ps/toolkit/etc/enabled_services", );

my @default_known_services = (
    {
        name        => "hls",
        description => "Lookup Service",
        service_name=> "lookup_service",
        enabled_services_variable => "hls_enabled",
        enabled     => 1,
    },
    {
        name        => "ls_registration_daemon",
        description => "LS Registration Daemon",
        service_name=> "ls_registration_daemon",
        enabled     => 1,
    },
    {
        name                      => "snmp_ma",
        description               => "SNMP MA",
        enabled_services_variable => "snmpma_enabled",
        service_name              => "snmp_ma",
        enabled                   => 1,
    },
    {
        name                      => "ndt",
        description               => "NDT",
        enabled_services_variable => "ndt_enabled",
        service_name              => "ndt",
        enabled                   => 1,
    },
    {
        name                      => "npad",
        description               => "NPAD",
        enabled_services_variable => "npad_enabled",
        service_name              => "npad",
        enabled                   => 1,
    },
    {
        name                      => "pinger",
        description               => "PingER",
        enabled_services_variable => "pinger_enabled",
        service_name              => "PingER",
        enabled                   => 1,
    },
    {
        name                      => "owamp",
        description               => "OWAMP",
        enabled_services_variable => "owamp_enabled",
        service_name              => "owampd",
        enabled                   => 1,
    },
    {
        name                      => "bwctl",
        description               => "BWCTL",
        enabled_services_variable => "bwctl_enabled",
        service_name              => "bwctld",
        enabled                   => 1,
    },
    {
        name                      => "ssh",
        description               => "SSH",
        enabled_services_variable => "ssh_enabled",
        service_name              => "sshd",
        enabled                   => 0,
    },
    {
        name                      => "http",
        description               => "Web Services",
        enabled_services_variable => "https_enabled",
        service_name              => "httpd",
        enabled                   => 1,
    },
    {
        name                      => "perfsonarbuoy_ma",
        description               => "perfSONAR-BUOY MA",
        enabled_services_variable => "psb_ma_enabled",
        service_name              => "perfsonarbuoy_ma",
        enabled                   => 1,
    },
    {
        name                      => "perfsonarbuoy_owamp",
        description               => "perfSONAR-BUOY Collector (Latency)",
        enabled_services_variable => "psb_owamp_enabled",
        service_name              => [ "perfsonarbuoy_owp_collector", "perfsonarbuoy_owp_master" ],
        enabled                   => 1,
    },
    {
        name                      => "perfsonarbuoy_bwctl",
        description               => "perfSONAR-BUOY Collector (Throughput)",
        enabled_services_variable => "psb_enabled",
        service_name              => [ "perfsonarbuoy_bw_collector", "perfsonarbuoy_bw_master" ],
        enabled                   => 1,
    },
    {
        name                      => "traceroute_scheduler",
        description               => "perfSONAR-PS Traceroute Scheduler",
        enabled_services_variable => "traceroute_scheduler_enabled",
        service_name              => [ "traceroute_scheduler", "traceroute_master" ],
        enabled                   => 1,
    },
    {
        name                      => "traceroute_ma",
        description               => "perfSONAR-PS Traceroute MA",
        enabled_services_variable => "traceroute_ma_enabled",
        service_name              => [ "traceroute_ma" ],
        enabled                   => 1,
    },
    {
        name        => "ntp",
        description => "NTP",
        service_name=> "ntpd",
        enabled     => 1,
    },
    {
        name        => "maddash",
        description => "Monitoring and Debugging Dashboard",
        service_name=> "maddash-server",
        enabled_services_variable => "maddash_enabled",
        enabled     => 1,
    },
);

=head2 init({ enabled_services_file => 0 })

Initializes the client. Returns 0 on success and -1 on failure. The
enabled_services_file parameter can be specified to set which file the module
should use for reading/writing the configuration.

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { enabled_services_file => 0, } );

    # Initialize the defaults
    $self->{ENABLED_SERVICES_FILE} = $defaults{enabled_services_file};

    # Override any
    $self->{ENABLED_SERVICES_FILE} = $parameters->{enabled_services_file} if ( $parameters->{enabled_services_file} );

    my $res = $self->reset_state();
    if ( $res != 0 ) {
        return $res;
    }

    return 0;
}

=head2 save({ restart_services => 0 })
    Saves the configuration to disk. The dependent services can be restarted by
    specifying the "restart_services" parameter as 1. 
=cut

sub save {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { restart_services => 0, } );

    my $enabled_services_file_output = $self->generate_enabled_services_file();

    my $res;

    $res = save_file( { file => $self->{ENABLED_SERVICES_FILE}, content => $enabled_services_file_output } );
    if ( $res == -1 ) {
        return (-1, "Problem saving set of enabled services");
    }

    if ( $parameters->{restart_services} ) {
        foreach my $key ( keys %{ $self->{SERVICES} } ) {
            my $service = $self->{SERVICES}->{$key};

            next if ($service->{name} eq "http"); # XXX it restarts the apache daemon while it is running.

            if ( $service->{enabled} ) {
                $self->{LOGGER}->debug( "Starting " . $service->{name} );
                start_service( { name => $service->{name} } );
            }
            else {
                $self->{LOGGER}->debug( "Stopping " . $service->{name} );
                stop_service( { name => $service->{name} } );
            }
        }
    }

    return 0;
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
=cut

sub reset_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %new_services_list = ();

    foreach my $service ( @default_known_services ) {
        my %service_desc = ();
        $service_desc{name}                      = $service->{name};
        $service_desc{description}               = $service->{description};
        $service_desc{service_name}              = $service->{service_name};
        $service_desc{enabled}                   = $service->{enabled};
        $service_desc{enabled_services_variable} = $service->{enabled_services_variable};

        $new_services_list{ $service->{name} } = \%service_desc;
    }

    my ( $status, $res ) = read_enabled_services_file( { file => $self->{ENABLED_SERVICES_FILE} } );
    if ( $status == 0 ) {

        # This just tells if it's enabled, we need to combine it with the stuff above

        foreach my $variable ( keys %$res ) {
            foreach my $key ( keys %new_services_list ) {
                my $service = $new_services_list{$key};
                next unless ( $service->{enabled_services_variable} );

                next unless ( $variable eq $service->{enabled_services_variable} );

                if ( $res->{$variable} eq "disabled" ) {
                    $service->{enabled} = 0;
                }
                elsif ( $res->{$variable} eq "enabled" ) {
                    $service->{enabled} = 1;
                }
            }
        }
    }

    $self->{SERVICES} = \%new_services_list;

    return 0;
}

=head2 get_services ({})
    Returns the list of services as a hash indexed by name. The hash values are
    hashes containing the service's properties.
=cut

sub get_services {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{SERVICES};
}

=head2 lookup_service ({ name => 1})
    Returns the properties of the specified service as a hash. Returns
    undefined if the service request does not exist.
=cut

sub lookup_service {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    return $self->{SERVICES}->{$name};
}

=head2 enable_service ({ name => 1})
    Enables the specified service. Returns 0 if successful and -1 if the
    service does not exist.
=cut

sub enable_service {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    return -1 unless ( $self->{SERVICES}->{$name} );

    $self->{SERVICES}->{$name}->{enabled} = 1;

    return 0;
}

=head2 disable_service ({ name => 1})
    Disables the specified service. Returns 0 if successful and -1 if the
    service does not exist.
=cut

sub disable_service {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    return -1 unless ( $self->{SERVICES}->{$name} );

    $self->{SERVICES}->{$name}->{enabled} = 0;

    return 0;
}

=head2 last_modified()
    Returns when the site information was last saved.
=cut

sub last_modified {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ($mtime) = (stat ( $self->{ENABLED_SERVICES_FILE} ) )[9];

    return $mtime;
}

=head2 read_enabled_services_file({ file => 1 })
    Reads the specified "enabled_services.info" file. This file consists of
    key/value pairs specifying whether services should be enabled or not.
=cut

sub read_enabled_services_file {
    my $parameters = validate( @_, { file => 1, } );

    # If the file doesn't exist, that means no interfaces are configured
    unless ( open( FILE, $parameters->{file} ) ) {
        my %retval = ();
        return ( 0, \%retval );
    }

    my %enabled = ();

    while ( <FILE> ) {
        chomp;

        if ( /=/ ) {
            my ( $variable, $value ) = split( '=' );

            # clear out whitespace
            $value =~ s/^\s+//;
            $value =~ s/\s+$//;

            $enabled{$variable} = $value;
        }
    }

    close( FILE );

    return ( 0, \%enabled );
}

=head2 generate_enabled_services_file ({})
    Generates a string representation of the contents of an
    "enabled_services.info" file from the internal set of services.
=cut

sub generate_enabled_services_file {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my $output = "";

    foreach my $key ( sort keys %{ $self->{SERVICES} } ) {
        my $service = $self->{SERVICES}->{$key};

        next unless ( $service->{enabled_services_variable} );

        if ( $service->{enabled} ) {
            $output .= $service->{enabled_services_variable} . "=enabled\n";
        }
        else {
            $output .= $service->{enabled_services_variable} . "=disabled\n";
        }
    }

    return $output;
}

=head2 save_state()
    Saves the current state of the module as a string. This state allows the
    module to be recreated later.
=cut

sub save_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %state = (
        services              => $self->{SERVICES},
        enabled_services_file => $self->{ENABLED_SERVICES_FILE},
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

    $self->{SERVICES}              = $state->{services};
    $self->{ENABLED_SERVICES_FILE} = $state->{enabled_services_file};

    return;
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
