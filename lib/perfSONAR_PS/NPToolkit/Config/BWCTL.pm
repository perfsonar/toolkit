package perfSONAR_PS::NPToolkit::Config::BWCTL;

use strict;
use warnings;

our $VERSION = 3.3;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::BWCTL

=head1 DESCRIPTION

Module for configuring BWCTL limits and key files. Longer term, This should get
extended to configure all aspects of BWCTL configuration.

=cut

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'BWCTL_CONF', 'BWCTL_LIMITS', 'BWCTL_KEYS', 'BWCTLD_CONF_FILE', 'BWCTLD_LIMITS_FILE', 'BWCTLD_KEYS_FILE';

use Params::Validate qw(:all);
use Storable qw(store retrieve freeze thaw dclone);
use Data::Dumper;

use perfSONAR_PS::Utils::Config::BWCTL qw( bwctl_conf_parse_file bwctl_keys_parse_file bwctl_limits_parse_file bwctl_keys_hash_password bwctl_conf_output bwctl_keys_output bwctl_limits_output bwctl_known_limits );
use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file restart_service );

# These are the defaults for the current NPToolkit
my %defaults = (
    bwctld_limits => "/etc/bwctld/bwctld.limits",
    bwctld_keys   => "/etc/bwctld/bwctld.keys",
    bwctld_conf   => "/etc/bwctld/bwctld.conf",
);

=head2 init({ bwctld_limits => 0, bwctld_keys => 0, bwctld_conf => 0 })

Initializes the client. Returns 0 on success and -1 on failure. The
bwctld_limits and bwctld_keys parameters can be specified to set which files
the module should use for reading/writing the configuration.

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            bwctld_limits => 0,
            bwctld_keys   => 0,
            bwctld_conf   => 0,
        }
    );

    my $res;

    $res = $self->SUPER::init();
    if ( $res != 0 ) {
        return $res;
    }

    # Initialize the defaults
    $self->{BWCTLD_CONF_FILE}   = $defaults{bwctld_conf};
    $self->{BWCTLD_KEYS_FILE}   = $defaults{bwctld_keys};
    $self->{BWCTLD_LIMITS_FILE} = $defaults{bwctld_limits};

    $self->{BWCTLD_CONF_FILE}   = $parameters->{bwctld_conf}   if ( $parameters->{bwctld_conf} );
    $self->{BWCTLD_KEYS_FILE}   = $parameters->{bwctld_keys}   if ( $parameters->{bwctld_keys} );
    $self->{BWCTLD_LIMITS_FILE} = $parameters->{bwctld_limits} if ( $parameters->{bwctld_limits} );

    $res = $self->reset_state();
    if ( $res != 0 ) {
        return $res;
    }

    return 0;
}

=head2 save({ restart_services => 0 })
    Saves the configuration to disk. The bwctl service can be restarted by
    specifying the "restart_services" parameter as 1. 
=cut

sub save {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { restart_services => 0, } );

    my ( $status, $res );

    ( $status, $res ) = bwctl_limits_output( { groups => $self->{BWCTL_LIMITS}->{groups}, users => $self->{BWCTL_LIMITS}->{users}, networks => $self->{BWCTL_LIMITS}->{networks}, default_group => $self->{BWCTL_LIMITS}->{default_group} } );
    if ($status != 0) {
        $self->{LOGGER}->error("Couldn't save limits: ".$res);
        return (-1, "Problem generating limits file");
    }

    my $bwctld_limits_output = join( "\n", @{$res} );

    ( $status, $res ) = bwctl_keys_output( { users => $self->{BWCTL_KEYS} } );
    if ($status != 0) {
        $self->{LOGGER}->error("Couldn't save keys: ".$res);
        return (-1, "Problem generating keys file");
    }

    my $bwctld_keys_output = join( "\n", @{$res} );

    ( $status, $res ) = bwctl_conf_output( { variables => $self->{BWCTL_CONF} } );
    if ($status != 0) {
        $self->{LOGGER}->error("Couldn't save conf: ".$res);
        return (-1, "Problem generating conf file");
    }

    my $bwctld_conf_output = join( "\n", @{$res} );

    $res = save_file( { file => $self->{BWCTLD_LIMITS_FILE}, content => $bwctld_limits_output } );
    if ( $res == -1 ) {
        return (-1, "Problem saving limits file: ".$self->{BWCTLD_LIMITS_FILE});
    }

    $res = save_file( { file => $self->{BWCTLD_KEYS_FILE}, content => $bwctld_keys_output } );
    if ( $res == -1 ) {
        return (-1, "Problem saving keys file");
    }

    $res = save_file( { file => $self->{BWCTLD_CONF_FILE}, content => $bwctld_conf_output } );
    if ( $res == -1 ) {
        return (-1, "Problem saving conf file");
    }

    if ( $parameters->{restart_services} ) {
        $res = restart_service( { name => "bwctl" } );
        if ( $res == -1 ) {
            return (-1, "Problem restarting bwctl");
        }
    }

    return 0;
}

