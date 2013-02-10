package perfSONAR_PS::NPToolkit::Config::NTP;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::NTP

=head1 DESCRIPTION

Module for configuring the ntp configuration. The module is currently very
simple and only allows configuration of the servers contained in the
configuration. Longer term, it might make sense to allow a more fine-grained
configuration. This module can read/write ntp.conf as well as
/usr/local/etc/ntp.known_servers and uses the ntp_conf.tmpl file for writing
the ntp.conf file.

=cut

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'NTP_SERVERS', 'NTP_CONF_FILE', 'NTP_CONF_TEMPLATE_FILE', 'KNOWN_SERVERS_FILE', 'STEP_TICKERS_FILE';

use Template;
use Data::Dumper;
use Params::Validate qw(:all);
use Storable qw(store retrieve freeze thaw dclone);

use perfSONAR_PS::Utils::Config::NTP qw( ntp_conf_read_file );
use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file restart_service );

# These are the defaults for the current NPToolkit
my %defaults = (
    ntp_conf          => "/etc/ntp.conf",
    known_servers     => "/opt/perfsonar_ps/toolkit/etc/ntp_known_servers",
    ntp_conf_template => "/opt/perfsonar_ps/toolkit/templates/config/ntp_conf.tmpl",
    step_tickers_file => "/etc/ntp/step-tickers",
);

=head2 init({ ntp_conf_template => 0, known_servers => 0, ntp_conf => 0 })

Initializes the client. Returns 0 on success and -1 on failure. If specified,
the parameters can be used to set which ntp.conf file, ntp.known_servers file
and ntp.conf template are used for configuration. The defaults are where these
files are located on the current NPToolkit version.

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            ntp_conf_template => 0,
            known_servers     => 0,
            ntp_conf          => 0,
            step_tickers_file => 0,
        }
    );

    # Initialize the defaults
    $self->{NTP_CONF_TEMPLATE_FILE} = $defaults{ntp_conf_template};
    $self->{NTP_CONF_FILE}          = $defaults{ntp_conf};
    $self->{KNOWN_SERVERS_FILE}     = $defaults{known_servers};
    $self->{STEP_TICKERS_FILE}      = $defaults{step_tickers_file};

    # Override any
    $self->{NTP_CONF_TEMPLATE_FILE} = $parameters->{ntp_conf_template} if ( $parameters->{ntp_conf_template} );
    $self->{NTP_CONF_FILE}          = $parameters->{ntp_conf}          if ( $parameters->{ntp_conf} );
    $self->{KNOWN_SERVERS_FILE}     = $parameters->{known_servers}     if ( $parameters->{known_servers} );
    $self->{STEP_TICKERS_FILE}      = $parameters->{step_tickers_file} if ( $parameters->{step_tickers_file} );

    my $res = $self->reset_state();
    if ( $res != 0 ) {
        return $res;
    }
    return 0;
}

=head2 save({ restart_services => 0 })
    Saves the configuration to disk. NTP can be restarted by specifying the
    "restart_services" parameter as 1. 
=cut

sub save {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { restart_services => 0, } );

    my $ntp_conf_output          = $self->generate_ntp_conf();
    my $ntp_known_servers_output = $self->generate_ntp_server_list();
    my $ntp_step_tickers         = $self->generate_step_tickers_list();

    my $res;

    return (-1, "Problem generating NTP configuration") unless ( $ntp_conf_output );
    return (-1, "Problem generating list of known servers") unless ( $ntp_known_servers_output );
    return (-1, "Problem generating list of selected servers") unless ($ntp_step_tickers);

    $res = save_file( { file => $self->{NTP_CONF_FILE}, content => $ntp_conf_output } );
    if ( $res == -1 ) {
        $self->{LOGGER}->error( "File save failed: " . $self->{KNOWN_SERVERS_FILE} );
        return (-1, "Problem saving NTP configuration");
    }

    $res = save_file( { file => $self->{KNOWN_SERVERS_FILE}, content => $ntp_known_servers_output } );
    if ( $res == -1 ) {
        $self->{LOGGER}->error( "File save failed: " . $self->{KNOWN_SERVERS_FILE} );
        return (-1, "Problem saving list of known NTP servers");
    }

    $res = save_file( { file => $self->{STEP_TICKERS_FILE}, content => $ntp_step_tickers} );
    if ( $res == -1 ) {
        $self->{LOGGER}->error( "File save failed: " . $self->{STEP_TICKERS_FILE} );
        return (-1, "Problem saving NTP configuration");
    }

    if ( $parameters->{restart_services} ) {
        $res = restart_service( { name => "ntp" } );
        if ( $res == -1 ) {
            $self->{LOGGER}->error( "restart failed" );
            return (-1, "Problem restarting NTP");
        }
    }

    return 0;
}