=head2 lookup_network({ name => 1 })

Networks are defined by their "name". This is the 192.168.0.2/32. The return
value is either undefined if that network does not exist, or a hash reference
containing "name" and "group" keys with corresponding values.

=cut

sub lookup_network {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    return unless $self->{BWCTL_LIMITS}->{networks}->{$name};

    my %network = (
        name  => $name,
        group => $self->{BWCTL_LIMITS}->{networks}->{$name},
    );

    return \%network;
}

=head2 get_networks ({})

Returns the set of networks as a hash keyed on the network's name.

=cut

sub get_networks {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %network_list = ();

    my @networks = ();

    foreach my $name ( keys %{ $self->{BWCTL_LIMITS}->{networks} } ) {

        my %network = (
            name  => $name,
            group => $self->{BWCTL_LIMITS}->{networks}->{$name},
        );

        $network_list{$name} = \%network;
    }

    return \%network_list;
}

=head2 add_network({ name => 1, group => 1})

Adds the network to the list. Returns 0 if successful and -1 on failure. The
'name' parameter must be of the form '[ip address]/[0-32]', and that name must
not already be in use for another network. Group must correspond to one of the
defined groups.

=cut

sub add_network {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name  => 1,
            group => 1,
        }
    );

    my $name  = $parameters->{name};
    my $group = $parameters->{group};

    return -1 if ( $self->{BWCTL_LIMITS}->{networks}->{$name} );
    return -1 unless ( $self->{BWCTL_LIMITS}->{groups}->{$group} );
    return -1 unless ( $name =~ /\// );

    my ( $ip, $netmask ) = split( '/', $name );

    # verify the netmask is of /[number] form
    return -1 unless ( int( $netmask ) == $netmask and int( $netmask ) >= 0 and int( $netmask ) <= 64 );

    $self->{BWCTL_LIMITS}->{networks}->{$name} = $group;

    return 0;
}

=head2 update_network({ name => 1, group => 1})

Updates the network in the list. The 'name' parameter must correspond to a
defined network.  Group must correspond to one of the defined groups.

=cut

sub update_network {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name  => 1,
            group => 1,
        }
    );

    my $name  = $parameters->{name};
    my $group = $parameters->{group};

    return -1 unless ( $self->{BWCTL_LIMITS}->{networks}->{$name} );
    return -1 unless ( $self->{BWCTL_LIMITS}->{groups}->{$group} );

    $self->{BWCTL_LIMITS}->{networks}->{$name} = $group;

    return 0;
}

=head2 delete_network({ name => 1 })

Deletes the network in the list. Returns 0 if the network is no longer in the list (even if it never was).

=cut

sub delete_network {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    delete( $self->{BWCTL_LIMITS}->{networks}->{$name} );

    return 0;
}

=head2 update_user({ name => 1, password => 0, group => 0 })

Updates the user's properties . The 'name' parameter must correspond to a
defined user.  'group', if specified, must correspond to one of the defined
groups.

=cut

sub update_user {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name     => 1,
            password => 0,
            group    => 0,
        }
    );

    my $name     = $parameters->{name};
    my $password = $parameters->{password};
    my $group    = $parameters->{group};

    return -1 unless ( $self->{BWCTL_KEYS}->{$name} or $self->{BWCTL_LIMITS}->{users}->{$name} );

    if ( $password ) {
        my $hashed_pw = bwctl_keys_hash_password( { password => $password } );
        $self->{BWCTL_KEYS}->{$name} = $hashed_pw;
    }

    if ( exists $parameters->{group} ) {
        $self->{BWCTL_LIMITS}->{users}->{$name} = $group;
    }

    return 0;
}

=head2 lookup_user({ name => 1 })

Users are defined by their name. The return value is either undefined if that
user does not exist, or a hash reference containing "name" and "group" keys
with corresponding values.

=cut