=head2 generate_step_tickers_list({})
    Returns a list of selected servers for the step tickers.
=cut

sub generate_step_tickers_list {
    my $self = shift();
    my $servers                  = $self->get_selected_servers();
    my $selected_server_list     = $self->generate_server_list( servers => $servers );
    return $selected_server_list;
}

=head2
    Takes an array of NTP servers and returns a string of host names seperated by newlines.
=cut

sub generate_server_list {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            servers => 1
        }
    );
    my $servers = $parameters->{servers};
    my $ret;

    foreach (@{$servers}) {
        $ret .= $_->{address} . "\n";
    }
    return $ret;
}

=head2 get_selected_servers ({})
    Returns an array of user selected NTP servers.
=cut

sub get_selected_servers {
    my $self = shift();
    my @servers = ();

    foreach my $key ( keys %{ $self->{NTP_SERVERS} } ) {
        my $ntp_server = $self->{NTP_SERVERS}->{$key};
        if ( $ntp_server->{selected} ) {
            push(@servers, $ntp_server);
        }
    }
    return \@servers;
}

=head2 add_server({ address => 1, description => 1, selected => 1 })

Adds a new server with the specified description and whether it is one of the
servers that NTP should be consulting.  Returns 0 on success and -1 on failure.
Returns -1 if a server with the specified address already exists. The
description parameter contains a text description of the server. The selected
parameter is 1 or 0 depending on whether the server is selected to be in the
ntp.conf file.

=cut

sub add_server {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            address     => 1,
            description => 1,
            selected    => 1,
        }
    );

    my $address     = $parameters->{address};
    my $description = $parameters->{description};
    my $selected    = $parameters->{selected};

    if ( $self->{NTP_SERVERS}->{$address} ) {
        return -1;
    }

    $self->{NTP_SERVERS}->{$address} = {
        address     => $address,
        description => $description,
        selected    => $selected,
    };
    return 0;
}

=head2 update_server({ address => 1, description => 0, selected => 0 })

Updates the server's description and whether it should be used in the ntp
configuration. Returns 0 on success and -1 on failure. A server with the
specified address must exist or -1 is returned. The description parameter
contains a text description of the server. The selected parameter is 1 or 0
depending on whether the server is selected to be in the ntp.conf file.

=cut

sub update_server {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            address     => 1,
            description => 0,
            selected    => 0,
        }
    );

    my $address     = $parameters->{address};
    my $description = $parameters->{description};
    my $selected    = $parameters->{selected};

    return -1 unless ( $self->{NTP_SERVERS}->{$address} );

    $self->{NTP_SERVERS}->{$address}->{description} = $description if ( defined $description );
    $self->{NTP_SERVERS}->{$address}->{selected}    = $selected    if ( defined $selected );

    return 0;
}

=head2 get_servers ({})
    Returns the list of known servers as a hash keyed on the servers' addresses.
=cut

sub get_servers {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{NTP_SERVERS};
}

=head2 lookup_server ({ address => 1 })
    Returns a description of the specified server or undefined if the server
    does not exist. The description is a hash containing a description key and
    a selected key.
=cut

sub lookup_server {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { address => 1, } );

    my $address = $parameters->{address};

    return ( $self->{NTP_SERVERS}->{$address} );
}

=head2 delete_server ({ address => 1 })
    Removes the selected server from the list. A return value of 0 means the
    server is not in the list. 
=cut

sub delete_server {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { address => 1, } );

    my $address = $parameters->{address};

    delete( $self->{NTP_SERVERS}->{$address} );

    return 0;
}

=head2 last_modified()
    Returns when the site information was last saved.
=cut