sub lookup_user {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    return undef unless ( $self->{BWCTL_LIMITS}->{users}->{$name} or $self->{BWCTL_KEYS}->{$name} );

    my %user = (
        name     => $name,
        group    => $self->{BWCTL_LIMITS}->{users}->{$name},
        password => $self->{BWCTL_KEYS}->{$name},
    );

    return \%user;
}

=head2 get_users ({})

Returns the set of users as a hash keyed on the users's name.

=cut

sub get_users {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %user_list = ();

    my @users = ();
    push @users, keys %{ $self->{BWCTL_LIMITS}->{users} };
    push @users, keys %{ $self->{BWCTL_KEYS} };

    foreach my $user_name ( @users ) {
        next if ( $user_list{$user_name} );

        my %user = (
            name     => $user_name,
            group    => $self->{BWCTL_LIMITS}->{users}->{$user_name},
            password => $self->{BWCTL_KEYS}->{$user_name},
        );

        $user_list{$user_name} = \%user;
    }

    return \%user_list;
}

=head2 add_user({ name => 1, password => 1, group => 1})

Adds the user to the list. Returns 0 if successful and -1 on failure. The
'name' parameter must not already be in use for another user. Group must
correspond to one of the defined groups.

=cut

sub add_user {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name     => 1,
            password => 1,
            group    => 1,
        }
    );

    my $name     = $parameters->{name};
    my $password = $parameters->{password};
    my $group    = $parameters->{group};

    return -1 if ( $self->{BWCTL_KEYS}->{$name} or $self->{BWCTL_LIMITS}->{users}->{$name} );

    my $hashed_pw = bwctl_keys_hash_password( { password => $password } );
    $self->{BWCTL_KEYS}->{$name} = $hashed_pw;
    $self->{BWCTL_LIMITS}->{users}->{$name} = $group;

    return 0;
}

=head2 delete_user ({ name => 1 })

Deletes the user from the list. Returns 0 if the user is no longer in the list (even if it never was).

=cut

sub delete_user {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    delete( $self->{BWCTL_KEYS}->{$name} );
    delete( $self->{BWCTL_LIMITS}->{users}->{$name} );

    return 0;
}

=head2 lookup_group({ name => 1 })

Groups are defined by their name. The return value is either undefined if that
group does not exist, or a hash reference containing "name" and the attributes
for that group.

=cut

sub lookup_group {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    $self->{LOGGER}->info( "Groups: " . Dumper( $self->{BWCTL_LIMITS}->{groups} ) );

    return $self->{BWCTL_LIMITS}->{groups}->{$name};
}

=head2 get_groups ({})

Returns the set of groups as a hash keyed on the group's name.

=cut

sub get_groups {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{BWCTL_LIMITS}->{groups};
}

=head2 add_group({ name => 1, parent => 0, bandwidth => 0, pending => 0, event_horizon => 0, duration => 0, allow_open_mode => 0, allow_tcp => 0, allow_udp => 0, max_time_error => 0 })

Adds the group to the list. Returns 0 if successful and -1 on failure. The
'name' parameter must not already be in use for another group. The limits
parameters are sanity checked. The allow_* parameters must be "on" or "off".
'parent' correspond to an existing group. bandwidth, event_horizon, duration
and max_time_error must all be 0 or more.

=cut

sub add_group {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name            => 1,
            parent          => 0,
            bandwidth       => 0,
            pending         => 0,
            event_horizon   => 0,
            duration        => 0,
            allow_open_mode => 0,
            allow_tcp       => 0,
            allow_udp       => 0,
            max_time_error  => 0,
        }
    );

    my $name            = $parameters->{name};
    my $parent          = $parameters->{parent};
    my $bandwidth       = $parameters->{bandwidth};
    my $pending         = $parameters->{pending};
    my $event_horizon   = $parameters->{event_horizon};
    my $duration        = $parameters->{duration};
    my $allow_open_mode = $parameters->{allow_open_mode};
    my $allow_tcp       = $parameters->{allow_tcp};
    my $allow_udp       = $parameters->{allow_udp};
    my $max_time_error  = $parameters->{max_time_error};

    # Sanity check the arguments
    return -1 if ( $self->{BWCTL_LIMITS}->{groups}->{$name} );
    return -1 if ( $allow_tcp and $allow_tcp ne "on" and $allow_tcp ne "off" );
    return -1 if ( $allow_udp and $allow_udp ne "on" and $allow_udp ne "off" );
    return -1 if ( $allow_open_mode and $allow_open_mode ne "on" and $allow_open_mode ne "off" );
    return -1 if ( $parent         and not $self->{BWCTL_LIMITS}->{groups}->{$parent} );
    return -1 if ( $event_horizon  and $event_horizon < 0 );
    return -1 if ( $duration       and $duration < 0 );
    return -1 if ( $max_time_error and $max_time_error < 0 );
    return -1 if ( $bandwidth      and ( $bandwidth !~ /^([0-9]+)[mMbBgGkK]?$/ ) );

    my %group = ();
    $group{allow_tcp}       = $allow_tcp       if ( defined $allow_tcp );
    $group{allow_udp}       = $allow_udp       if ( defined $allow_udp );
    $group{allow_open_mode} = $allow_open_mode if ( defined $allow_open_mode );
    $group{parent}          = $parent          if ( defined $parent );
    $group{max_time_error}  = $max_time_error  if ( defined $max_time_error );
    $group{duration}        = $duration        if ( defined $duration );
    $group{event_horizon}   = $event_horizon   if ( defined $event_horizon );
    $group{bandwidth}       = $bandwidth       if ( defined $bandwidth );

    $self->{BWCTL_LIMITS}->{groups}->{$name} = \%group;

    return 0;
}

=head2 update_group({ name => 1, parent => 0, bandwidth => 0, pending => 0, event_horizon => 0, duration => 0, allow_open_mode => 0, allow_tcp => 0, allow_udp => 0, max_time_error => 0 })

Updates the specified group. Returns 0 if successful and -1 on failure. The
'name' parameter must not already be in use for another group. The limits
parameters are sanity checked. The allow_* parameters must be "on" or "off".
'parent' correspond to an existing group. bandwidth, event_horizon, duration
and max_time_error must all be 0 or more.

=cut

sub update_group {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name            => 1,
            parent          => 0,
            bandwidth       => 0,
            pending         => 0,
            event_horizon   => 0,
            duration        => 0,
            allow_open_mode => 0,
            allow_tcp       => 0,
            allow_udp       => 0,
            max_time_error  => 0,
        }
    );

    my $name            = $parameters->{name};
    my $parent          = $parameters->{parent};
    my $bandwidth       = $parameters->{bandwidth};
    my $pending         = $parameters->{pending};
    my $event_horizon   = $parameters->{event_horizon};
    my $duration        = $parameters->{duration};
    my $allow_open_mode = $parameters->{allow_open_mode};
    my $allow_tcp       = $parameters->{allow_tcp};
    my $allow_udp       = $parameters->{allow_udp};
    my $max_time_error  = $parameters->{max_time_error};

    # Sanity check the arguments
    return -1 unless ( $self->{BWCTL_LIMITS}->{groups}->{$name} );
    return -1 if ( $allow_tcp       and $allow_tcp       ne "on" and $allow_tcp       ne "off" );
    return -1 if ( $allow_udp       and $allow_udp       ne "on" and $allow_udp       ne "off" );
    return -1 if ( $allow_open_mode and $allow_open_mode ne "on" and $allow_open_mode ne "off" );
    return -1 if ( $parent         and not $self->{BWCTL_LIMITS}->{groups}->{$parent} );
    return -1 if ( $event_horizon  and $event_horizon < 0 );
    return -1 if ( $duration       and $duration < 0 );
    return -1 if ( $max_time_error and $max_time_error < 0 );
    return -1 if ( $bandwidth      and ( $bandwidth !~ /^([0-9]+)[mMbBgGkK]?$/ ) );

    $self->{BWCTL_LIMITS}->{groups}->{$name}->{allow_tcp}       = $allow_tcp       if ( defined $allow_tcp );
    $self->{BWCTL_LIMITS}->{groups}->{$name}->{allow_udp}       = $allow_udp       if ( defined $allow_udp );
    $self->{BWCTL_LIMITS}->{groups}->{$name}->{allow_open_mode} = $allow_open_mode if ( defined $allow_open_mode );
    $self->{BWCTL_LIMITS}->{groups}->{$name}->{parent}          = $parent          if ( defined $parent );
    $self->{BWCTL_LIMITS}->{groups}->{$name}->{max_time_error}  = $max_time_error  if ( defined $max_time_error );
    $self->{BWCTL_LIMITS}->{groups}->{$name}->{duration}        = $duration        if ( defined $duration );
    $self->{BWCTL_LIMITS}->{groups}->{$name}->{event_horizon}   = $event_horizon   if ( defined $event_horizon );
    $self->{BWCTL_LIMITS}->{groups}->{$name}->{bandwidth}       = $bandwidth       if ( defined $bandwidth );

    return 0;
}