sub last_modified {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ($mtime1) = (stat ( $self->{KNOWN_SERVERS_FILE} ) )[9];
    my ($mtime2) = (stat ( $self->{NTP_CONF_FILE} ) )[9];

    my $mtime = ($mtime1 > $mtime2)?$mtime1:$mtime2;

    return $mtime;
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
=cut

sub reset_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %new_ntp_servers = ();

    if ( $self->{KNOWN_SERVERS_FILE} ) {
        my ( $status, $res ) = $self->read_ntp_server_list( { file => $self->{KNOWN_SERVERS_FILE} } );
        if ( $status != 0 ) {
            $self->{LOGGER}->error( "Couldn't read NTP server list: " . $res );
        }
        else {
            my $servers = $res;

            foreach my $key ( keys %{$servers} ) {
                my $server = $servers->{$key};

                next if ( $new_ntp_servers{ $server->{address} } );

                my %ntp_server = (
                    address     => $server->{address},
                    description => $server->{description},
                );

                $new_ntp_servers{ $server->{address} } = \%ntp_server;
            }
        }
    }

    if ( $self->{NTP_CONF_FILE} ) {
        my ( $status, $res ) = ntp_conf_read_file( { file => $self->{NTP_CONF_FILE} } );
        if ( $status != 0 ) {
            return $status;
        }

        foreach my $address ( @{$res} ) {
            if ( $new_ntp_servers{$address} ) {
                $new_ntp_servers{$address}->{selected} = 1;
                next;
            }

            my %ntp_server = (
                address  => $address,
                selected => 1,
            );

            $new_ntp_servers{$address} = \%ntp_server;
        }
    }

    $self->{NTP_SERVERS} = \%new_ntp_servers;

    return 0;
}

=head2 generate_ntp_conf ({})
    Converts the internal configuration into the expected template toolkit
    variables, and passes them to template toolkit along with the configured
    template.
=cut

sub generate_ntp_conf {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %vars         = ();
    my @vars_servers = ();
    foreach my $key ( sort keys %{ $self->{NTP_SERVERS} } ) {
        my $ntp_server = $self->{NTP_SERVERS}->{$key};

        if ( $ntp_server->{selected} ) {
            my %server_desc = ();
            $server_desc{address}     = $ntp_server->{address};
            $server_desc{description} = $ntp_server->{description};

            push @vars_servers, \%server_desc;
        }
    }
    $vars{servers} = \@vars_servers;

    my $config;

    my $tt = Template->new( ABSOLUTE => 1 );
    unless ( $tt ) {
        $self->{LOGGER}->error( "Couldn't initialize template toolkit" );
        return;
    }

    unless ( $tt->process( $self->{NTP_CONF_TEMPLATE_FILE}, \%vars, \$config ) ) {
        $self->{LOGGER}->error( "Error writing ntp.conf: " . $tt->error() );
        return;
    }

    return $config;
}

=head2 read_ntp_server_list ({ file => 1 })
    Reads the specified ntp.known_server file and returns a hash keyed on the
    addresses with hash values being a hash containing the description.
=cut

sub read_ntp_server_list {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { file => 1, } );

    unless ( open( NTP_SERVERS_FILE, $parameters->{file} ) ) {
        return ( -1, "Couldn't open file: " . $parameters->{file} );
    }

    my %ntp_servers = ();

    while ( <NTP_SERVERS_FILE> ) {
        chomp;

        my ( $address, $description ) = split( ':', $_ );

        next unless ( $address );

        my %ntp_server = (
            address     => $address,
            description => $description,
        );

        $ntp_servers{$address} = \%ntp_server;
    }

    close( NTP_SERVERS_FILE );

    return ( 0, \%ntp_servers );
}

=head2 generate_ntp_server_list
    Takes the internal representation of the known ntp servers and returns a
    string representation of the contents of a ntp.known_servers file
    containing those servers.
=cut

sub generate_ntp_server_list {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my $output = "";

    foreach my $key ( sort keys %{ $self->{NTP_SERVERS} } ) {
        my $ntp_server = $self->{NTP_SERVERS}->{$key};

        $output .= $ntp_server->{address} . ':';
        $output .= $ntp_server->{description} if ( $ntp_server->{description} );
        $output .= "\n";
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
        ntp_servers        => $self->{NTP_SERVERS},
        ntp_conf           => $self->{NTP_CONF_FILE},
        ntp_conf_template  => $self->{NTP_CONF_TEMPLATE_FILE},
        known_servers_file => $self->{KNOWN_SERVERS_FILE},
        step_tickers_file  => $self->{STEP_TICKERS_FILE},
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

    $self->{NTP_SERVERS}            = $state->{ntp_servers};
    $self->{NTP_CONF_FILE}          = $state->{ntp_conf};
    $self->{NTP_CONF_TEMPLATE_FILE} = $state->{ntp_conf_template};
    $self->{KNOWN_SERVERS_FILE}     = $state->{known_servers_file};
    $self->{STEP_TICKERS_FILE}      = $state->{step_tickers_file};

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