=head2 delete_group ({ name => 1 })

Deletes the group from the list. Returns (0, "") if the group is no longer in
the list (even if it never was). Returns (-1, $error_msg) if a network or user
is a member of that group.

=cut

sub delete_group {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    foreach my $network ( keys %{ $self->{BWCTL_LIMITS}->{networks} } ) {
        if ( $self->{BWCTL_LIMITS}->{networks}->{$network} eq $name ) {
            return ( -1, "Network $network is a member of $name" );
        }
    }

    foreach my $user ( keys %{ $self->{BWCTL_LIMITS}->{users} } ) {
        if ( $self->{BWCTL_LIMITS}->{users}->{$user} eq $name ) {
            return ( -1, "User $user is a member of $name" );
        }
    }

    delete( $self->{BWCTL_LIMITS}->{groups}->{$name} );

    return ( 0, "" );
}

=head2 get_port_range
	Gets the port range for the test type specified in port_type
=cut
sub get_port_range {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { port_type => 1 } );
    my $port_type = $parameters->{port_type};

    unless ($port_type eq "peer" or $port_type eq "iperf") {
        my $msg = "Invalid port range: ".$port_type;
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    my $port_variable = $port_type."_port";

    my ($min_port, $max_port) = (0, 0);

    if ($self->{BWCTL_CONF}->{$port_variable}) {
        if ($self->{BWCTL_CONF}->{$port_variable} =~ /^(\d+)-(\d+)$/) {
            $min_port = $1;
            $max_port = $2;
        }
        else {
            my $msg = "Invalid port range for $port_variable: ".$self->{BWCTL_CONF}->{$port_variable};
            $self->{LOGGER}->error($msg);
            return (-1, $msg);
        }
    }

    return (0, { min_port => $min_port, max_port => $max_port });
}

=head2 set_port_range
	Set the port range for the test type specified in port_type
=cut
sub set_port_range {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { port_type => 1, min_port => 1, max_port => 1 } );
    my $port_type = $parameters->{port_type};
    my $min_port  = $parameters->{min_port};
    my $max_port  = $parameters->{max_port};

    unless ($port_type eq "peer" or $port_type eq "iperf") {
        my $msg = "Invalid port range: ".$port_type;
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    if ($min_port > $max_port) {
        my $msg = "Invalid port range (min port > max port): ".$min_port."<".$max_port;
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    my $port_variable = $port_type."_port";

    my $range_desc = $min_port."-".$max_port;
    if ($min_port == 0 and $max_port == 0) {
        $range_desc = "0";
    }

    $self->{BWCTL_CONF}->{$port_variable} = $range_desc;

    return 0;
}

=head2 lookup_limit
	Looks up the limit for the specified group
=cut
sub lookup_limit {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, limit => 1, non_recursive => 0, constrained => 0 } );

    my $name = $parameters->{name};
    my $limit = $parameters->{limit};
    my $non_recursive = $parameters->{non_recursive};
    my $constrained   = $parameters->{constrained};

    my ($status, $res);

    unless ($self->{BWCTL_LIMITS}->{groups}->{$name}) {
        return (-1, "Unknown group: $name");
    }

    ($status, $res) = bwctl_known_limits({ limit => $limit });
    if ($status != 0) {
        return (-1, "Unknown limit: $limit");
    }

    my $group = $self->{BWCTL_LIMITS}->{groups}->{$name};

    if ($non_recursive) {
        return $group->{$limit};
    }
    else {
        return __lookup_limit($group, $self->{BWCTL_LIMITS}->{groups}, $limit, $constrained);
    }
}

sub __lookup_limit {
    my ( $group, $groups, $limit, $constrained ) = @_;

    my ($new_limit, $existing_limit);

    if (defined $group->{$limit} && not $constrained) {
        return $group->{$limit}; 
    }

    if ($group->{parent}) {
        $existing_limit = __lookup_limit($groups->{$group->{parent}}, $groups, $limit, $constrained);
    }

    unless (defined $existing_limit) {
        $new_limit = $group->{$limit};
    } else {
        my $limit_type = bwctl_known_limits({ limit => $limit });

        if ($limit_type->{type} eq "boolean") {
            if (defined $group->{$limit} and $existing_limit eq "on") {
                $new_limit = $group->{$limit};
            } else {
                $new_limit = $existing_limit;
            }
        } elsif ($limit_type->{type} eq "bandwidth" or $limit_type->{type} eq "disk" or $limit_type->{type} eq "time"  or $limit_type->{type} eq "integer" ) {
            $new_limit = $existing_limit;

            if (defined $group->{$limit}) {
                if ($group->{$limit} < $existing_limit or $existing_limit == 0) {
                    $new_limit = $group->{$limit};
                }
            }
        }
    }

    unless (defined $new_limit) {
        my $limit_type = bwctl_known_limits({ limit => $limit });
        $new_limit = $limit_type->{default};
    }

    return $new_limit;
}

=head2 set_default_group({ name => 1 })

Sets the group for incoming connections that aren't authenticated with a
password and don't come from one of the configured networks. Returns 0 on
success and -1 on failure. The name must correspond to a defined group.

=cut

sub set_default_group {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { name => 1, } );

    my $name = $parameters->{name};

    return -1 unless ( $self->{BWCTL_LIMITS}->{groups}->{$name} );

    $self->{BWCTL_LIMITS}->{default_group} = $name;

    return 0;
}

=head2 last_modified()
    Returns when the configuration was last saved.
=cut

sub last_modified {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ($mtime1) = (stat ( $self->{BWCTLD_KEYS_FILE} ) )[9];
    my ($mtime2) = (stat ( $self->{BWCTLD_LIMITS_FILE} ) )[9];
    my ($mtime3) = (stat ( $self->{BWCTLD_CONF_FILE} ) )[9];

    $mtime1 = 0 unless ($mtime1);
    $mtime2 = 0 unless ($mtime2);
    $mtime3 = 0 unless ($mtime3);

    my $mtime = ($mtime1 > $mtime2)?$mtime1:$mtime2;
    $mtime = ($mtime > $mtime3)?$mtime:$mtime3;

    return $mtime;
}


=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
=cut

sub reset_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ( $status, $res );

    if ( -f $self->{BWCTLD_LIMITS_FILE} ) {
        ( $status, $res ) = bwctl_limits_parse_file( { file => $self->{BWCTLD_LIMITS_FILE} } );
        if ( $status != 0 ) {
            $self->{LOGGER}->error( "Limits: $res" );
            return -1;
        }

	$self->{BWCTL_LIMITS} = $res;
    }
    else {
        $self->{BWCTL_LIMITS} = {};
    }

    if ( -f $self->{BWCTLD_KEYS_FILE} ) {
        ( $status, $res ) = bwctl_keys_parse_file( { file => $self->{BWCTLD_KEYS_FILE} } );
        if ( $status != 0 ) {
            $self->{LOGGER}->error( "Keys: $res" );
            return -1;
        }

        $self->{BWCTL_KEYS} = $res;
    }
    else {
        $self->{BWCTL_KEYS} = {};
    }

    if ( -f $self->{BWCTLD_CONF_FILE} ) {
        ( $status, $res ) = bwctl_conf_parse_file( { file => $self->{BWCTLD_CONF_FILE} } );
        if ( $status != 0 ) {
            $self->{LOGGER}->error( "Keys: $res" );
            return -1;
        }

        $self->{BWCTL_CONF} = $res;

        use Data::Dumper;
        $self->{LOGGER}->error("BWCTL_CONF: ".Dumper($res));
    }
    else {
        $self->{BWCTL_CONF} = {};
    }

    return 0;
}

=head2 save_state()
    Saves the current state of the module as a string. This state allows the
    module to be recreated later.
=cut

sub save_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %state = (
        bwctl_limits       => $self->{BWCTL_LIMITS},
        bwctl_keys         => $self->{BWCTL_KEYS},
        bwctl_conf         => $self->{BWCTL_CONF},
        bwctld_limits_file => $self->{BWCTLD_LIMITS_FILE},
        bwctld_keys_file   => $self->{BWCTLD_KEYS_FILE},
        bwctld_conf_file   => $self->{BWCTLD_CONF_FILE},
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

    $self->{BWCTL_LIMITS}       = $state->{bwctl_limits};
    $self->{BWCTL_KEYS}         = $state->{bwctl_keys};
    $self->{BWCTL_CONF}         = $state->{bwctl_conf};
    $self->{BWCTLD_LIMITS_FILE} = $state->{bwctld_limits_file};
    $self->{BWCTLD_KEYS_FILE}   = $state->{bwctld_keys_file};
    $self->{BWCTLD_CONF_FILE}   = $state->{bwctld_conf_file};

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
